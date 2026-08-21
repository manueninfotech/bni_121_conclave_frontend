import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';

/// The app's home shell: the three top-level destinations and a FLOATING
/// navigation bar that hovers above the content.
///
/// Built on go_router's [StatefulNavigationShell], so each tab keeps its own
/// navigation stack and scroll position. Detail pages (a conclave, a member,
/// edit profile) are pushed on the ROOT navigator instead, so they cover this
/// bar rather than sitting above it.
///
/// The bar is an OVERLAY, not a `bottomNavigationBar`: content scrolls behind
/// the frosted pill (each tab root reserves room for it via
/// `context.floatingNavClearance`), which is what gives it the floating,
/// iOS-Instagram feel rather than a hard docked bar.
class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  void _go(int index) {
    // initialLocation: true means tapping the CURRENT tab again pops it back to
    // its root — the behaviour every native app has.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          navigationShell,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: Gap.md),
              child: Center(
                child: _NavPill(
                  currentIndex: navigationShell.currentIndex,
                  onTap: _go,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavPill({required this.currentIndex, required this.onTap});

  static const _items = <({IconData icon, IconData selected, String label})>[
    (icon: Icons.home_outlined, selected: Icons.home_rounded, label: 'Home'),
    (icon: Icons.event_outlined, selected: Icons.event_rounded, label: 'Conclaves'),
    (icon: Icons.people_outline_rounded, selected: Icons.people_rounded, label: 'Members'),
    (icon: Icons.person_outline_rounded, selected: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            // Translucent so the blur reads as frosted glass.
            color: scheme.surface.withValues(alpha: isDark ? 0.72 : 0.82),
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavItem(
                  icon: _items[i].icon,
                  selectedIcon: _items[i].selected,
                  label: _items[i].label,
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One destination. The selected item expands into a tinted pill that reveals
/// its label; the rest stay as quiet icons.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: AnimatedContainer(
          duration: Motion.normal,
          curve: Motion.curve,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? Gap.md : Gap.md,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.crimson.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 24,
                color: selected ? AppColors.crimson : scheme.onSurfaceVariant,
              ),
              // The label only appears for the active tab — the expanding pill
              // is the whole point of the interaction.
              AnimatedSize(
                duration: Motion.normal,
                curve: Motion.curve,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: Gap.sm),
                        child: Text(
                          label,
                          style: context.text.labelLarge?.copyWith(
                            color: AppColors.crimson,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
