import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/time/server_clock.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../data/active_conclave_repository.dart';
import '../data/local_db.dart';
import '../data/notification_service.dart';
import '../data/sync_service.dart';
import '../domain/active_conclave_models.dart';
import '../domain/attendance_qr.dart';
import 'captain_scanner_screen.dart';

/// The screen people actually use at the event.
///
/// Design constraints that drove this layout, all of them physical:
///
///  - It is used STANDING UP, in a noisy room, under a countdown. The remaining
///    time is the single most important thing on screen, so it is the anchor and
///    it is legible at arm's length.
///  - The primary action (scan, for a captain; show your code, for a member) has
///    to be reachable with a thumb, so it is pinned to the bottom rather than
///    buried in a scrolling list.
///  - Phase is never signalled by colour alone — a phone in direct sunlight at a
///    venue washes colour out completely.
class ActiveRoundScreen extends ConsumerStatefulWidget {
  final String conclaveId;

  const ActiveRoundScreen({super.key, required this.conclaveId});

  @override
  ConsumerState<ActiveRoundScreen> createState() => _ActiveRoundScreenState();
}

class _ActiveRoundScreenState extends ConsumerState<ActiveRoundScreen> {
  Timer? _ticker;
  StreamSubscription? _fcmSub;
  DateTime _now = DateTime.now();

  /// Server-corrected clock. Round boundaries are set by the server, so the
  /// device clock must never be trusted to decide when a round opens or closes.
  DateTime _serverNow() => ref.read(serverClockProvider).now();

  /// Local (offline) state for the round currently on screen.
  Map<String, bool> _attendance = {};
  Set<String> _referred = {};
  int _pendingSync = 0;
  int? _loadedRound;

