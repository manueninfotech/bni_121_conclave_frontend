import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/server_clock.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/active_conclave_repository.dart';
import '../data/live_lock.dart';
import '../data/local_db.dart';
import '../data/notification_service.dart';
import '../data/sync_service.dart';
import '../domain/active_conclave_models.dart';
import 'captain_scanner_screen.dart';
import 'round/round_deck_view.dart';

/// The screen people actually use at the event.
///
/// This widget is the controller: it owns the ticking clock, the offline record
/// state, the Rapido lock, and the write actions (attendance, referral, note,
/// scan, sync). The live-round UI itself is the swipeable card deck under
/// `round/` — see [RoundDeckView].
class ActiveRoundScreen extends ConsumerStatefulWidget {
  final String conclaveId;

  const ActiveRoundScreen({super.key, required this.conclaveId});

  @override
  ConsumerState<ActiveRoundScreen> createState() => _ActiveRoundScreenState();
}

class _ActiveRoundScreenState extends ConsumerState<ActiveRoundScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  /// Server-corrected clock. Round boundaries are set by the server, so the
  /// device clock must never be trusted to decide when a round opens or closes.
  DateTime _serverNow() => ref.read(serverClockProvider).now();

  /// Local (offline) state for the round currently on screen.
  Map<String, bool> _attendance = {};
  Set<String> _referred = {};
  Set<String> _noted = {};
  int _pendingSync = 0;
  int? _loadedRound;

  @override
  void initState() {
    super.initState();
    _now = _serverNow();
    WidgetsBinding.instance.addObserver(this);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = _serverNow());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).startSyncTimer(widget.conclaveId);
      ref.read(notificationServiceProvider).subscribe(widget.conclaveId);
    });
    // Foreground round alerts are surfaced app-wide as a real notification (see
    // the onMessage handler in app.dart), so this screen no longer double-toasts.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The live round rides a Server-Sent-Events stream. When the phone is locked
    // or pocketed — which is exactly when a round ends and the admin advances —
    // iOS suspends the app and freezes that stream, so the move instruction
    // ("Go to Table N") for the next round can arrive late or not at all until
    // the SSE reconnects on its own (backoff up to ~30s). On foreground we force
    // an immediate catch-up: re-subscribe the live stream (refetches the current
    // round) and flush/clock-sync, so the right round and move table show at once.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(activeRoundProvider(widget.conclaveId));
      ref.read(syncServiceProvider).syncNow(widget.conclaveId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    // The ongoing round sticky is NOT cancelled here: it is owned app-wide by
    // roundStickyDriverProvider so it persists while the member is on another
    // screen or has the phone pocketed. It clears itself when the round ends.
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
    final noted = await db.getNotedUserIdsForRound(
      conclaveId: round.conclaveId,
      roundNumber: round.roundNumber,
      fromUserId: round.currentUserId,
    );
    final pending = await db.pendingRecordCount();

    if (!mounted) return;
    setState(() {
      _attendance = attendance;
      _referred = referred;
      _noted = noted;
      _pendingSync = pending;
      _loadedRound = round.roundNumber;
    });
  }

  /// Push a freshly-captured record to the server right away instead of waiting
  /// for the 30s timer or a connectivity change. Fire-and-forget: syncNow leaves
  /// anything it can't push unsynced, and the timer/foreground flush retries (#8).
  void _pushSoon(String conclaveId) {
    unawaited(ref.read(syncServiceProvider).syncNow(conclaveId));
  }

  Future<void> _setAttendance(
      ActiveRound round, TableSeat seat, bool present) async {
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
    _pushSoon(round.conclaveId);
  }

  /// Gives a referral immediately — one tap, no dialog.
  ///
  /// The note is optional and offered afterwards. A confirmation dialog with a
  /// text field put a form between the user and the single action the whole
  /// event exists for.
  Future<void> _giveReferral(ActiveRound round, TableSeat seat) async {
    // Referrals only in the referral slot, after everyone's bio.
    if (!round.isReferralOpenAt(_serverNow())) return;

    final written = await ref.read(localDbProvider).addReferral(
          conclaveId: round.conclaveId,
          roundNumber: round.roundNumber,
          fromUserId: round.currentUserId,
          toUserId: seat.userId,
          toName: seat.name,
          toBusinessName: seat.businessName,
        );

    if (written) {
      Analytics.referralPassed();
      _pushSoon(round.conclaveId);
    }
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
          // Short-lived, floating and with an explicit close: the confirmation
          // must get out of the way on its own and be dismissible without having
          // to tap "Add note" (a note is optional). (#9)
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          showCloseIcon: true,
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
            // A referral is a business lead — pull the person's name + number
            // straight from the phone's contacts instead of typing it (#7). Uses
            // the OS picker. Tap again to add more than one.
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Drop the keyboard before the OS picker takes over, and keep
                  // it down when we come back with the contact.
                  FocusManager.instance.primaryFocus?.unfocus();
                  // Ask the picker for the phone number too — a referral is a
                  // lead, so the note needs "name;number", not just the name.
                  // iOS returns the number permissionlessly; Android needs
                  // READ_CONTACTS, so request it there first (falls through to a
                  // name-only picker if the member declines).
                  if (Platform.isAndroid) {
                    await FlutterContacts.permissions
                        .request(PermissionType.read);
                  }
                  Contact? contact;
                  try {
                    contact = await FlutterContacts.native
                        .showPicker(properties: {ContactProperty.phone});
                  } on PlatformException {
                    contact = await FlutterContacts.native.showPicker();
                  }
                  if (contact == null) return;
                  final name = (contact.displayName ?? '').trim();
                  final number = contact.phones.isNotEmpty
                      ? contact.phones.first.number.trim()
                      : '';
                  final entry = number.isEmpty ? name : '$name;$number';
                  if (entry.isEmpty) return;
                  final current = controller.text.trimRight();
                  controller.text =
                      current.isEmpty ? entry : '$current\n$entry';
                  controller.selection = TextSelection.collapsed(
                      offset: controller.text.length);
                  // Don't re-raise the keyboard after picking a contact.
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                icon: const Icon(Icons.contacts_outlined, size: 18),
                label: const Text('Add from contacts'),
              ),
            ),
            const SizedBox(height: Gap.sm),
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
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save note'),
              ),
            ),
          ],
        ),
      ),
    );

    // The sheet can be dismissed by swipe/tap-out with the keyboard still up —
    // drop focus so it doesn't linger over the deck.
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();

    if (saved != true) return;

    await ref.read(localDbProvider).updateReferralNote(
          conclaveId: round.conclaveId,
          roundNumber: round.roundNumber,
          fromUserId: round.currentUserId,
          toUserId: seat.userId,
          notes: controller.text,
        );
    await _loadLocal(round);
    _pushSoon(round.conclaveId);
    _toast('Note saved.');
  }

  Future<void> _openScanner(ActiveRound round) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CaptainScannerScreen(round: round)),
    );
    await _loadLocal(round);
  }

  /// Captain, during the move window: scan the incoming group straight into the
  /// NEXT round (its table and group), so arrivals are recorded as they walk up.
  Future<void> _openArrivalsScanner(ActiveRound round) async {
    final next = round.arrivalsRound();
    if (next == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptainScannerScreen(round: next, arrivals: true),
      ),
    );
    _pushSoon(round.conclaveId);
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
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        showCloseIcon: true,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeRoundProvider(widget.conclaveId));
    // Rapido lock: while this conclave's round is the live one, block the
    // Android back button/gesture so the member can't leave the active round.
    // (The router redirect would bounce them back anyway; this prevents a flash.)
    final locked = ref.watch(liveConclaveProvider)?.id == widget.conclaveId;

    return PopScope(
      canPop: !locked,
      child: Scaffold(
        // The note sheet is a modal that handles its own keyboard inset; the
        // deck behind must NOT resize, or its fixed-height cards overflow.
        resizeToAvoidBottomInset: false,
        // Headerless by design — the deck owns its own top strip. Tapping the
        // screen dismisses a lingering keyboard (swiping the note sheet away can
        // leave it up on iOS); translucent so the deck's own taps/swipes still win.
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: state.when(
          // Keep the current round on screen while a resume-triggered refresh
          // re-subscribes the live stream, rather than flashing the loader.
          skipLoadingOnReload: true,
          loading: () => const LoadingView(label: 'Finding your table…'),
          error: (e, _) => ErrorView(
            message: 'Could not load the round.',
            detail: e.toString(),
            onRetry: () => ref.invalidate(activeRoundProvider(widget.conclaveId)),
          ),
          data: (s) {
            final round = s.round;
            if (round == null) {
              return _Unavailable(reason: s.unavailable!);
            }

            // First paint of a round (or when the admin advances): pull the
            // offline records for it.
            if (_loadedRound != round.roundNumber) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _loadLocal(round));
            }

            // While paused, evaluate everything at the round's frozen instant so
            // the countdown holds steady instead of flickering against the live
            // clock. Running: use the live tick.
            final effectiveNow = round.frozenAt ?? _now;

            return RoundDeckView(
              round: round,
              now: effectiveNow,
              attendance: _attendance,
              referred: _referred,
              noted: _noted,
              pendingSync: _pendingSync,
              onSync: _syncNow,
              onAttendance: (seat, present) =>
                  _setAttendance(round, seat, present),
              onRefer: (seat) => _giveReferral(round, seat),
              onAddNote: (seat) => _editNote(round, seat),
              onScan: () => _openScanner(round),
              onScanArrivals: () => _openArrivalsScanner(round),
            );
          },
          ),
        ),
      ),
    );
  }
}

/// Why there is no live round to show — each reason rendered as a calm empty
/// state rather than an error.
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
