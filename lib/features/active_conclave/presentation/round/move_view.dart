import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/active_conclave_models.dart';
import '../../domain/attendance_qr.dart';
import 'animated_countdown.dart';
import 'card_backdrop.dart';
import 'round_avatar.dart';
import 'round_timer.dart';

/// The full-screen move window between rounds — one job, said once.
///
///  - Member:  "Move to Table X", the walk countdown, and their QR in the bottom
///             half, ready to show the captain the moment they arrive.
///  - Captain: "Stay at Table X · your next group is arriving", the incoming
///             members arriving one by one, and a button to start scanning them
///             straight into the next round.
///  - Last round (no next table): a calm "that's a wrap".
///
/// Behind it, a switching-tables doodle: people hopping from one table to the
/// next. Paused freezes everything.
class MoveView extends StatelessWidget {
  final ActiveRound round;
  final RoundTimer vm;
  final bool paused;
  final VoidCallback onScanArrivals;

  const MoveView({
    super.key,
    required this.round,
    required this.vm,
    required this.paused,
    required this.onScanArrivals,
  });

  @override
  Widget build(BuildContext context) {
    final next = round.nextTableNumber;
    // Transition = walking with a countdown; ended (manual mode) = waiting for
    // the organiser to start the next round.
    // No walking after the last round — nobody is moving anywhere.
    final walking = next != null &&
        vm.phase == RoundPhase.transition &&
        vm.remaining > Duration.zero;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Same flowing silk as the cards, in its faster "move" look.
        CardBackdrop(
          mood: paused ? CardMood.paused : CardMood.move,
          seed: 3.1,
        ),
        SafeArea(
          child: Padding(
            // SafeArea already clears the home indicator.
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(round: round, vm: vm, paused: paused, walking: walking),
                // The top half is the doodle's stage.
                const Spacer(flex: 3),
                if (next == null)
                  ..._wrap(context)
                else if (round.canScanArrivals)
                  ..._captain(context, next)
                else
                  ..._member(context, next, walking),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _member(BuildContext context, int next, bool walking) {
    final payload = AttendanceQr(
      conclaveId: round.conclaveId,
      uid: round.currentUserId,
    ).encode();
    final group = round.upcomingSeats.where((s) => !s.isSelf).toList();
    return [
      _Kicker('MOVE TO'),
      _BigTable(next),
      const SizedBox(height: Gap.xs),
      _Sub(walking
          ? 'Head over now — Round ${round.roundNumber + 1} starts soon.'
          : 'Take your seat — the organiser will start Round ${round.roundNumber + 1}.'),
      if (group.isNotEmpty) ...[
        const SizedBox(height: Gap.lg),
        _ArrivingRow(seats: group),
      ],
      const SizedBox(height: Gap.md),
      _FirstSpeaker(round: round),
      const Spacer(flex: 2),
      // Bottom: the code the captain scans on arrival (no captains, no
      // scanning — just the table and the group).
      if (round.attendanceEnabled)
        Flexible(
          flex: 6,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.all(Gap.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(data: payload, size: 200, backgroundColor: Colors.white),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Show this to the captain at Table $next',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: const Color(0xFF8A1020),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _captain(BuildContext context, int next) {
    final arriving = round.upcomingSeats.where((s) => !s.isSelf).toList();
    final staying = next == round.tableNumber;
    return [
      _Kicker(staying ? 'STAY AT' : 'MOVE TO'),
      _BigTable(next),
      const SizedBox(height: Gap.xs),
      _Sub(staying
          ? 'Your next group is arriving'
          : "You're captain there next round — scan everyone in"),
      const SizedBox(height: Gap.xl),
      _ArrivingRow(seats: arriving),
      const SizedBox(height: Gap.md),
      _FirstSpeaker(round: round),
      const Spacer(flex: 2),
      SizedBox(
        height: 56,
        child: FilledButton.icon(
          onPressed: onScanArrivals,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: kDeckBottom,
            textStyle:
                context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          icon: const Icon(Icons.qr_code_scanner, size: 24),
          label: const Text('Start scanning'),
        ),
      ),
    ];
  }

  List<Widget> _wrap(BuildContext context) => [
        _Kicker('THAT WAS THE LAST ROUND'),
        Text(
          "That's a wrap",
          textAlign: TextAlign.center,
          style: context.text.displaySmall
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: Gap.xs),
        _Sub('Your summary opens as soon as the conclave closes.'),
        const Spacer(flex: 3),
      ];
}

class _TopBar extends StatelessWidget {
  final ActiveRound round;
  final RoundTimer vm;
  final bool paused;
  final bool walking;
  const _TopBar({
    required this.round,
    required this.vm,
    required this.paused,
    required this.walking,
  });

  @override
  Widget build(BuildContext context) {
    final label = round.nextTableNumber == null
        ? 'ROUND ${round.roundNumber} OF ${round.totalRounds}'
        : 'ROUND ${round.roundNumber} → ${round.roundNumber + 1}';
    final style = context.text.titleSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
    );
    Widget? status;
    if (paused) {
      status = _pill(Icons.pause_rounded, Text('Paused', style: style),
          key: const ValueKey('paused'));
    } else if (walking) {
      status = _pill(
        Icons.directions_walk,
        AnimatedCountdown(remaining: vm.remaining, style: style),
        key: const ValueKey('walk'),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.text.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: status ?? const SizedBox.shrink(key: ValueKey('none')),
        ),
      ],
    );
  }

  Widget _pill(IconData icon, Widget label, {required Key key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 6),
        label,
      ]),
    );
  }
}

class _Kicker extends StatelessWidget {
  final String text;
  const _Kicker(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: context.text.labelLarge?.copyWith(
          color: Colors.white70,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      );
}

class _BigTable extends StatelessWidget {
  final int table;
  const _BigTable(this.table);
  @override
  Widget build(BuildContext context) => Text(
        'Table $table',
        textAlign: TextAlign.center,
        style: context.text.displayLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          height: 1.05,
        ),
      );
}

class _Sub extends StatelessWidget {
  final String text;
  const _Sub(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: context.text.bodyLarge?.copyWith(color: Colors.white),
      );
}

/// The incoming group, arriving one after another.
class _ArrivingRow extends StatefulWidget {
  final List<TableSeat> seats;
  const _ArrivingRow({required this.seats});
  @override
  State<_ArrivingRow> createState() => _ArrivingRowState();
}

class _ArrivingRowState extends State<_ArrivingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 500 + 180 * widget.seats.length),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.seats.length;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Gap.md,
      runSpacing: Gap.md,
      children: [
        for (var i = 0; i < n; i++)
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final start = n <= 1 ? 0.0 : (i / n) * 0.6;
              final p = Curves.easeOutBack.transform(
                  ((_c.value - start) / 0.4).clamp(0.0, 1.0));
              return Opacity(
                opacity: p.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(24 * (1 - p), 0),
                  child: child,
                ),
              );
            },
            child: _Arrival(seat: widget.seats[i]),
          ),
      ],
    );
  }
}

