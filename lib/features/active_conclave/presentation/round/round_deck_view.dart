import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/active_conclave_models.dart';
import 'deck_footer.dart';
import 'deck_header.dart';
import 'move_view.dart';
import 'person_card.dart';
import 'referral_sheet.dart';
import 'round_timer.dart';

/// The live round as a swipeable stack of table cards — one per person — with a
/// glanceable top strip, a "right now" band and an "up next" speaking strip.
/// Headerless by design; the deck auto-follows the current speaker.
class RoundDeckView extends StatefulWidget {
  final ActiveRound round;
  final DateTime now;
  final Map<String, bool> attendance;
  final Set<String> referred;
  final Set<String> noted;
  final int pendingSync;
  final VoidCallback onSync;
  final void Function(TableSeat, bool) onAttendance;
  final void Function(TableSeat) onRefer;
  final void Function(TableSeat) onAddNote;
  final VoidCallback onScan;

  /// Captain, during the move window: scan the incoming group into the next round.
  final VoidCallback onScanArrivals;

  const RoundDeckView({
    super.key,
    required this.round,
    required this.now,
    required this.attendance,
    required this.referred,
    required this.noted,
    required this.pendingSync,
    required this.onSync,
    required this.onAttendance,
    required this.onRefer,
    required this.onAddNote,
    required this.onScan,
    required this.onScanArrivals,
  });

  @override
  State<RoundDeckView> createState() => _RoundDeckViewState();
}

class _RoundDeckViewState extends State<RoundDeckView> {
  final PageController _pc = PageController(viewportFraction: 0.9);
  int _page = 0;
  int? _lastSpeakerId;
  DateTime _lastManualSwipe = DateTime.fromMillisecondsSinceEpoch(0);
  bool _animating = false;

  /// Live referred/noted state for an open referral sheet.
  late final ValueNotifier<ReferralSheetState> _sheetState =
      ValueNotifier((referred: widget.referred, noted: widget.noted));

