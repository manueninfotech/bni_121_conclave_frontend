import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A member's avatar: their photo if they have one, otherwise their initials on
/// a tinted disc.
///
/// One widget so every place that shows a person — the profile header, the
/// directory, a table seat — renders them identically, and a broken or offline
/// photo URL always falls back to initials instead of a broken-image glyph.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;

  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 22,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final initials = Text(
      _initials,
      style: TextStyle(
        fontSize: radius * 0.72,
        fontWeight: FontWeight.w700,
        color: scheme.onPrimaryContainer,
      ),
    );

    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      // foregroundImage sits ON TOP of the initials child, so a slow or failed
      // load simply reveals the initials underneath — no flicker, no broken
      // glyph. onForegroundImageError is required or a failed load throws.
      foregroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      onForegroundImageError: hasPhoto ? (_, _) {} : null,
      child: initials,
    );
  }
}
