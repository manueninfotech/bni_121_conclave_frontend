import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/illustrations.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/shimmer.dart';
import '../data/conclave_repository.dart';
import '../domain/conclave_model.dart';
import 'list/conclave_cards.dart';
import 'list/conclave_segments.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

class ConclavesListScreen extends ConsumerStatefulWidget {
  const ConclavesListScreen({super.key});

  @override
  ConsumerState<ConclavesListScreen> createState() =>
      _ConclavesListScreenState();
}

class _ConclavesListScreenState extends ConsumerState<ConclavesListScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the app must not leave a stale list up (e.g. a conclave that
    // went live, or ended, while we were backgrounded). Re-fetch on resume so
    // the status is current without waiting on the 30s poll or a manual pull (#13).
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(conclavesStreamProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  static const _ongoing = {ConclaveStatus.running, ConclaveStatus.locked};
  static const _past = {ConclaveStatus.completed, ConclaveStatus.cancelled};

  /// Upcoming is the COMPLEMENT of the other two, so a status added later can
  /// never fall through the cracks and become invisible in the app.
  List<Conclave> _filter(List<Conclave> all, int tab) => switch (tab) {
    0 => all.where((c) => _ongoing.contains(c.effectiveStatus)).toList(),
    2 => all.where((c) => _past.contains(c.effectiveStatus)).toList(),
    _ =>
      all
          .where(
            (c) =>
                !_ongoing.contains(c.effectiveStatus) &&
                !_past.contains(c.effectiveStatus),
          )
          .toList(),
  };

  /// Open on Ongoing when something is live, else Upcoming — once, on first
  /// data, so we never yank the member off a tab they picked.
  bool _pickedInitialTab = false;

  void _pickInitialTab(List<Conclave> all) {
    if (_pickedInitialTab || all.isEmpty) return;
    _pickedInitialTab = true;
    final anyLive = all.any((c) => _ongoing.contains(c.effectiveStatus));
    if (!anyLive) _tabController.index = 1;
  }

  @override
  Widget build(BuildContext context) {
    final conclaves = ref.watch(conclavesStreamProvider);
    final all = conclaves.asData?.value ?? const <Conclave>[];
    _pickInitialTab(all);
    final counts = [for (var t = 0; t < 3; t++) _filter(all, t).length];

    return Scaffold(
      // No app bar: the tinted header leads, with the segment switcher in it.
      body: Column(
        children: [
          _ConclavesHeader(
            live: counts[0],
            upcoming: counts[1],
            segments: ConclaveSegments(
              controller: _tabController,
              segments: [
                (label: 'Ongoing', count: counts[0]),
                (label: 'Upcoming', count: counts[1]),
                (label: 'Past', count: counts[2]),
              ],
            ),
          ),
          Expanded(
            child: conclaves.when(
              // A skeleton, not a spinner: it says what is coming and how much
              // of it, and the layout doesn't jump when the data lands.
              loading: () => const ConclaveListSkeleton(),
              error: (e, _) => ErrorView(
                message: 'Could not load conclaves.',
                detail: e.toString(),
                onRetry: () => ref.invalidate(conclavesStreamProvider),
              ),
              data: (all) => TabBarView(
                controller: _tabController,
                children: List.generate(
                  3,
                  (tab) => _ConclaveList(conclaves: _filter(all, tab), tab: tab),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tinted header: title, a live/upcoming summary, and the segment switcher.
class _ConclavesHeader extends StatelessWidget {
  final int live;
  final int upcoming;
  final Widget segments;
  const _ConclavesHeader({
    required this.live,
    required this.upcoming,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final parts = <String>[
      if (live > 0) '$live live',
      if (upcoming > 0) '$upcoming upcoming',
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        topInset + Gap.md,
        context.pagePadding,
        Gap.md,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.brandRed.withValues(alpha: 0.13),
            AppColors.brandRed.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conclaves',
              style: context.text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              parts.isEmpty ? 'Your networking events' : parts.join('  ·  '),
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.md),
            segments,
          ],
        ),
      ),
    );
  }
}

class _ConclaveList extends StatelessWidget {
  final List<Conclave> conclaves;
  final int tab;

  const _ConclaveList({required this.conclaves, required this.tab});

  @override
  Widget build(BuildContext context) {
    if (conclaves.isEmpty) {
      return ListView(
        physics: const ClampingScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
          EmptyView(
            art: switch (tab) {
              0 => const TablesIllustration(size: 130),
              _ => const EmptyCalendarIllustration(size: 110),
            },
            icon: CoolIcons.calendarEvent,
            title: switch (tab) {
              0 => 'Nothing live right now',
              2 => 'No past conclaves yet',
              _ => 'No upcoming conclaves',
            },
            message: switch (tab) {
              0 => 'When a conclave starts, it appears here.',
              2 => 'Conclaves you attend will be listed here, with your summary.',
              _ => 'New conclaves appear here once registration opens.',
            },
          ),
        ],
      );
    }

    return ContentWidth(
      child: ListView.separated(
        physics: const ClampingScrollPhysics(),
        // A tab root: content scrolls BEHIND the floating nav bar, so the
        // bottom is grown to keep the last card clear of it.
        padding: context.tabScrollInsets,
        itemCount: conclaves.length,
        separatorBuilder: (_, _) =>
            SizedBox(height: tab == 2 ? Gap.sm : Gap.md),
        itemBuilder: (context, i) {
          final c = conclaves[i];
          final card = switch (tab) {
            0 => LiveConclaveCard(conclave: c),
            2 => PastConclaveRow(conclave: c),
            _ => UpcomingConclaveCard(conclave: c),
          };
          return FadeSlideIn(index: i, child: card);
        },
      ),
    );
  }
}
