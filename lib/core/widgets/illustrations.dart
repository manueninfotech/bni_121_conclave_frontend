import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Vector illustrations, drawn rather than imported.
///
/// A greyed-out 48px Material icon is the single loudest "unfinished" signal an
/// app can send — it is the same glyph the OS uses for a settings row, blown up
/// and washed out. These are drawn from the app's own vocabulary (tables, seats,
/// rotation) so an empty state still says something about the product.
///
/// CustomPainter rather than SVG: no dependency, no asset loading, and they can
/// respond to the theme and animate.

/// Tables with occupied seats around them — the actual shape of a conclave.
class TablesIllustration extends StatelessWidget {
  final double size;
  final Color? color;

  const TablesIllustration({super.key, this.size = 140, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.72,
      child: CustomPaint(
        painter: _TablesPainter(
          accent: color ?? context.scheme.primary,
          muted: context.scheme.onSurfaceVariant.withValues(alpha: 0.35),
          hairline: context.colors.hairline,
        ),
      ),
    );
  }
}

class _TablesPainter extends CustomPainter {
  final Color accent;
  final Color muted;
  final Color hairline;

  _TablesPainter({
    required this.accent,
    required this.muted,
    required this.hairline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void table(Offset c, double r, int seats, {required bool active}) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = active ? accent.withValues(alpha: 0.55) : hairline;

      final fill = Paint()
        ..color = active ? accent.withValues(alpha: 0.08) : muted.withValues(alpha: 0.05);

      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, ring);

      // Seats sit ON the table's edge, evenly spaced — the same arrangement the
      // matcher is producing.
      for (var i = 0; i < seats; i++) {
        final angle = (i / seats) * 2 * math.pi - math.pi / 2;
        final p = Offset(
          c.dx + math.cos(angle) * (r + 7),
          c.dy + math.sin(angle) * (r + 7),
        );
        canvas.drawCircle(
          p,
          3.4,
          Paint()..color = active ? accent : muted,
        );
      }
    }

    table(Offset(w * 0.26, h * 0.36), w * 0.11, 5, active: false);
    table(Offset(w * 0.74, h * 0.34), w * 0.10, 4, active: false);
    // One table lit: the eye needs somewhere to land, and it hints that a
    // conclave is a set of tables of which one is *yours*.
    table(Offset(w * 0.5, h * 0.72), w * 0.13, 6, active: true);
  }

  @override
  bool shouldRepaint(_TablesPainter old) =>
      old.accent != accent || old.muted != muted || old.hairline != hairline;
}

/// A calendar sheet with a soft "nothing scheduled" mark.
class EmptyCalendarIllustration extends StatelessWidget {
  final double size;
  const EmptyCalendarIllustration({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.9,
      child: CustomPaint(
        painter: _CalendarPainter(
          accent: context.scheme.primary,
          muted: context.scheme.onSurfaceVariant.withValues(alpha: 0.3),
          hairline: context.colors.hairline,
          surface: context.scheme.surfaceContainerLow,
        ),
      ),
    );
  }
}

class _CalendarPainter extends CustomPainter {
  final Color accent;
  final Color muted;
  final Color hairline;
  final Color surface;

  _CalendarPainter({
    required this.accent,
    required this.muted,
    required this.hairline,
    required this.surface,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, h * 0.16, w * 0.8, h * 0.74),
      const Radius.circular(10),
    );

    canvas.drawRRect(body, Paint()..color = surface);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = hairline,
    );

    // Header band in the brand colour — the one spot of warmth.
    final header = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.1, h * 0.16, w * 0.8, h * 0.16),
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
    );
    canvas.drawRRect(header, Paint()..color = accent.withValues(alpha: 0.85));

    // Binding rings.
    for (final x in [w * 0.3, w * 0.7]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2.5, h * 0.06, 5, h * 0.16),
          const Radius.circular(3),
        ),
        Paint()..color = muted,
      );
    }

    // Grid dots, fading out — "nothing here yet" without spelling it.
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        final p = Offset(w * 0.22 + col * w * 0.19, h * 0.46 + row * h * 0.15);
        canvas.drawCircle(
          p,
          3,
          Paint()..color = muted.withValues(alpha: 0.55 - row * 0.15),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CalendarPainter old) => old.accent != accent;
}

/// A handshake ring — used where referrals are the subject.
class ReferralIllustration extends StatelessWidget {
  final double size;
  const ReferralIllustration({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.8,
      child: CustomPaint(
        painter: _ReferralPainter(
          accent: context.scheme.primary,
          success: context.colors.success,
          muted: context.scheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _ReferralPainter extends CustomPainter {
  final Color accent;
  final Color success;
  final Color muted;

  _ReferralPainter({
    required this.accent,
    required this.success,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h / 2);
    final r = math.min(w, h) * 0.34;

    // Two arcs chasing each other: the reciprocity the referral model is built
    // on, without resorting to a clip-art handshake.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi * 0.9,
      math.pi * 0.8,
      false,
      arc..color = accent.withValues(alpha: 0.9),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      math.pi * 0.1,
      math.pi * 0.8,
      false,
      arc..color = success.withValues(alpha: 0.9),
    );

    for (final o in [
      Offset(c.dx - r, c.dy),
      Offset(c.dx + r, c.dy),
    ]) {
      canvas.drawCircle(o, 5, Paint()..color = muted);
    }
  }

  @override
  bool shouldRepaint(_ReferralPainter old) => old.accent != accent;
}

/// Offline / can't-reach-the-server.
class OfflineIllustration extends StatelessWidget {
  final double size;
  const OfflineIllustration({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.8,
      child: CustomPaint(
        painter: _OfflinePainter(
          accent: context.colors.danger,
          muted: context.scheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _OfflinePainter extends CustomPainter {
  final Color accent;
  final Color muted;

  _OfflinePainter({required this.accent, required this.muted});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final origin = Offset(w / 2, h * 0.78);

    // Signal arcs, the outer ones faded — reach falling away.
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: w * (0.16 + i * 0.13)),
        -math.pi * 0.82,
        math.pi * 0.64,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = muted.withValues(alpha: 0.55 - i * 0.15),
      );
    }
    canvas.drawCircle(origin, 5, Paint()..color = muted);

    // The slash, in danger — unmistakable at a glance.
    canvas.drawLine(
      Offset(w * 0.24, h * 0.16),
      Offset(w * 0.76, h * 0.86),
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(_OfflinePainter old) => old.accent != accent;
}
