import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../data/conclave_repository.dart';
import '../domain/conclave_model.dart';

/// One conclave: what it is, where, when, and the one thing you can do about it.
class ConclaveDetailScreen extends ConsumerWidget {
  final String conclaveId;

  const ConclaveDetailScreen({super.key, required this.conclaveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conclaves = ref.watch(conclavesStreamProvider);

    return Scaffold(
      body: conclaves.when(
        loading: () => const _Shell(child: LoadingView()),
        error: (e, _) => _Shell(
          child: ErrorView(
            message: 'Could not load this conclave.',
            detail: e.toString(),
            onRetry: () => ref.invalidate(conclavesStreamProvider),
          ),
        ),
        data: (all) {
          // The old code used `orElse: () => conclaves.first`, so a bad id
          // silently showed a DIFFERENT conclave — the user would be reading
          // someone else's event and never know.
          final conclave =
              all.where((c) => c.id == conclaveId).firstOrNull;

          if (conclave == null) {
            return _Shell(
              child: EmptyView(
                icon: Icons.search_off_rounded,
                title: 'Conclave not found',
                message: 'It may have been cancelled or removed.',
                action: FilledButton(
                  onPressed: () => context.go('/conclaves'),
                  child: const Text('Back to conclaves'),
                ),
              ),
            );
          }

          return _Detail(conclave: conclave);
        },
      ),
    );
  }
}

/// An app bar for the states where we have no conclave to title it with.
class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(title: const Text('Conclave')),
        Expanded(child: child),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  final Conclave conclave;

  const _Detail({required this.conclave});

  (String, StatusTone, IconData) get _status => switch (conclave.status) {
        ConclaveStatus.running => ('Live now', StatusTone.success, Icons.podcasts),
        ConclaveStatus.completed => ('Completed', StatusTone.neutral, Icons.check),
        ConclaveStatus.cancelled => ('Cancelled', StatusTone.danger, Icons.close),
        ConclaveStatus.registrationOpen =>
          ('Registration open', StatusTone.info, Icons.how_to_reg),
        ConclaveStatus.registrationNotOpen =>
          ('Registration not open yet', StatusTone.warning, Icons.lock_clock),
        _ => ('Upcoming', StatusTone.warning, Icons.schedule),
      };

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = _status;

    return CustomScrollView(
      slivers: [
        // A large title that collapses on scroll — gives the name room to
        // breathe on arrival, then gets out of the way.
        SliverAppBar.large(
          title: Text(conclave.name),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            // A manual leading button (unlike the auto-injected BackButton) gets
            // no default label, so a screen reader would announce a bare
            // "button". Name it.
            tooltip: 'Back',
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go('/conclaves'),
          ),
        ),
        SliverToBoxAdapter(
          child: ContentWidth(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                0,
                context.pagePadding,
                context.pagePadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(label: label, tone: tone, icon: icon),
                  const SizedBox(height: Gap.xl),

                  FadeSlideIn(
                    index: 0,
                    child: _Card(
                      children: [
                        InfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Venue',
                          value: conclave.venueLocation,
                        ),
                        InfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Date',
                          value: DateFormat('EEEE, MMMM d, yyyy')
                              .format(conclave.date),
                        ),
                        if (conclave.startTime != null)
                          InfoRow(
                            icon: Icons.schedule,
                            label: conclave.endTime != null ? 'Time' : 'Starts',
                            value: conclave.endTime != null
                                ? '${DateFormat('h:mm a').format(conclave.startTime!)}'
                                    ' – ${DateFormat('h:mm a').format(conclave.endTime!)}'
                                : DateFormat('h:mm a').format(conclave.startTime!),
                          ),
                      ],
                    ),
                  ),

                  if (conclave.isRegistered) ...[
                    const SizedBox(height: Gap.md),
                    FadeSlideIn(
                      index: 1,
                      child: _Card(
                        title: 'Your place',
                        children: [
                          InfoRow(
                            icon: conclave.userRole == ConclaveRole.captain
                                ? Icons.star_outline
                                : Icons.person_outline,
                            label: 'Role',
                            value: conclave.userRole == ConclaveRole.captain
                                ? 'Captain — you anchor a table'
                                : 'Member — you rotate each round',
                          ),
                          InfoRow(
                            icon: Icons.table_restaurant_outlined,
                            label: 'Table',
                            value: conclave.userTableNumber?.toString() ??
                                'Assigned when the schedule is published',
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (conclave.chiefGuests.isNotEmpty) ...[
                    const SizedBox(height: Gap.md),
                    FadeSlideIn(
                      index: 2,
                      child: _Card(
                        title: 'Chief guests',
                        children: [
                          for (final g in conclave.chiefGuests)
                            InfoRow(
                              icon: Icons.star_border_rounded,
                              label: 'Guest',
                              value: g,
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: Gap.md),
                  FadeSlideIn(
                    index: 3,
                    child: _Card(
                      title: 'How it works',
                      children: [
                        InfoRow(
                          icon: Icons.groups_outlined,
                          label: 'Table size',
                          value: '${conclave.personsPerTable} people, '
                              'including the captain',
                        ),
                        InfoRow(
                          icon: Icons.repeat,
                          label: 'Rounds',
                          value: '${conclave.roundCount} — you move tables each round',
                        ),
                        InfoRow(
                          icon: Icons.category_outlined,
                          label: 'Seating rule',
                          value: 'No two people from the same business category '
                              'ever share a table',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Gap.xl),
                  _Action(conclave: conclave),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _Card({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!.toUpperCase(),
                style: context.text.labelSmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Gap.sm),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Exactly one action, decided by state. A screen that offers three things at
/// once makes the user choose; this one already knows what they came for.
class _Action extends StatelessWidget {
  final Conclave conclave;

  const _Action({required this.conclave});

  @override
  Widget build(BuildContext context) {
    if (conclave.status == ConclaveStatus.running && conclave.isRegistered) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: () => context.push('/conclaves/${conclave.id}/active'),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Join active round'),
        ),
      );
    }

    if (conclave.status == ConclaveStatus.completed && conclave.isRegistered) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: () => context.push('/conclaves/${conclave.id}/summary'),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('View my summary'),
        ),
      );
    }

    if (conclave.isRegistrationOpen && !conclave.isRegistered) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: () => context.push('/conclaves/${conclave.id}/register'),
          icon: const Icon(Icons.how_to_reg),
          label: const Text('Register for this conclave'),
        ),
      );
    }

    if (conclave.isRegistered) {
      final c = context.colors;
      return Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: c.successContainer,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: c.onSuccessContainer),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                "You're registered. We'll show your table when it starts.",
                style: context.text.bodyMedium
                    ?.copyWith(color: c.onSuccessContainer),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: null,
        child: Text(
          conclave.status == ConclaveStatus.registrationNotOpen
              ? 'Registration opens soon'
              : 'Registration closed',
        ),
      ),
    );
  }
}
