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
import '../../active_conclave/presentation/round/deck_footer.dart' show roundPanel;
import '../../active_conclave/presentation/round/round_timer.dart' show kDeckBottom;
import '../data/conclave_repository.dart';
import '../domain/conclave_model.dart';
import 'list/date_tile.dart';
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
    final tint = Color.alphaBlend(
      AppColors.brandRed.withValues(alpha: 0.10),
      context.scheme.surface,
    );
    final action = _actionFor(context, c);
    final upcoming = c.effectiveStatus != ConclaveStatus.running &&
        c.effectiveStatus != ConclaveStatus.completed &&
        c.effectiveStatus != ConclaveStatus.cancelled;

    return Column(
      children: [
        _TopBar(tint: tint),
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _Header(conclave: c, tint: tint),
              ContentWidth(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding,
                    Gap.md,
                    context.pagePadding,
                    Gap.xl + (action == null ? context.bottomInset : 0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(index: 0, child: _WhenWhere(conclave: c, upcoming: upcoming)),
                      const SizedBox(height: Gap.md),
                      FadeSlideIn(index: 1, child: _Glance(conclave: c, upcoming: upcoming)),
                      if (c.isRegistered) ...[
                        const SizedBox(height: Gap.xl),
                        const _Label('Your place'),
                        FadeSlideIn(index: 2, child: _YourPlace(conclave: c)),
                        const SizedBox(height: Gap.md),
                        FadeSlideIn(index: 3, child: SpecificAskCard(conclave: c)),
                      ],
                      const SizedBox(height: Gap.xl),
                      const _Label('How it works'),
                      FadeSlideIn(index: 4, child: _HowItWorks(conclave: c)),
                      if (c.description.isNotEmpty || c.coordinator.isNotEmpty) ...[
                        const SizedBox(height: Gap.xl),
                        const _Label('About'),
                        FadeSlideIn(index: 5, child: _About(conclave: c)),
                      ],
                      if (c.chiefGuests.isNotEmpty) ...[
                        const SizedBox(height: Gap.xl),
                        const _Label('Chief guests'),
                        FadeSlideIn(index: 6, child: _Guests(names: c.chiefGuests)),
                      ],
                    ],
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
  /// do (the header's status already says ended / cancelled / closed).
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

/// Fixed top bar: a round back button aligned with the page's content edge.
class _TopBar extends StatelessWidget {
  final Color tint;
  const _TopBar({required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tint,
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        MediaQuery.paddingOf(context).top + Gap.xs,
        context.pagePadding,
        Gap.sm,
      ),
      child: ContentWidth(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: context.scheme.surfaceContainerLowest,
            shape: CircleBorder(side: BorderSide(color: context.colors.hairline)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _back(context),
              child: Semantics(
                button: true,
                label: 'Back',
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(CoolIcons.arrowLeft, size: 20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tinted header: date tile beside the name and one status line.
class _Header extends StatelessWidget {
  final Conclave conclave;
  final Color tint;
  const _Header({required this.conclave, required this.tint});

  (String, Color, IconData) _status(BuildContext context) {
    final c = conclave;
    final status = c.effectiveStatus;
    if (c.isRegistered &&
        status != ConclaveStatus.running &&
        status != ConclaveStatus.completed &&
        status != ConclaveStatus.cancelled) {
      return ("You're registered", context.colors.success, CoolIcons.circleCheckFill);
    }
    final muted = context.scheme.onSurfaceVariant;
    return switch (status) {
      ConclaveStatus.running => ('Live now', kDeckBottom, CoolIcons.broadcast),
      ConclaveStatus.completed => (
          c.isRegistered ? 'Attended' : 'Ended',
          c.isRegistered ? context.colors.success : muted,
          CoolIcons.check,
        ),
      ConclaveStatus.cancelled => ('Cancelled', context.colors.danger, CoolIcons.close),
      ConclaveStatus.registrationOpen => (
          'Registration open',
          context.scheme.onSurface,
          CoolIcons.userCheckCorner,
        ),
      ConclaveStatus.registrationNotOpen => ('Registration opens soon', muted, CoolIcons.clock),
      _ => ('Registration closed', muted, CoolIcons.lock),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final (label, color, icon) = _status(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint, context.scheme.surface],
        ),
      ),
      padding: EdgeInsets.fromLTRB(context.pagePadding, Gap.sm, context.pagePadding, Gap.md),
      child: ContentWidth(
        child: Row(
          children: [
            DateTile(date: c.date, muted: c.effectiveStatus == ConclaveStatus.completed),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: context.text.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// When and where, in one card, with the two things you'd do with them.
class _WhenWhere extends StatelessWidget {
  final Conclave conclave;
  final bool upcoming;
  const _WhenWhere({required this.conclave, required this.upcoming});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final time = c.startTime == null
        ? null
        : c.endTime == null
            ? DateFormat('h:mm a').format(c.startTime!)
            : '${DateFormat('h:mm a').format(c.startTime!)} – ${DateFormat('h:mm a').format(c.endTime!)}';
    final rows = <Widget>[
      _Row(icon: CoolIcons.calendar, label: 'Date', value: DateFormat('EEE, d MMM yyyy').format(c.date)),
      if (time != null) _Row(icon: CoolIcons.clock, label: 'Time', value: time),
      _Row(
        icon: CoolIcons.mapPin,
        label: 'Venue',
        value: c.venueLocation,
        action: ('Directions', () => launchUrl(
              Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(c.venueLocation)}'),
              mode: LaunchMode.externalApplication,
            )),
      ),
      if (upcoming)
        _Row(
          icon: CoolIcons.calendarPlusCorner,
          label: 'Calendar',
          value: 'Add a reminder',
          action: ('Add', () => ConclaveCalendar.addToCalendar(c)),
        ),
    ];
    return _Card(children: rows);
  }
}

/// The numbers that make a conclave real: who came, what came of it.
class _Glance extends StatelessWidget {
  final Conclave conclave;
  final bool upcoming;
  const _Glance({required this.conclave, required this.upcoming});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final spots = c.memberLimit > 0
        ? '${c.registrationCount} of ${c.memberLimit}'
        : '${c.registrationCount}';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Tile(
              icon: CoolIcons.users,
              value: upcoming ? spots : '${c.registrationCount}',
              caption: upcoming ? 'spots taken' : 'members',
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: upcoming
                ? _Tile(
                    icon: CoolIcons.usersGroup,
                    value: '${(c.registrationCount / c.personsPerTable.clamp(1, 8)).ceil()}',
                    caption: 'tables so far',
                  )
                : _Tile(
                    icon: CoolIcons.handshake,
                    value: '${c.referralCount}',
                    caption: 'referrals passed',
                  ),
          ),
        ],
      ),
    );
  }
}

class _About extends StatelessWidget {
  final Conclave conclave;
  const _About({required this.conclave});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: roundPanel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.description.isNotEmpty)
            Text(c.description, style: context.text.bodyMedium?.copyWith(height: 1.45)),
          if (c.description.isNotEmpty && c.coordinator.isNotEmpty)
            const SizedBox(height: Gap.md),
          if (c.coordinator.isNotEmpty)
            Row(children: [
              Icon(CoolIcons.user, size: 16, color: context.scheme.onSurfaceVariant),
              const SizedBox(width: Gap.sm),
              Text('Organised by ',
                  style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
              Flexible(
                child: Text(c.coordinator,
                    style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
        ],
      ),
    );
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
  final (String, VoidCallback)? action;
  const _Row({required this.icon, required this.label, required this.value, this.action});

  @override
  Widget build(BuildContext context) {
    final muted = context.scheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.fromLTRB(Gap.lg, Gap.md, action == null ? Gap.lg : Gap.sm, Gap.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelSmall?.copyWith(color: muted)),
                Text(value, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: action!.$2,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandRed,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(action!.$1),
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

/// A small square-ish tile: icon, value, caption.
class _Tile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String caption;
  const _Tile({required this.icon, required this.value, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: roundPanel(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.brandRed),
          const SizedBox(height: Gap.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            caption,
            maxLines: 2,
            style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  final Conclave conclave;
  const _HowItWorks({required this.conclave});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Tile(
              icon: CoolIcons.usersGroup,
              value: 'Up to ${c.personsPerTable}',
              caption: 'per table',
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: _Tile(
              icon: CoolIcons.repeat,
              value: '${c.roundCount} rounds',
              caption: 'new table each round',
            ),
          ),
          const SizedBox(width: Gap.sm),
          const Expanded(
            child: _Tile(
              icon: CoolIcons.shapes,
              value: 'Mixed',
              caption: 'one per business category',
            ),
          ),
        ],
      ),
    );
  }
}

class _YourPlace extends StatelessWidget {
  final Conclave conclave;
  const _YourPlace({required this.conclave});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final captain = c.userRole == ConclaveRole.captain;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Tile(
              icon: captain ? CoolIcons.crownFill : CoolIcons.user,
              value: captain ? 'Captain' : 'Member',
              caption: captain ? 'you anchor a table' : 'you move each round',
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: _Tile(
              icon: CoolIcons.armchair,
              value: c.userTableNumber != null ? 'Table ${c.userTableNumber}' : 'Table soon',
              caption: c.userTableNumber != null
                  ? 'for round 1'
                  : 'shown once seating is ready',
            ),
          ),
        ],
      ),
    );
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
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}
