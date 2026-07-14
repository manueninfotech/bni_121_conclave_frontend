import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/time/server_clock.dart';
import '../data/active_conclave_repository.dart';
import '../data/local_db.dart';
import '../data/notification_service.dart';
import '../data/sync_service.dart';
import '../domain/active_conclave_models.dart';
import '../domain/attendance_qr.dart';
import 'captain_scanner_screen.dart';

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
  int? _loadedRound;

  @override
  void initState() {
    super.initState();
    _now = _serverNow();

    // Drives the countdown and, with it, the enable/disable state of the
    // attendance and referral controls.
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
    if (!mounted) return;
    setState(() {
      _attendance = attendance;
      _referred = referred;
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

    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Give referral to ${seat.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A referral cannot be changed once given.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. Call my friend John at 555-1234',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
          // Capture who this is NOW. After the conclave there is no table roster
          // left to resolve the uid against.
          toName: seat.name,
          toBusinessName: seat.businessName,
          notes: notesController.text,
        );

    await _loadLocal(round);
    _toast(written
        ? 'Referral to ${seat.name} saved offline.'
        : 'You have already referred ${seat.name} this round.');
  }

  Future<void> _openScanner(ActiveRound round) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CaptainScannerScreen(round: round)),
    );
    // The scanner wrote straight to sqflite; pull those rows back in.
    await _loadLocal(round);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeRoundProvider(widget.conclaveId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Round'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync now',
            onPressed: () async {
              _toast('Syncing…');
              await ref.read(syncServiceProvider).syncNow(widget.conclaveId);
              _toast('Sync attempted.');
            },
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (s) {
          final round = s.round;
          if (round == null) {
            return _UnavailableView(reason: s.unavailable!);
          }

          // First paint of a round (or after the admin advances): pull the
          // offline records for it.
          if (_loadedRound != round.roundNumber) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _loadLocal(round));
          }

          return _buildRound(round);
        },
      ),
    );
  }

  Widget _buildRound(ActiveRound round) {
    final phase = round.phaseAt(_now);
    final canRecord = round.canRecordAt(_now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimerHeader(round: round, phase: phase, remaining: round.remainingAt(_now)),
        if (!canRecord)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.orange.withValues(alpha: 0.15),
            child: Text(
              phase == RoundPhase.transition
                  ? 'Talking time is over — move to your next table. Attendance and referrals are closed.'
                  : 'This round has ended. Waiting for the admin to start the next round.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Table ${round.tableNumber} · Round ${round.roundNumber} of ${round.totalRounds}'
                '${round.isCaptain ? ' · You are the captain' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Captains capture the table's attendance by scanning; members
              // present the code that gets scanned. Both work with no network.
              if (round.isCaptain)
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan members to mark attendance'),
                  onPressed: canRecord ? () => _openScanner(round) : null,
                )
              else
                _MyQrCard(round: round),
              const SizedBox(height: 16),
              for (final seat in round.seats)
                _SeatTile(
                  seat: seat,
                  // Captains see the whole table's attendance; members only
                  // ever see their own.
                  attendance: (round.isCaptain || seat.isSelf)
                      ? _attendance[seat.userId]
                      : null,
                  showAttendanceControl: canRecord &&
                      (seat.isSelf || round.isCaptain),
                  canRefer: canRecord &&
                      !seat.isSelf &&
                      !_referred.contains(seat.userId),
                  alreadyReferred: _referred.contains(seat.userId),
                  onAttendance: (present) => _setAttendance(round, seat, present),
                  onRefer: () => _giveReferral(round, seat),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The member's own QR code — what the captain scans to mark them present.
///
/// Rendered on-device so it works with no network. The same payload is what
/// gets printed on the name badge, so a member with a dead phone is still
/// scannable.
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Show this to your table captain',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            QrImageView(data: payload, size: 180),
          ],
        ),
      ),
    );
  }
}

class _TimerHeader extends StatelessWidget {
  final ActiveRound round;
  final RoundPhase phase;
  final Duration remaining;

  const _TimerHeader({
    required this.round,
    required this.phase,
    required this.remaining,
  });

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (phase) {
      RoundPhase.active => (Colors.green, 'ACTIVE ROUND', Icons.timer),
      RoundPhase.transition => (Colors.orange, 'TRANSITION', Icons.directions_walk),
      RoundPhase.ended => (Colors.grey, 'ROUND ENDED', Icons.hourglass_empty),
    };

    return Container(
      padding: const EdgeInsets.all(24),
      color: color.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 44),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                _fmt(remaining),
                style: TextStyle(
                  color: color,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  final TableSeat seat;
  final bool? attendance;
  final bool showAttendanceControl;
  final bool canRefer;
  final bool alreadyReferred;
  final ValueChanged<bool> onAttendance;
  final VoidCallback onRefer;

  const _SeatTile({
    required this.seat,
    required this.attendance,
    required this.showAttendanceControl,
    required this.canRefer,
    required this.alreadyReferred,
    required this.onAttendance,
    required this.onRefer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${seat.name}'
                    '${seat.isSelf ? ' (you)' : ''}'
                    '${seat.isCaptain ? ' · Captain' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (attendance != null)
                  Chip(
                    label: Text(attendance! ? 'Present' : 'Absent'),
                    backgroundColor: (attendance! ? Colors.green : Colors.red)
                        .withValues(alpha: 0.12),
                  ),
              ],
            ),
            Text(
              '${seat.businessName} • ${seat.category}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (showAttendanceControl) ...[
                  TextButton(
                    onPressed: () => onAttendance(true),
                    child: Text(seat.isSelf ? 'I am here' : 'Present'),
                  ),
                  TextButton(
                    onPressed: () => onAttendance(false),
                    child: const Text('Absent'),
                  ),
                ],
                const Spacer(),
                if (!seat.isSelf)
                  ElevatedButton(
                    onPressed: canRefer ? onRefer : null,
                    child: Text(alreadyReferred ? 'Referral given' : 'Give referral'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableView extends StatelessWidget {
  final ActiveRoundUnavailable reason;

  const _UnavailableView({required this.reason});

  @override
  Widget build(BuildContext context) {
    final message = switch (reason) {
      ActiveRoundUnavailable.scheduleNotReady =>
        'The schedule has not been generated yet. Check back once the admin publishes it.',
      ActiveRoundUnavailable.notStarted =>
        'The conclave has not started. Your table will appear when round 1 begins.',
      ActiveRoundUnavailable.notInSnapshot =>
        'You are not in this conclave\'s participant list. If you registered late, ask the admin to regenerate the schedule.',
      ActiveRoundUnavailable.noTableThisRound =>
        'No table is assigned to you for this round. Please tell the admin.',
      ActiveRoundUnavailable.missingRoundStart =>
        'The round is running but has no recorded start time, so the timer cannot be shown. Please tell the admin.',
      ActiveRoundUnavailable.completed =>
        'This conclave has finished.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