  @override
  void didUpdateWidget(covariant RoundDeckView old) {
    super.didUpdateWidget(old);
    if (old.referred != widget.referred || old.noted != widget.noted) {
      // Push after the frame: the listener lives in another route (the sheet),
      // and marking it dirty mid-build of this one would assert.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _sheetState.value = (referred: widget.referred, noted: widget.noted);
        }
      });
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    _sheetState.dispose();
    super.dispose();
  }

  void _openReferralSheet() {
    showReferralSheet(
      context,
      tablemates: widget.round.speakingOrder.where((s) => !s.isSelf).toList(),
      state: _sheetState,
      onRefer: widget.onRefer,
      onNote: widget.onAddNote,
    );
  }

  @override
  Widget build(BuildContext context) {
    final round = widget.round;
    final now = widget.now;
    final vm = RoundTimer.of(round, now, context);
    final phase = round.phaseAt(now);

    // Between rounds the deck steps aside for the full-screen move view: one
    // job (get to Table X / scan your arriving group), said once.
    if (phase == RoundPhase.transition || phase == RoundPhase.ended) {
      return _handOff(
        'move',
        MoveView(
          round: round,
          vm: vm,
          paused: round.frozenAt != null,
          onScanArrivals: widget.onScanArrivals,
        ),
      );
    }

    // During the move window and the wait after it, the deck previews the NEXT
    // table's group (where the member is headed) instead of the group that just
    // finished.
    final showUpcoming = (phase == RoundPhase.transition ||
            phase == RoundPhase.ended) &&
        round.nextTableNumber != null &&
        round.upcomingSeats.isNotEmpty;
    final seats = showUpcoming ? round.upcomingSeats : round.speakingOrder;
    final currentTurn = round.currentTurnAt(now);
    final canRecord = round.canRecordAt(now);
    final referralOpen = round.isReferralOpenAt(now);
    // Paused: the repository hands us a frozen instant while the organiser holds
    // the round, so the clock stands still.
    final paused = round.frozenAt != null;

    final page = seats.isEmpty ? 0 : _page.clamp(0, seats.length - 1);

    // Auto-follow the speaker: when the floor passes to a new person, glide the
    // deck to their card — unless they just swiped to browse (a short grace
    // period keeps the deck from yanking back).
    final speakerId = currentTurn?.speaker.participantId;
    if (speakerId != null && speakerId != _lastSpeakerId) {
      _lastSpeakerId = speakerId;
      final idx = seats.indexWhere((s) => s.participantId == speakerId);
      if (idx >= 0 &&
          DateTime.now().difference(_lastManualSwipe) >
              const Duration(seconds: 6)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pc.hasClients) return;
          _animating = true;
          _pc
              .animateToPage(idx, duration: Motion.normal, curve: Curves.easeOut)
              .whenComplete(() => _animating = false);
        });
      }
    }

    return _handOff('deck', DecoratedBox(
      decoration: BoxDecoration(color: context.scheme.surface),
      child: SafeArea(
        child: Column(
          children: [
            DeckHeader(
              round: round,
              vm: vm,
              showUpcoming: showUpcoming,
              paused: paused,
              progress: _roundProgress(round, now),
              pendingSync: widget.pendingSync,
              onSync: widget.onSync,
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                onPageChanged: (i) {
                  if (!_animating) _lastManualSwipe = DateTime.now();
                  setState(() => _page = i);
                },
                itemCount: seats.length,
                itemBuilder: (context, i) {
                  final seat = seats[i];
                  final isSpeaker = currentTurn != null &&
                      currentTurn.speaker.participantId == seat.participantId;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                    child: PersonCard(
                      round: round,
                      seat: seat,
                      isSpeaker: isSpeaker,
                      turn: isSpeaker ? currentTurn : null,
                      now: now,
                      preview: showUpcoming,
                      paused: paused,
                      attendance: (round.isCaptain || seat.isSelf)
                          ? widget.attendance[seat.userId]
                          : null,
                      // Everyone may mark themselves present; marking others
                      // (scanning) is the captain's job, so not in a
                      // captainless conclave.
                      canMark: !showUpcoming &&
                          canRecord &&
                          (seat.isSelf ||
                              (round.isCaptain && round.attendanceEnabled)),
                      canRefer: !showUpcoming &&
                          referralOpen &&
                          !seat.isSelf &&
                          !widget.referred.contains(seat.userId),
                      // Notes belong to the referral slot only — a note IS a
                      // referral lead, so it's hidden during the bios.
                      canNote: !showUpcoming && referralOpen && !seat.isSelf,
                      alreadyReferred: widget.referred.contains(seat.userId),
                      hasNote: widget.noted.contains(seat.userId),
                      onAttendance: (p) => widget.onAttendance(seat, p),
                      onRefer: () => widget.onRefer(seat),
                      onAddNote: () => widget.onAddNote(seat),
                    ),
                  );
                },
              ),
            ),
            if (seats.length > 1) DeckDots(count: seats.length, index: page),
            // The light chrome: white panels on the page, red kept for the
            // card and the primary action. SafeArea already clears the home
            // indicator, so no extra bottom inset here.
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "Right now" guidance — hidden while paused: the header chip
                  // already says so, and a frozen round has no next action.
                  if (!paused) NowBand(vm: vm),
                  // Referral phase: one tap opens everyone at the table to
                  // refer — no swiping to find a card.
                  if (referralOpen && !showUpcoming && !paused) ...[
                    const SizedBox(height: Gap.sm),
                    _PrimaryAction(
                      icon: Icons.handshake_outlined,
                      label: 'Give a referral',
                      onPressed: _openReferralSheet,
                    ),
                  ],
                  if (!showUpcoming && round.speakingOrder.length > 1) ...[
                    const SizedBox(height: Gap.sm),
                    SpeakingOrderPanel(
                      order: round.speakingOrder,
                      currentTurn: currentTurn,
                      now: now,
                      passComplete: currentTurn == null,
                      selectedId:
                          seats.isEmpty ? null : seats[page].participantId,
                      onJump: (pid) {
                        final idx =
                            seats.indexWhere((s) => s.participantId == pid);
                        if (idx >= 0) {
                          _pc.animateToPage(idx,
                              duration: Motion.normal, curve: Curves.easeOut);
                        }
                      },
                    ),
                  ],
                  if (round.isCaptain) ...[
                    const SizedBox(height: Gap.sm),
                    _PrimaryAction(
                      icon: Icons.qr_code_scanner,
                      label: canRecord ? 'Scan members' : 'Scanning closed',
                      onPressed: canRecord ? widget.onScan : null,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }

  /// 0..1 through the round's talking time (bios + referrals + any extension).
  static double _roundProgress(ActiveRound round, DateTime now) {
    final total = round.activeEndsAt.difference(round.startTime).inMilliseconds;
    if (total <= 0) return 0;
    return now.difference(round.startTime).inMilliseconds / total;
  }

  /// Deck <-> move screen: a soft cross-fade with a slight settle, instead of a
  /// hard cut, so the room "turns over" between rounds.
  Widget _handOff(String key, Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(key), child: child),
    );
  }
}

/// The one red, full-width action on the light chrome (refer / scan).
class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kDeckBottom,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}