class _Arrival extends StatelessWidget {
  final TableSeat seat;
  const _Arrival({required this.seat});
  @override
  Widget build(BuildContext context) {
    final first = seat.name.split(' ').first;
    return SizedBox(
      width: 64,
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: seat.photoUrl != null
              ? Image.network(seat.photoUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => roundInitialAvatarText(context, seat))
              : roundInitialAvatarText(context, seat),
        ),
        const SizedBox(height: 4),
        Text(
          first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelMedium
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}

/// Who opens the next round, so they're ready the moment it starts (a late
/// first speaker eats their own bio time). Loud when it's you.
class _FirstSpeaker extends StatelessWidget {
  final ActiveRound round;
  const _FirstSpeaker({required this.round});

  @override
  Widget build(BuildContext context) {
    final order = round.arrivalsRound()?.speakingOrder ?? const <TableSeat>[];
    if (order.isEmpty) return const SizedBox.shrink();
    final first = order.first;
    final you = first.isSelf;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: you ? Colors.white : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.record_voice_over_rounded,
              size: 18, color: you ? kDeckBottom : Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              you
                  ? 'You speak first — be ready to start'
                  : 'First to speak: ${first.name.split(' ').first}',
              overflow: TextOverflow.ellipsis,
              style: context.text.labelLarge?.copyWith(
                color: you ? kDeckBottom : Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

