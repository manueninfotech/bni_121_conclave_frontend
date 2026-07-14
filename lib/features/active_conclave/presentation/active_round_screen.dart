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

  Future<void> _giveReferral(ActiveRound round, TableSeat seat) async {
    if (!round.canRecordAt(_serverNow())) return;

    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.handshake_outlined),
        title: Text('Refer ${seat.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are promising to send business to ${seat.name}. '
              'This cannot be undone.',
              style: ctx.text.bodyMedium,
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: notes,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. Call my friend John at 555-1234',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Give referral'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Re-check the clock: the dialog may have been open when the round closed.
    if (!round.canRecordAt(_serverNow())) {
      _toast('Round closed — referral not recorded.');
      return;
    }

    final written = await ref.read(localDbProvider).addReferral(
          conclaveId: round.conclaveId,
          roundNumber: round.roundNumber,
          fromUserId: round.currentUserId,
          toUserId: seat.userId,
          toName: seat.name,
          toBusinessName: seat.businessName,
          notes: notes.text,
        );

    await _loadLocal(round);
    _toast(written
        ? 'Referral to ${seat.name} saved.'
        : 'You have already referred ${seat.name} this round.');
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
  final VoidCallback onScan;

  const _RoundView({
    required this.round,
    required this.now,
    required this.attendance,
    required this.referred,
    required this.onAttendance,
    required this.onRefer,
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
                  child: FilledButton.icon(
                    onPressed: canRecord ? onScan : null,
                    icon: const Icon(Icons.qr_code_scanner, size: 26),
                    label: Text(
                      canRecord ? 'Scan members' : 'Scanning closed',
                      style: context.text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
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

    return Semantics(
      label: '$label. ${remaining.inMinutes} minutes '
          '${remaining.inSeconds.remainder(60)} seconds remaining. '
          'Round ${round.roundNumber} of ${round.totalRounds}, table ${round.tableNumber}.',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.normal,
        curve: Motion.curve,
        padding: const EdgeInsets.all(Gap.xl),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: fg.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: Gap.sm),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: context.text.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.lg),

            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // A ring, because time remaining is easier to judge at a glance
                  // as a shape than as digits.
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: progress, end: progress),
                    duration: Motion.fast,
                    builder: (context, v, _) => SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: phase == RoundPhase.ended ? 0 : v,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        color: fg,
                        backgroundColor: fg.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.xl),
                      child: Text(
                        _fmt(remaining),
                        style: context.text.displaySmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Gap.lg),
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
                    label: 'You are the captain',
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

  const _SeatCard({
    required this.seat,
    required this.attendance,
    required this.canMark,
    required this.canRefer,
    required this.alreadyReferred,
    required this.onAttendance,
    required this.onRefer,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: seat.isSelf
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  child: Text(
                    seat.name.isEmpty ? '?' : seat.name[0].toUpperCase(),
                    style: context.text.titleMedium?.copyWith(
                      color: seat.isSelf
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seat.isSelf ? '${seat.name} (you)' : seat.name,
                        style: context.text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${seat.businessName} · ${seat.category}',
                        style: context.text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (seat.isCaptain || attendance != null || alreadyReferred) ...[
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  if (seat.isCaptain)
                    const StatusBadge(
                      label: 'Captain',
                      tone: StatusTone.info,
                      icon: Icons.star_outline,
                    ),
                  if (attendance != null)
                    StatusBadge(
                      label: attendance! ? 'Present' : 'Absent',
                      tone: attendance! ? StatusTone.success : StatusTone.danger,
                      icon: attendance! ? Icons.check : Icons.close,
                    ),
                  if (alreadyReferred)
                    const StatusBadge(
                      label: 'Referral given',
                      tone: StatusTone.success,
                      icon: Icons.handshake_outlined,
                    ),
                ],
              ),
            ],

            if (canMark || (!seat.isSelf && (canRefer || alreadyReferred))) ...[
              const SizedBox(height: Gap.md),
              // Stacks instead of overflowing when the font size is turned up.
              AdaptiveRow(
                children: [
                  if (canMark) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onAttendance(true),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(seat.isSelf ? "I'm here" : 'Present'),
                      ),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onAttendance(false),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Absent'),
                      ),
                    ),
                  ],
                  if (!seat.isSelf && !alreadyReferred)
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: canRefer ? onRefer : null,
                        icon: const Icon(Icons.handshake_outlined, size: 18),
                        label: const Text('Refer'),
                      ),
                    ),
                ],
              ),
            ],
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
    };

    return EmptyView(icon: icon, title: title, message: message);
  }
}
