import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One option of a [PillSwitch].
class PillOption<T> {
  final T value;
  final String label;
  final IconData icon;
  const PillOption(this.value, this.label, this.icon);
}

/// The app's pill switcher (as on Conclaves and sign-in): a soft track with a
/// white thumb under the chosen option. [value] may be null for "not chosen".
class PillSwitch<T> extends StatelessWidget {
  final List<PillOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  const PillSwitch({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: _Segment(
                label: o.label,
                icon: o.icon,
                selected: value == o.value,
                onTap: () => onChanged(o.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? context.scheme.onSurface
        : context.scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Curves.easeOut,
          height: 40,
          decoration: BoxDecoration(
            color: selected
                ? context.scheme.surfaceContainerLowest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.text.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
