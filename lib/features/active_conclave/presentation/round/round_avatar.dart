import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/active_conclave_models.dart';

/// The initial-letter fallback shown when a seat has no photo (or it fails to
/// load). Shared by every avatar in the live-round deck.
Widget roundInitialAvatarText(BuildContext context, TableSeat seat) {
  final scheme = context.scheme;
  return Text(
    seat.name.isEmpty ? '?' : seat.name[0].toUpperCase(),
    style: context.text.titleMedium?.copyWith(
      color: seat.isSelf ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    ),
  );
}
