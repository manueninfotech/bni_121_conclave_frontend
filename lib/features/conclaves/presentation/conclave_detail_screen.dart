import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/conclave_calendar.dart';
import '../../../core/theme/cool_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../active_conclave/presentation/round/card_backdrop.dart';
import '../../active_conclave/presentation/round/deck_footer.dart' show roundPanel;
import '../../active_conclave/presentation/round/round_timer.dart' show kDeckBottom;
import '../data/conclave_repository.dart';
import '../domain/conclave_model.dart';
import 'specific_ask_card.dart';
import 'walk_in_action.dart';

/// One conclave: what it is, when and where, how it runs, your place in it —
/// and the one thing you can do about it, pinned at the bottom.
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
          // Never fall back to another conclave for a bad id — the member
          // would be reading someone else's event and never know.
          final conclave = all.where((c) => c.id == conclaveId).firstOrNull;
          if (conclave == null) {
            return _Shell(
              child: EmptyView(
                icon: CoolIcons.searchClose,
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

/// A plain bar for the states where there is no conclave to show.
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

void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/conclaves');

class _Detail extends StatelessWidget {
  final Conclave conclave;
  const _Detail({required this.conclave});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final action = _actionFor(context, c);
    final status = c.effectiveStatus;
    final upcoming = status != ConclaveStatus.running &&
        status != ConclaveStatus.completed &&
        status != ConclaveStatus.cancelled;

    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _Hero(conclave: c),
              // Drawn after the hero, so it sits ON its lower edge.
              ContentWidth(
                child: Transform.translate(
                  offset: const Offset(0, -_Hero.overlap),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      0,
                      context.pagePadding,
                      Gap.lg + (action == null ? context.bottomInset : 0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Numbers(conclave: c, upcoming: upcoming),
                        if (c.isRegistered) ...[
                          const SizedBox(height: Gap.xl),
                          const _Label('Your place'),
                          _YourPlace(conclave: c),
                          const SizedBox(height: Gap.md),
                          SpecificAskCard(conclave: c),
                        ],
                        const SizedBox(height: Gap.xl),
                        const _Label('Details'),
                        _Details(conclave: c, upcoming: upcoming),
                        const SizedBox(height: Gap.xl),
                        const _Label('How it works'),
                        _HowItWorks(conclave: c),
                        if (c.chiefGuests.isNotEmpty) ...[
                          const SizedBox(height: Gap.xl),
                          const _Label('Chief guests'),
                          _Guests(names: c.chiefGuests),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (action != null) _ActionBar(child: action),
      ],
    );
  }

  /// Exactly one action, decided by state — or none when there is nothing to
  /// do (the hero's status already says ended / cancelled / closed).
  Widget? _actionFor(BuildContext context, Conclave c) {
    final status = c.effectiveStatus;
    if (status == ConclaveStatus.running && c.isRegistered) {
      return _Primary(
        icon: CoolIcons.playFill,
        label: 'Join active round',
        onTap: () => context.push('/conclaves/${c.id}/active'),
      );
    }
    if (status == ConclaveStatus.completed && c.isRegistered) {
      return _Primary(
        icon: CoolIcons.receipt,
        label: 'View my summary',
        onTap: () => context.push('/conclaves/${c.id}/summary'),
      );
    }
    if (status == ConclaveStatus.running &&
        !c.isRegistered &&
        (c.walkInStatus == 'pending' || c.walkInOpen)) {
      return WalkInAction(conclave: c);
    }
    if (c.canRegister && !c.isRegistered) {
      return _Primary(
        icon: CoolIcons.userCheckCorner,
        label: 'Register for this conclave',
        onTap: () => context.push('/conclaves/${c.id}/register'),
      );
    }
    return null;
  }
}

/// The page's header, in the same language as the summary: one band with
/// rounded bottom corners and the back button inside it. Silk when the
/// conclave is live (the one red moment), a soft tint otherwise.
class _Hero extends StatelessWidget {
  final Conclave conclave;
  const _Hero({required this.conclave});

  /// How far the numbers card rides up over the hero's lower edge.
  static const double overlap = 40;

  (String, IconData) get _kicker {
    final c = conclave;
    final status = c.effectiveStatus;
    if (c.isRegistered &&
        status != ConclaveStatus.running &&
        status != ConclaveStatus.completed &&
        status != ConclaveStatus.cancelled) {
      return ("YOU'RE REGISTERED", CoolIcons.circleCheckFill);
    }
    return switch (status) {
      ConclaveStatus.running => ('LIVE NOW', CoolIcons.broadcast),
      ConclaveStatus.completed => (c.isRegistered ? 'ATTENDED' : 'ENDED', CoolIcons.check),
      ConclaveStatus.cancelled => ('CANCELLED', CoolIcons.close),
      ConclaveStatus.registrationOpen => ('REGISTRATION OPEN', CoolIcons.userCheckCorner),
      ConclaveStatus.registrationNotOpen => ('REGISTRATION OPENS SOON', CoolIcons.clock),
      _ => ('REGISTRATION CLOSED', CoolIcons.lock),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final live = c.effectiveStatus == ConclaveStatus.running;
    final ink = live ? Colors.white : context.scheme.onSurface;
    final soft = live ? Colors.white.withValues(alpha: 0.85) : context.scheme.onSurfaceVariant;
    final (kicker, kickerIcon) = _kicker;
    final time = c.startTime == null
        ? null
        : c.endTime == null
            ? DateFormat('h:mm a').format(c.startTime!)
            : '${DateFormat('h:mm a').format(c.startTime!)} – ${DateFormat('h:mm a').format(c.endTime!)}';
    final top = MediaQuery.paddingOf(context).top;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        children: [
          Positioned.fill(
            child: live
                ? const CardBackdrop(mood: CardMood.bio, seed: 4.4)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.alphaBlend(
                            AppColors.brandRed.withValues(alpha: 0.14),
                            context.scheme.surface,
                          ),
                          Color.alphaBlend(
                            AppColors.brandRed.withValues(alpha: 0.05),
                            context.scheme.surface,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          ContentWidth(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding - Gap.sm,
                top + Gap.xs,
                context.pagePadding,
                Gap.xl + overlap,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => _back(context),
                    icon: Icon(CoolIcons.arrowLeft, color: ink),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: Gap.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: Gap.sm),
                        Row(children: [
                          Icon(kickerIcon, size: 14, color: soft),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              kicker,
                              style: context.text.labelMedium?.copyWith(
                                color: soft,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: Gap.xs),
                        Text(
                          c.name,
                          style: context.text.headlineMedium?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: Gap.sm),
                        Text(
                          [DateFormat('EEE, d MMM yyyy').format(c.date), ?time].join('  ·  '),
                          style: context.text.bodyMedium?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.venueLocation,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(color: soft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three numbers in one white card, overlapping the hero (as on the summary).
class _Numbers extends StatelessWidget {
  final Conclave conclave;
  final bool upcoming;
  const _Numbers({required this.conclave, required this.upcoming});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final items = upcoming
        ? [
            (
              c.memberLimit > 0 ? '${c.registrationCount}/${c.memberLimit}' : '${c.registrationCount}',
              'Registered',
            ),
            ('${c.personsPerTable}', 'Per table'),
            ('${c.roundCount}', 'Rounds'),
          ]
        : [
            ('${c.registrationCount}', 'Members'),
            ('${c.roundCount}', 'Rounds'),
            ('${c.referralCount}', 'Referrals'),
          ];
    final divider = Container(
      width: 1,
      height: 36,
      color: context.scheme.outlineVariant.withValues(alpha: 0.6),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.lg, horizontal: Gap.sm),
      decoration: roundPanel(context, radius: 22),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) divider,
            Expanded(
              child: Column(children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    items[i].$1,
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  items[i].$2.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Where, the calendar, who organises it, and what it's about — one card.
class _Details extends StatelessWidget {
  final Conclave conclave;
  final bool upcoming;
  const _Details({required this.conclave, required this.upcoming});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final rows = <Widget>[
      _Row(
        icon: CoolIcons.mapPin,
        label: 'Venue',
        value: c.venueLocation,
        action: (
          'Directions',
          () => launchUrl(
                Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(c.venueLocation)}'),
                mode: LaunchMode.externalApplication,
              ),
        ),
      ),
      if (upcoming)
        _Row(
          icon: CoolIcons.calendarPlusCorner,
          label: 'Calendar',
          value: 'Get a reminder before it starts',
          action: ('Add to calendar', () => ConclaveCalendar.addToCalendar(c)),
        ),
      if (c.coordinator.isNotEmpty)
        _Row(icon: CoolIcons.user, label: 'Organised by', value: c.coordinator),
      if (c.region.isNotEmpty) _Row(icon: CoolIcons.map, label: 'Region', value: c.region),
      if (c.description.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Text(c.description, style: context.text.bodyMedium?.copyWith(height: 1.45)),
        ),
    ];
    return _Card(children: rows);
  }
}

/// A white card of label/value rows with hairline dividers.
class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      decoration: roundPanel(context),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: Gap.lg, endIndent: Gap.lg, color: context.colors.hairline),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// Optional link under the value (e.g. Directions), so a long value keeps
  /// the full width instead of being squeezed beside a button.
  final (String, VoidCallback)? action;
  const _Row({required this.icon, required this.label, required this.value, this.action});

  @override
  Widget build(BuildContext context) {
    final muted = context.scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: muted),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelSmall?.copyWith(color: muted)),
                Text(value, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (action != null)
                  InkWell(
                    onTap: action!.$2,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 2),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          action!.$1,
                          style: context.text.labelLarge?.copyWith(
                            color: AppColors.brandRed,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(CoolIcons.arrowUpRight, size: 14, color: AppColors.brandRed),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: Gap.xs, bottom: Gap.sm),
        child: Text(
          text.toUpperCase(),
          style: context.text.labelMedium?.copyWith(
            color: context.scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );
}

/// The three rules, as quiet rows in one card.
class _HowItWorks extends StatelessWidget {
  final Conclave conclave;
  const _HowItWorks({required this.conclave});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    return _Card(children: [
      _Rule(
        icon: CoolIcons.usersGroup,
        text: 'Up to ${c.personsPerTable} people at each table, kept even',
      ),
      _Rule(
        icon: CoolIcons.repeat,
        text: '${c.roundCount} rounds, and you meet a new table every round',
      ),
      const _Rule(
        icon: CoolIcons.shapes,
        text: 'Never two people from the same business category at one table',
      ),
    ]);
  }
}

class _Rule extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Rule({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.brandRed),
        const SizedBox(width: Gap.md),
        Expanded(child: Text(text, style: context.text.bodyMedium)),
      ]),
    );
  }
}

/// Role and table, as two rows in one card.
class _YourPlace extends StatelessWidget {
  final Conclave conclave;
  const _YourPlace({required this.conclave});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final captain = c.userRole == ConclaveRole.captain;
    return _Card(children: [
      _Row(
        icon: captain ? CoolIcons.crownFill : CoolIcons.user,
        label: 'Role',
        value: captain ? 'Captain, you anchor a table' : 'Member, you move each round',
      ),
      _Row(
        icon: CoolIcons.armchair,
        label: 'Round 1 table',
        value: c.userTableNumber != null
            ? 'Table ${c.userTableNumber}'
            : 'Shown once seating is ready',
      ),
    ]);
  }
}

class _Guests extends StatelessWidget {
  final List<String> names;
  const _Guests({required this.names});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      decoration: roundPanel(context),
      child: Column(
        children: [
          for (var i = 0; i < names.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: Gap.lg,
                endIndent: Gap.lg,
                color: context.colors.hairline,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
              child: Row(children: [
                const Icon(CoolIcons.starFill, size: 16, color: Color(0xFFE0A200)),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    names[i],
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

/// The pinned action area at the bottom of the page.
class _ActionBar extends StatelessWidget {
  final Widget child;
  const _ActionBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        Gap.md,
        context.pagePadding,
        Gap.md + context.bottomInset,
      ),
      child: ContentWidth(child: child),
    );
  }
}

class _Primary extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Primary({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: kDeckBottom,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800, fontSize: 16),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}
