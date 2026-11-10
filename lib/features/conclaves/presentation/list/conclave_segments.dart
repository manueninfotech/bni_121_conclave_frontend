import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// Ongoing · Upcoming · Past as one rounded pill switcher with counts — calmer
/// than an underlined tab bar, and the counts say where things are.
class ConclaveSegments extends StatelessWidget {
  final TabController controller;
  final List<({String label, int count})> segments;

  const ConclaveSegments({
    super.key,
    required this.controller,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedBuilder(
        animation: controller.animation!,
        builder: (context, _) {
          final pos = controller.animation!.value;
          return LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth / segments.length;
            return Stack(
              children: [
                // The sliding white thumb follows the swipe position.
                Positioned(
                  left: pos * w,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < segments.length; i++)
                      Expanded(
                        child: _Segment(
                          label: segments[i].label,
                          count: segments[i].count,
                          selected: (pos - i).abs() < 0.5,
                          onTap: () => controller.animateTo(i),
                        ),
                      ),
                  ],
                ),
              ],
            );
          });
        },
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = selected ? context.scheme.onSurface : context.scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: '$label, $count',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(
                    color: ink,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? context.scheme.onSurface
                        : context.scheme.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: context.text.labelSmall?.copyWith(
                      color: selected ? context.scheme.surface : ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
