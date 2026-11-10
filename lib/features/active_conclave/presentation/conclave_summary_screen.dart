import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_refresh.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../data/conclave_summary_repository.dart';
import '../data/sync_service.dart';
import 'summary/summary_feedback.dart';
import 'summary/summary_hero.dart';
import 'summary/summary_journey.dart';
import 'summary/summary_widgets.dart';

/// After the conclave: the shape of the day, what came of it, and — quietly,
/// unless something is outstanding — whether it all made it off the phone.
///
/// Built from the local db (attendance, referrals given) reconciled with the
/// server on open, plus the frozen schedule for rounds and people met.
class ConclaveSummaryScreen extends ConsumerStatefulWidget {
  final String conclaveId;

  const ConclaveSummaryScreen({super.key, required this.conclaveId});

  @override
  ConsumerState<ConclaveSummaryScreen> createState() =>
      _ConclaveSummaryScreenState();
}

class _ConclaveSummaryScreenState extends ConsumerState<ConclaveSummaryScreen> {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    // Reconcile with the server the moment the summary opens: the local db is
    // missing what lived on other phones (referrals given TO this member,
    // attendance a captain recorded), so without this it can read 0 (#18).
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await ref.read(syncServiceProvider).syncNow(widget.conclaveId);
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
        ref.invalidate(conclaveSummaryProvider(widget.conclaveId));
      }
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/conclaves/${widget.conclaveId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.conclaveId;
    final summary = ref.watch(conclaveSummaryProvider(id));
    final journey =
        ref.watch(summaryJourneyProvider(id)).value ?? SummaryJourney.empty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar over the red hero.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: summary.when(
          loading: () => const LoadingView(),
          error: (e, _) => SafeArea(
            child: ErrorView(
              message: 'Could not load your summary.',
              detail: e.toString(),
              onRetry: () => ref.invalidate(conclaveSummaryProvider(id)),
            ),
          ),
          data: (s) {
            final presentByRound = {
              for (final a in s.attendance) a.roundNumber: a.isPresent,
            };
            final stops = [
              for (final r in journey.rounds)
                (
                  round: r.roundNumber,
                  table: r.tableNumber,
                  captain: r.wasCaptain,
                  tablemates: r.tablemates,
                  present: presentByRound[r.roundNumber],
                ),
            ];
            final refs = s.referrals;

            final sections = <Widget>[
              SummaryStats(referrals: refs, pendingSync: s.pendingSyncCount),
              if (journey.people.isNotEmpty) ...[
                const SizedBox(height: Gap.xl),
                SummarySection('People you met',
                    note: '${journey.people.length}'),
                SummaryPeople(
                  people: journey.people,
                  onOpen: () => context.push('/conclaves/$id/met'),
                ),
              ],
              if (stops.isNotEmpty) ...[
                const SizedBox(height: Gap.xl),
                SummarySection('Your rounds',
                    note: s.attendance.isEmpty
                        ? null
                        : '${s.roundsAttended} of ${stops.length} attended'),
                SummaryRounds(stops: stops),
              ],
              const SizedBox(height: Gap.xl),
              const SummarySection('Referrals you gave'),
              if (refs.given.isEmpty)
                const SummaryEmpty('You gave no referrals.')
              else
                SummaryReferrals(
                  referrals: refs.given,
                  outgoing: true,
                  isMutual: refs.isMutualWith,
                ),
              const SizedBox(height: Gap.xl),
              const SummarySection('Referrals you received'),
              if (refs.received.isEmpty)
                const SummaryEmpty(
                  "None yet. A referral to you is made on the other person's "
                  'phone, so it shows here once both phones have synced.',
                )
              else
                SummaryReferrals(
                  referrals: refs.received,
                  outgoing: false,
                  isMutual: refs.isMutualWith,
                ),
              const SizedBox(height: Gap.xl),
              SummaryFeedbackCard(conclaveId: id),
              SizedBox(height: Gap.xl + MediaQuery.paddingOf(context).bottom),
            ];

            return AppRefresh(
              onRefresh: _sync,
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  // One column, so the stats card (drawn after the hero) sits
                  // ON TOP of the hero's lower edge instead of under it.
                  SummaryHero(
                    conclaveName: journey.conclaveName,
                    rounds: journey.rounds.length,
                    peopleMet: journey.people.length,
                    syncing: _syncing,
                    onBack: _back,
                    onSync: _sync,
                  ),
                  ContentWidth(
                    child: Transform.translate(
                      offset: const Offset(0, -SummaryHero.overlap),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < sections.length; i++)
                              FadeSlideIn(index: i ~/ 3, child: sections[i]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
