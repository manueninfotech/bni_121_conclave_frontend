import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // Small pinned bar: just the way back. The name lives in the
              // header below, so nothing collapses or jumps on scroll.
              SliverAppBar(
                pinned: true,
                backgroundColor: tint,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: const Icon(CoolIcons.arrowLeft),
                  tooltip: 'Back',
                  onPressed: () => _back(context),
                ),
              ),
              SliverToBoxAdapter(child: _Header(conclave: c, tint: tint)),
              SliverToBoxAdapter(
                child: ContentWidth(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      Gap.lg,
                      context.pagePadding,
                      Gap.xl + (action == null ? context.bottomInset : 0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (c.isRegistered) ...[
                          const _Label('Your place'),
                          FadeSlideIn(index: 0, child: _YourPlace(conclave: c)),
                          const SizedBox(height: Gap.md),
                          FadeSlideIn(index: 1, child: SpecificAskCard(conclave: c)),
                          const SizedBox(height: Gap.xl),
                        ],
                        const _Label('How it works'),
                        FadeSlideIn(index: 2, child: _HowItWorks(conclave: c)),
                        if (c.chiefGuests.isNotEmpty) ...[
                          const SizedBox(height: Gap.xl),
                          const _Label('Chief guests'),
                          FadeSlideIn(index: 3, child: _Guests(names: c.chiefGuests)),
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

/// Tinted header: date tile, name, one status chip, when + where.
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
    final muted = context.scheme.onSurfaceVariant;
    final time = c.startTime == null
        ? null
        : c.endTime == null
            ? DateFormat('h:mm a').format(c.startTime!)
            : '${DateFormat('h:mm a').format(c.startTime!)} – ${DateFormat('h:mm a').format(c.endTime!)}';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint, context.scheme.surface],
        ),
      ),
      padding: EdgeInsets.fromLTRB(context.pagePadding, 0, context.pagePadding, Gap.sm),
      child: ContentWidth(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: Gap.sm),
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
                  const SizedBox(height: Gap.md),
                  _Meta(
                    icon: CoolIcons.calendar,
                    text: [
                      DateFormat('EEEE, d MMMM yyyy').format(c.date),
                      ?time,
                    ].join('  ·  '),
                    color: muted,
                  ),
                  _Meta(icon: CoolIcons.mapPin, text: c.venueLocation, color: muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Meta({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurface),
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
