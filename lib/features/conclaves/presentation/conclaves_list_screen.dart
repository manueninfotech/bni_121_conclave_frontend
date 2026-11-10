import 'package:flutter/material.dart';
import '../../../core/widgets/app_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/illustrations.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/shimmer.dart';
import '../data/conclave_repository.dart';
import '../domain/conclave_model.dart';
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

  @override
  Widget build(BuildContext context) {
    final conclaves = ref.watch(conclavesStreamProvider);
    final all = conclaves.asData?.value ?? const <Conclave>[];
    final live = all
        .where((c) => c.effectiveStatus == ConclaveStatus.running)
        .length;
    final upcoming = all
        .where(
          (c) =>
              !_ongoing.contains(c.effectiveStatus) &&
              !_past.contains(c.effectiveStatus),
        )
        .length;

    return Scaffold(
      // No app bar: a tinted header leads the screen (fills the bare top), with
      // the tab strip directly beneath it (#17 / #13).
      body: Column(
        children: [
          _ConclavesHeader(live: live, upcoming: upcoming),
          Material(
            color: context.scheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Ongoing'),
                Tab(text: 'Upcoming'),
                Tab(text: 'Past'),
              ],
            ),
          ),
          Expanded(
            child: conclaves.when(
              // A skeleton, not a spinner: it says what is coming and how much of
              // it, and the layout doesn't jump when the data lands.
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
                  (tab) => _ConclaveList(
                    conclaves: _filter(all, tab),
                    tab: tab,
                    onRefresh: () async {
                      ref.invalidate(conclavesStreamProvider);
                      await ref.read(conclavesStreamProvider.future);
                    },
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

/// Tinted header for the Conclaves tab: the title plus a live/upcoming count,
/// flowing straight into the tab strip.
class _ConclavesHeader extends StatelessWidget {
  final int live;
  final int upcoming;
  const _ConclavesHeader({required this.live, required this.upcoming});

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
        ],
      ),
    );
  }
}

class _ConclaveList extends StatelessWidget {
  final List<Conclave> conclaves;
  final int tab;
  final Future<void> Function() onRefresh;

  const _ConclaveList({
    required this.conclaves,
    required this.tab,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (conclaves.isEmpty) {
      // Always scrollable, so pull-to-refresh still works on an empty list.
      return AppRefresh(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            EmptyView(
              art: switch (tab) {
                0 => const TablesIllustration(size: 150),
                _ => const EmptyCalendarIllustration(size: 120),
              },
              icon: CoolIcons.calendarEvent,
              title: switch (tab) {
                0 => 'Nothing running right now',
                2 => 'No past conclaves',
                _ => 'No upcoming conclaves',
              },
              message: switch (tab) {
                0 => 'When a conclave starts, it will appear here.',
                2 => 'Conclaves you have attended will be listed here.',
                _ => 'New conclaves show up here once the admin opens them.',
              },
            ),
          ],
        ),
      );
    }

    return AppRefresh(
      onRefresh: onRefresh,
      child: ContentWidth(
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          // A tab root: content scrolls BEHIND the floating nav bar, so the
          // bottom is grown to keep the last card clear of it.
          padding: context.tabScrollInsets,
          itemCount: conclaves.length,
          separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
          itemBuilder: (context, i) => FadeSlideIn(
            index: i,
            child: _ConclaveCard(conclave: conclaves[i]),
          ),
        ),
      ),
    );
  }
}

class _ConclaveCard extends StatelessWidget {
  final Conclave conclave;

  const _ConclaveCard({required this.conclave});

  (String, StatusTone, IconData) get _status {
    // A registered member's own status comes first — "am I in?" is what they
    // scan for, not the conclave's registration window (which no longer concerns
    // them). Live / completed / cancelled still win, because those drive the next
    // action (join, view summary) and the action button already says so.
    if (conclave.isRegistered &&
        conclave.effectiveStatus != ConclaveStatus.running &&
        conclave.effectiveStatus != ConclaveStatus.completed &&
        conclave.effectiveStatus != ConclaveStatus.cancelled) {
      return ('Registered', StatusTone.success, CoolIcons.circleCheckFill);
    }
    return switch (conclave.effectiveStatus) {
      ConclaveStatus.running => (
        'Live',
        StatusTone.success,
        CoolIcons.broadcast,
      ),
      ConclaveStatus.completed => (
        'Completed',
        StatusTone.neutral,
        CoolIcons.check,
      ),
      ConclaveStatus.cancelled => (
        'Cancelled',
        StatusTone.danger,
        CoolIcons.close,
      ),
      ConclaveStatus.registrationOpen => (
        'Registration open',
        StatusTone.info,
        CoolIcons.userCheckCorner,
      ),
      _ => ('Upcoming', StatusTone.warning, CoolIcons.clock),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = _status;
    final isLive = conclave.effectiveStatus == ConclaveStatus.running;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/conclaves/${conclave.id}'),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wrap, not Row: at a large font size the title and badge cannot
              // both fit on one line, and a Row would overflow.
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.55,
                    ),
                    child: Text(
                      conclave.name,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusBadge(label: label, tone: tone, icon: icon),
                ],
              ),
              const SizedBox(height: Gap.md),

              InfoRow(
                icon: CoolIcons.mapPin,
                label: 'Venue',
                value: conclave.venueLocation,
              ),
              InfoRow(
                icon: CoolIcons.calendar,
                label: 'Date',
                value: DateFormat('EEE, MMM d, yyyy').format(conclave.date),
              ),
              if (conclave.startTime != null)
                InfoRow(
                  icon: CoolIcons.clock,
                  label: 'Starts',
                  value: DateFormat('h:mm a').format(conclave.startTime!),
                ),

              const SizedBox(height: Gap.lg),
              _CardAction(conclave: conclave, isLive: isLive),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final Conclave conclave;
  final bool isLive;

  const _CardAction({required this.conclave, required this.isLive});

  @override
  Widget build(BuildContext context) {
    if (conclave.isRegistered) {
      return SizedBox(
        width: double.infinity,
        child: isLive
            ? FilledButton.icon(
                onPressed: () =>
                    context.push('/conclaves/${conclave.id}/active'),
                icon: const Icon(CoolIcons.playFill),
                label: const Text('Join active round'),
              )
            : OutlinedButton.icon(
                onPressed: () => context.push('/conclaves/${conclave.id}'),
                icon: const Icon(CoolIcons.eye),
                label: const Text('View details'),
              ),
      );
    }

    if (conclave.canRegister) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => context.push('/conclaves/${conclave.id}/register'),
          icon: const Icon(CoolIcons.userCheckCorner),
          label: const Text('Register'),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: null,
        child: Text(switch (conclave.effectiveStatus) {
          ConclaveStatus.completed => 'Ended',
          ConclaveStatus.cancelled => 'Cancelled',
          ConclaveStatus.registrationNotOpen => 'Registration not open yet',
          _ => 'Registration closed',
        }),
      ),
    );
  }
}
