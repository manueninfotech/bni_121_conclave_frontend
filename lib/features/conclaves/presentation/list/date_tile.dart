import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';

/// A small calendar tile: month above, day number below.
class DateTile extends StatelessWidget {
  final DateTime date;
  final bool muted;
  const DateTile({super.key, required this.date, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final accent = muted ? scheme.onSurfaceVariant : AppColors.brandRed;
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: muted
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : AppColors.brandRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('MMM').format(date).toUpperCase(),
            style: context.text.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          Text(
            DateFormat('d').format(date),
            style: context.text.titleLarge?.copyWith(
              color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Sat, 15 Nov · 9:00 AM" — the one line of when.
String conclaveWhen(DateTime date, DateTime? start) {
  final d = DateFormat('EEE, d MMM').format(date);
  return start == null ? d : '$d  ·  ${DateFormat('h:mm a').format(start)}';
}