  @override
  void initState() {
    super.initState();
    _now = _serverNow();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = _serverNow());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).startSyncTimer(widget.conclaveId);
      ref.read(notificationServiceProvider).subscribe(widget.conclaveId);
    });

    // FCM shows no system notification while the app is open, so surface round
    // alerts in-app. The round itself still comes from the conclave document —
    // this only tells the user to look up.
    _fcmSub = ref
        .read(notificationServiceProvider)
        .foregroundMessages
        .listen((message) {
      final title = message.notification?.title;
      if (title != null && mounted) _toast(title);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _fcmSub?.cancel();
    super.dispose();
  }

  /// Reloads the offline records for [round]. Called on first paint of a round
  /// and after every local write, so the UI reflects sqflite, not memory.
  Future<void> _loadLocal(ActiveRound round) async {
    final db = ref.read(localDbProvider);
    final attendance = await db.getAttendanceForRound(
      conclaveId: round.conclaveId,
      roundNumber: round.roundNumber,
    );
    final referred = await db.getReferredUserIdsForRound(
      conclaveId: round.conclaveId,
      roundNumber: round.roundNumber,
      fromUserId: round.currentUserId,
    );
    final pending = await db.pendingRecordCount();

    if (!mounted) return;
    setState(() {
      _attendance = attendance;
      _referred = referred;
      _pendingSync = pending;
      _loadedRound = round.roundNumber;
    });
  }

  Future<void> _setAttendance(ActiveRound round, TableSeat seat, bool present) async {
    if (!round.canRecordAt(_serverNow())) return;

    await ref.read(localDbProvider).markAttendance(
          conclaveId: round.conclaveId,
          roundNumber: round.roundNumber,
          tableNumber: round.tableNumber,
          userId: seat.userId,
          isPresent: present,
          markedBy: round.currentUserId,
        );
    await _loadLocal(round);
  }

  /// Gives a referral immediately — one tap, no dialog.
  ///
  /// The note is optional and offered afterwards. A confirmation dialog with a
  /// text field put a form between the user and the single action the whole
  /// event exists for.
  Future<void> _giveReferral(ActiveRound round, TableSeat seat) async {
    if (!round.canRecordAt(_serverNow())) return;

    final written = await ref.read(localDbProvider).addReferral(
          conclaveId: round.conclaveId,
          roundNumber: round.roundNumber,
          fromUserId: round.currentUserId,
          toUserId: seat.userId,
          toName: seat.name,
          toBusinessName: seat.businessName,
        );

    await _loadLocal(round);
    if (!mounted) return;

    if (!written) {
      _toast('You have already referred ${seat.name} this round.');
      return;
    }

    // The undo lives here rather than in a confirmation up front: it costs the
    // 95% who meant it nothing, and still protects the mis-tap.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Referred ${seat.name}'),
          action: SnackBarAction(
            label: 'Add note',
            onPressed: () => _editNote(round, seat),
          ),
        ),
      );
  }

  /// Annotates a referral that has already been given.
  Future<void> _editNote(ActiveRound round, TableSeat seat) async {
    final existing = await ref.read(localDbProvider).getReferralNote(
          conclaveId: round.conclaveId,
          roundNumber: round.roundNumber,
          fromUserId: round.currentUserId,
          toUserId: seat.userId,
        );
    if (!mounted) return;

    final controller = TextEditingController(text: existing ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // sheet must ride above the keyboard
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: Gap.xl,
          right: Gap.xl,
          top: Gap.sm,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + Gap.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Note for ${seat.name}',
              style: ctx.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              'Only you can see this. It syncs with the referral.',
              style: ctx.text.bodySmall
                  ?.copyWith(color: ctx.scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Call my friend John at 555-1234',
              ),
            ),
            const SizedBox(height: Gap.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save note'),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    await ref.read(localDbProvider).updateReferralNote(
          conclaveId: round.conclaveId,
          roundNumber: round.roundNumber,
          fromUserId: round.currentUserId,
          toUserId: seat.userId,
          notes: controller.text,
        );
    await _loadLocal(round);
    _toast('Note saved.');
  }

  Future<void> _openScanner(ActiveRound round) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CaptainScannerScreen(round: round)),
    );
    await _loadLocal(round);
  }

  Future<void> _syncNow() async {
    _toast('Syncing…');
    await ref.read(syncServiceProvider).syncNow(widget.conclaveId);
    final pending = await ref.read(localDbProvider).pendingRecordCount();
    if (!mounted) return;
    setState(() => _pendingSync = pending);
    _toast(pending == 0
        ? 'Everything is saved to the server.'
        : '$pending record(s) still waiting — will retry.');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeRoundProvider(widget.conclaveId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active round'),
        actions: [
          _SyncButton(pending: _pendingSync, onTap: _syncNow),
          const SizedBox(width: Gap.xs),
        ],
      ),
      body: state.when(
        loading: () => const LoadingView(label: 'Finding your table…'),
        error: (e, _) => ErrorView(
          message: 'Could not load the round.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(activeRoundProvider(widget.conclaveId)),
        ),
        data: (s) {
          final round = s.round;
          if (round == null) return _Unavailable(reason: s.unavailable!);

          // First paint of a round (or when the admin advances): pull the offline
          // records for it.
          if (_loadedRound != round.roundNumber) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _loadLocal(round));
          }

          return _RoundView(
            round: round,
            now: _now,
            attendance: _attendance,
            referred: _referred,
            onAttendance: (seat, present) => _setAttendance(round, seat, present),
            onRefer: (seat) => _giveReferral(round, seat),
            onAddNote: (seat) => _editNote(round, seat),
            onScan: () => _openScanner(round),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _RoundView extends StatelessWidget {
  final ActiveRound round;
  final DateTime now;
  final Map<String, bool> attendance;
  final Set<String> referred;
  final void Function(TableSeat, bool) onAttendance;
  final void Function(TableSeat) onRefer;
  final void Function(TableSeat) onAddNote;
  final VoidCallback onScan;

  const _RoundView({
    required this.round,
    required this.now,
    required this.attendance,
    required this.referred,
    required this.onAttendance,
    required this.onRefer,
    required this.onAddNote,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final phase = round.phaseAt(now);
    final canRecord = round.canRecordAt(now);

    return Column(
      children: [
        Expanded(
          child: ContentWidth(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                context.pagePadding,
                context.pagePadding,
                Gap.sm,
              ),
              children: [
                _TimerCard(round: round, now: now, phase: phase),
                const SizedBox(height: Gap.lg),

                if (!canRecord) ...[
                  _PhaseNotice(phase: phase, round: round),
                  const SizedBox(height: Gap.lg),
                ],

                // A member's code is the thing a captain scans, so it is the
                // member's primary object — not buried below the roster.
                if (!round.isCaptain) ...[
                  _MyQrCard(round: round),
                  const SizedBox(height: Gap.lg),
                ],

                Row(
                  children: [
                    Text(
                      'At your table',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (round.isCaptain)
                      Text(
                        '${attendance.values.where((p) => p).length} of ${round.seats.length} present',
                        style: context.text.labelSmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.sm),

                for (var i = 0; i < round.seats.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: FadeSlideIn(
                      index: i,
                      child: _SeatCard(
                        seat: round.seats[i],
                        // Captains see the whole table's attendance; members only
                        // ever see their own.
                        attendance: (round.isCaptain || round.seats[i].isSelf)
                            ? attendance[round.seats[i].userId]
                            : null,
                        canMark: canRecord &&
                            (round.seats[i].isSelf || round.isCaptain),
                        canRefer: canRecord &&
                            !round.seats[i].isSelf &&
                            !referred.contains(round.seats[i].userId),
                        alreadyReferred: referred.contains(round.seats[i].userId),
                        onAttendance: (p) => onAttendance(round.seats[i], p),
                        onRefer: () => onRefer(round.seats[i]),
                        onAddNote: () => onAddNote(round.seats[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Captains scan; that is their whole job at the table, and it must be
        // one thumb away rather than at the top of a scrolling list.
        if (round.isCaptain)
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                Gap.sm,
                context.pagePadding,
                Gap.md,
              ),
              child: ContentWidth(
                child: SizedBox(
                  height: 56,
                  // No `style:` on the label. Overriding it with a TextTheme
                  // style drags in that style's colour (near-black onSurface),
                  // which silently defeats the button's own onPrimary and leaves
                  // black text on the red fill. Let the button own its colours.
                  child: FilledButton.icon(
                    onPressed: canRecord ? onScan : null,
                    icon: const Icon(Icons.qr_code_scanner, size: 24),
                    label: Text(canRecord ? 'Scan members' : 'Scanning closed'),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// The anchor of the screen: how long is left, and what for.
class _TimerCard extends StatelessWidget {
  final ActiveRound round;
  final DateTime now;
  final RoundPhase phase;

  const _TimerCard({required this.round, required this.now, required this.phase});

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (fg, bg, label, icon) = switch (phase) {
      RoundPhase.active => (
          c.onSuccessContainer,
          c.successContainer,
          'Talking time',
          Icons.record_voice_over_outlined,
        ),
      RoundPhase.transition => (
          c.onWarningContainer,
          c.warningContainer,
          'Move to your next table',
          Icons.directions_walk,
        ),
      RoundPhase.ended => (
          context.scheme.onSurfaceVariant,
          context.scheme.surfaceContainerHighest,
          'Round ended',
          Icons.hourglass_empty,
        ),
    };

    final remaining = round.remainingAt(now);
    final total = phase == RoundPhase.active
        ? round.timing.active
        : round.timing.transition;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    // Under a minute, the countdown starts breathing. It is the one moment the
    // screen should demand attention — you are about to be moved on mid-sentence.
    final urgent = phase == RoundPhase.active &&
        remaining.inSeconds <= 60 &&
        remaining.inSeconds > 0;

    return Semantics(
      label: '$label. ${remaining.inMinutes} minutes '
          '${remaining.inSeconds.remainder(60)} seconds remaining. '
          'Round ${round.roundNumber} of ${round.totalRounds}, table ${round.tableNumber}.',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.slow,
        curve: Motion.curve,
        padding: const EdgeInsets.symmetric(vertical: Gap.xl, horizontal: Gap.lg),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(color: fg.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: Gap.sm),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: context.text.labelSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.xl),

            _PulsingRing(
              enabled: urgent,
              child: SizedBox(
                width: 184,
                height: 184,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // A ring, because time remaining is easier to judge at a
                    // glance as a shape than as digits — and at this event you
                    // are glancing, mid-conversation.
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: progress, end: progress),
                      duration: Motion.fast,
                      builder: (context, v, _) => SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: phase == RoundPhase.ended ? 0 : v,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          color: fg,
                          backgroundColor: fg.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tabular figures: without them the digits jitter as the
                        // glyph widths change each second, and a twitching timer
                        // is maddening to watch.
                        Text(
                          _fmt(remaining),
                          style: context.text.displayMedium?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -2,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          phase == RoundPhase.ended ? 'ended' : 'remaining',
                          style: context.text.labelSmall?.copyWith(
                            color: fg.withValues(alpha: 0.7),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: Gap.xl),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              alignment: WrapAlignment.center,
              children: [
                StatusBadge(
                  label: 'Table ${round.tableNumber}',
                  icon: Icons.table_restaurant_outlined,
                ),
                StatusBadge(
                  label: 'Round ${round.roundNumber} of ${round.totalRounds}',
                  icon: Icons.repeat,
                ),
                if (round.isCaptain)
                  const StatusBadge(
                    label: 'Captain',
                    tone: StatusTone.info,
                    icon: Icons.star_outline,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A slow pulse for the final minute.
///
/// Deliberately subtle and slow — a fast flash would read as an error, and the
/// point is "wrap up", not "something is wrong".
class _PulsingRing extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _PulsingRing({required this.child, required this.enabled});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingRing old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.enabled && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(
        scale: 1 + (_c.value * 0.03),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _PhaseNotice extends StatelessWidget {
  final RoundPhase phase;
  final ActiveRound round;

  const _PhaseNotice({required this.phase, required this.round});

  @override
  Widget build(BuildContext context) {
    final isTransition = phase == RoundPhase.transition;
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: isTransition ? c.warningContainer : context.scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isTransition ? Icons.lock_clock : Icons.hourglass_empty,
            size: 20,
            color: isTransition ? c.onWarningContainer : context.scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              isTransition
                  ? 'Talking time is over. Attendance and referrals are closed for '
                      'round ${round.roundNumber}.'
                  : 'This round has ended. Waiting for the admin to start the next one.',
              style: context.text.bodySmall?.copyWith(
                color: isTransition
                    ? c.onWarningContainer
                    : context.scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The member's own code — what a captain scans to mark them present.
class _MyQrCard extends StatelessWidget {
  final ActiveRound round;

  const _MyQrCard({required this.round});

  @override
  Widget build(BuildContext context) {
    final payload = AttendanceQr(
      conclaveId: round.conclaveId,
      uid: round.currentUserId,
    ).encode();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, size: 20, color: context.scheme.primary),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Show this to your table captain',
                    style: context.text.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            // White plate regardless of theme: a scanner needs the quiet zone and
            // the contrast, and inverting a QR code in dark mode breaks it.
            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: QrImageView(
                data: payload,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: Gap.md),
            Text(
              'Works offline. Your captain can also mark you manually.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatCard extends StatelessWidget {
  final TableSeat seat;
  final bool? attendance;
  final bool canMark;
  final bool canRefer;
  final bool alreadyReferred;
  final ValueChanged<bool> onAttendance;
  final VoidCallback onRefer;
  final VoidCallback onAddNote;

  const _SeatCard({
    required this.seat,
    required this.attendance,
    required this.canMark,
    required this.canRefer,
    required this.alreadyReferred,
    required this.onAttendance,
    required this.onRefer,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final c = context.colors;

    // The card itself carries the answer. Once you've said you're here, the card
    // reads as settled at a glance — you shouldn't have to parse a control to
    // find out what you already told it.
    final accent = switch (attendance) {
      true => c.success,
      false => c.danger,
      null => null,
    };

    return AnimatedContainer(
      duration: Motion.normal,
      curve: Motion.curve,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: accent?.withValues(alpha: 0.45) ?? c.hairline,
          width: accent != null ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(seat: seat, attendance: attendance),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              seat.isSelf ? 'You' : seat.name,
                              style: context.text.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (seat.isCaptain) ...[
                            const SizedBox(width: Gap.sm),
                            Icon(Icons.star_rounded, size: 15, color: c.info),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        seat.businessName.isEmpty
                            ? seat.category
                            : '${seat.businessName} · ${seat.category}',
                        style: context.text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (alreadyReferred)
                  Tooltip(
                    message: 'You referred ${seat.name} this round',
                    child: Container(
                      padding: const EdgeInsets.all(Gap.sm),
                      decoration: BoxDecoration(
                        color: c.successContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.handshake_rounded,
                          size: 16, color: c.onSuccessContainer),
                    ),
                  ),
              ],
            ),

            if (canMark && attendance != true) ...[
              const SizedBox(height: Gap.lg),
              _AttendanceToggle(
                value: attendance,
                isSelf: seat.isSelf,
                onChanged: onAttendance,
              ),
            ],

            // A referral is a promise of business — the point of the whole
            // event — so giving one is a single tap. The note is optional and
            // comes after; making people fill in a dialog first put a form
            // between them and the thing they actually came to do.
            if (!seat.isSelf) ...[
              const SizedBox(height: Gap.sm),
              _ReferralAction(
                seat: seat,
                given: alreadyReferred,
                enabled: canRefer,
                onRefer: onRefer,
                onAddNote: onAddNote,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The avatar doubles as the attendance indicator once an answer exists.
class _Avatar extends StatelessWidget {
  final TableSeat seat;
  final bool? attendance;

  const _Avatar({required this.seat, required this.attendance});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = context.scheme;

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: seat.isSelf
                  ? scheme.secondaryContainer
                  : scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              seat.name.isEmpty ? '?' : seat.name[0].toUpperCase(),
              style: context.text.titleMedium?.copyWith(
                color: seat.isSelf
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (attendance != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: AnimatedScale(
                scale: 1,
                duration: Motion.normal,
                curve: Motion.spring,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: attendance! ? c.success : c.danger,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      attendance! ? Icons.check_rounded : Icons.close_rounded,
                      size: 11,
                      color: scheme.surface,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Attendance.
///
/// The rule: **Present is final; Absent is not.**
///
/// Being seen at the table is a fact — once recorded it is not up for revision,
/// and a control that invites you to un-see someone is nonsense. Absent is
/// different: it means "not seen YET". The real pattern at a venue is a captain
/// marking their table absent early and people trickling in over the next
/// minute, so absent must stay changeable or the roll is wrong by design.
///
/// So this widget only renders while the answer is still open. Once someone is
/// Present, the card shows the settled state instead (avatar badge + hairline)
/// and the control disappears — there is nothing left to decide.
class _AttendanceToggle extends StatelessWidget {
  final bool? value;
  final bool isSelf;
  final ValueChanged<bool> onChanged;

  const _AttendanceToggle({
    required this.value,
    required this.isSelf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final markedAbsent = value == false;

    return Semantics(
      label: isSelf ? 'Your attendance' : 'Attendance',
      value: markedAbsent ? 'Absent' : 'Not marked',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: context.scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.hairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Segment(
                    label: isSelf ? "I'm here" : 'Present',
                    icon: Icons.check_rounded,
                    selected: false,
                    color: c.success,
                    onTap: () => onChanged(true),
                  ),
                ),
                Expanded(
                  child: _Segment(
                    label: 'Absent',
                    icon: Icons.close_rounded,
                    selected: markedAbsent,
                    color: c.danger,
                    onTap: () => onChanged(false),
                  ),
                ),
              ],
            ),
          ),
          if (markedAbsent) ...[
            const SizedBox(height: Gap.sm),
            Text(
              isSelf
                  ? 'Tap "I\'m here" if you join the table.'
                  : 'Still changeable — tap Present if they arrive.',
              textAlign: TextAlign.center,
              style: context.text.labelSmall
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Giving a referral, and optionally annotating it.
///
/// One tap gives the referral. The note is optional and comes AFTER, in a sheet.
/// The previous flow opened a confirmation dialog with a text field before
/// anything was recorded — a form standing between the user and the single thing
/// the event exists for. Dialogs are for decisions with consequences; this is an
/// action, so it just happens, and the note is there for whoever wants it.
class _ReferralAction extends StatelessWidget {
  final TableSeat seat;
  final bool given;
  final bool enabled;
  final VoidCallback onRefer;
  final VoidCallback onAddNote;

  const _ReferralAction({
    required this.seat,
    required this.given,
    required this.enabled,
    required this.onRefer,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (given) {
      return Container(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
        decoration: BoxDecoration(
          color: c.successContainer,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: c.onSuccessContainer),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                'Referral given',
                style: context.text.labelLarge?.copyWith(
                  color: c.onSuccessContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onAddNote,
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Note'),
              style: TextButton.styleFrom(foregroundColor: c.onSuccessContainer),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? onRefer : null,
        icon: const Icon(Icons.handshake_outlined, size: 18),
        label: Text('Refer ${seat.name.split(' ').first}'),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? context.scheme.surface : context.scheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.curve,
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: Gap.xs),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the number of records still on the phone. At a venue with no signal this
/// is the only honest answer to "did my data save?", so it is always visible
/// rather than hidden behind a settings screen.
class _SyncButton extends StatelessWidget {
  final int pending;
  final VoidCallback onTap;

  const _SyncButton({required this.pending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final synced = pending == 0;

    return Tooltip(
      message: synced
          ? 'Everything is saved to the server'
          : '$pending record(s) waiting to upload',
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
          synced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
          size: 20,
          color: synced ? context.colors.success : context.colors.warning,
        ),
        label: Text(
          synced ? 'Saved' : '$pending',
          style: context.text.labelMedium?.copyWith(
            color: synced ? context.colors.success : context.colors.warning,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  final ActiveRoundUnavailable reason;

  const _Unavailable({required this.reason});

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = switch (reason) {
      ActiveRoundUnavailable.scheduleNotReady => (
          Icons.pending_outlined,
          'Schedule not ready',
          'The admin has not generated the seating yet. Your table will appear here '
              'once they do.',
        ),
      ActiveRoundUnavailable.notStarted => (
          Icons.hourglass_top,
          'Not started yet',
          'Your table will appear the moment round 1 begins.',
        ),
      ActiveRoundUnavailable.notInSnapshot => (
          Icons.person_search_outlined,
          'You are not on the list',
          'You are not in this conclave\'s participant list. If you registered late, '
              'ask the admin to regenerate the schedule.',
        ),
      ActiveRoundUnavailable.noTableThisRound => (
          Icons.table_restaurant_outlined,
          'No table this round',
          'No seat is assigned to you for this round. Please tell the admin.',
        ),
      ActiveRoundUnavailable.missingRoundStart => (
          Icons.timer_off_outlined,
          'Timer unavailable',
          'The round is running but has no recorded start time, so the countdown '
              'cannot be shown. Please tell the admin.',
        ),
      ActiveRoundUnavailable.completed => (
          Icons.celebration_outlined,
          'This conclave has finished',
          'Open your summary to see your referrals and check your data has synced.',
        ),
      ActiveRoundUnavailable.cancelled => (
          Icons.event_busy_outlined,
          'This conclave was cancelled',
          'The admin called it off. Anything you recorded is still saved on your '
              'phone and will sync, but there are no more rounds.',
        ),
    };

    return EmptyView(icon: icon, title: title, message: message);
  }
}
