import 'package:flutter/material.dart';
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

class ConclavesListScreen extends ConsumerStatefulWidget {
  const ConclavesListScreen({super.key});

  @override
  ConsumerState<ConclavesListScreen> createState() => _ConclavesListScreenState();
}

class _ConclavesListScreenState extends ConsumerState<ConclavesListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const _ongoing = {ConclaveStatus.running, ConclaveStatus.locked};
  static const _past = {ConclaveStatus.completed, ConclaveStatus.cancelled};

  /// Upcoming is the COMPLEMENT of the other two, so a status added later can
  /// never fall through the cracks and become invisible in the app.
  List<Conclave> _filter(List<Conclave> all, int tab) => switch (tab) {
        0 => all.where((c) => _ongoing.contains(c.status)).toList(),
        2 => all.where((c) => _past.contains(c.status)).toList(),
        _ => all
            .where((c) =>
                !_ongoing.contains(c.status) && !_past.contains(c.status))
            .toList(),
      };

  @override
  Widget build(BuildContext context) {
    final conclaves = ref.watch(conclavesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conclaves'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My profile',
            onPressed: () => context.push('/profile'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ongoing'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: conclaves.when(
        // A skeleton, not a spinner: it says what is coming and how much of it,
        // and the layout doesn't jump when the data lands.
        loading: () => const ConclaveListSkeleton(),
        error: (e, _) => ErrorView(
          message: 'Could not load conclaves.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(conclavesStreamProvider),
        ),
        data: (all) => TabBarView(
          controller: _tabController,
          children: List.generate(3, (tab) => _ConclaveList(
                conclaves: _filter(all, tab),
                tab: tab,
                onRefresh: () async {
                  ref.invalidate(conclavesStreamProvider);
                  // Wait for the rebuilt stream to actually produce a value —
                  // otherwise the spinner vanishes before the data arrives, which
                  // is what the old `Future.delayed(1s)` was papering over.
                  await ref.read(conclavesStreamProvider.future);
                },
              )),
        ),
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
      return RefreshIndicator(
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
              icon: Icons.event_outlined,
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

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ContentWidth(
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.pagePadding),
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

  (String, StatusTone, IconData) get _status => switch (conclave.status) {
        ConclaveStatus.running => ('Live', StatusTone.success, Icons.podcasts),
        ConclaveStatus.completed => ('Completed', StatusTone.neutral, Icons.check),
        ConclaveStatus.cancelled => ('Cancelled', StatusTone.danger, Icons.close),
        ConclaveStatus.registrationOpen =>
          ('Registration open', StatusTone.info, Icons.how_to_reg),
        _ => ('Upcoming', StatusTone.warning, Icons.schedule),
      };

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = _status;
    final isLive = conclave.status == ConclaveStatus.running;

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
                      style: context.text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusBadge(label: label, tone: tone, icon: icon),
                ],
              ),
              const SizedBox(height: Gap.md),

              InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Venue',
                value: conclave.venueLocation,
              ),
              InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: DateFormat('EEE, MMM d, yyyy').format(conclave.date),
              ),
              if (conclave.startTime != null)
                InfoRow(
                  icon: Icons.schedule,
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
                onPressed: () => context.push('/conclaves/${conclave.id}/active'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Join active round'),
              )
            : OutlinedButton.icon(
                onPressed: () => context.push('/conclaves/${conclave.id}'),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View details'),
              ),
      );
    }

    if (conclave.isRegistrationOpen) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => context.push('/conclaves/${conclave.id}/register'),
          icon: const Icon(Icons.how_to_reg),
          label: const Text('Register'),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: null,
        child: Text(
          conclave.status == ConclaveStatus.registrationNotOpen
              ? 'Registration not open yet'
              : 'Registration closed',
        ),
      ),
    );
  }
}
