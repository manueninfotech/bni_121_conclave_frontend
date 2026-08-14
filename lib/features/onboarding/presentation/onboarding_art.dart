import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// The four onboarding illustrations.
///
/// Everything here is drawn with [CustomPainter], not shipped as images. The app
/// runs at venues with no usable signal, and a bundled PNG set would either bloat
/// the APK or (if fetched) fail to load exactly when the first-time user opens the
/// app on venue wifi. Vector art also stays crisp on every density and recolours
/// itself for the plum hero backdrop for free.
///
/// The palette is fixed rather than theme-derived: onboarding always renders on
/// the deep plum hero, so these read against it in both light and dark mode.
class _Ink {
  _Ink._();
  static Color glass(double a) => Colors.white.withValues(alpha: a);
  static const accent = Color(0xFFFF5A72); // crimson, lifted to sing on plum
  static const accentDeep = AppColors.crimson;
}

/// Runs a repeating 0→1 clock and hands it to a painter each frame.
///
/// One controller per illustration. They loop continuously but cheaply — a few
/// shapes — so the motion reads as "alive" without being a battery draw.
class LoopingArt extends StatefulWidget {
  final Duration duration;
  final CustomPainter Function(double t) build;

  const LoopingArt({super.key, required this.duration, required this.build});

  @override
  State<LoopingArt> createState() => _LoopingArtState();
}

class _LoopingArtState extends State<LoopingArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        painter: widget.build(_c.value),
        size: Size.infinite,
      ),
    );
  }
}

double _tri(double t) => 1 - (2 * t - 1).abs(); // 0→1→0

// ---------------------------------------------------------------------------
// 1. Your table, round by round.
// ---------------------------------------------------------------------------

class ScheduleArt extends StatelessWidget {
  const ScheduleArt({super.key});

  @override
  Widget build(BuildContext context) => LoopingArt(
        duration: const Duration(seconds: 6),
        build: (t) => _SchedulePainter(t),
      );
}

class _SchedulePainter extends CustomPainter {
  final double t;
  _SchedulePainter(this.t);

  static const _seats = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rx = size.width * 0.34;
    final ry = size.height * 0.30;

    // A slow orbit so the arrangement feels live rather than diagrammatic.
    final spin = t * 2 * math.pi;

    for (var i = 0; i < _seats; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / _seats + spin * 0.15;
      final p = Offset(
        center.dx + rx * math.cos(angle),
        center.dy + ry * math.sin(angle),
      );

      // Seats light up in sequence, then hold — the schedule "resolving".
      final local = ((t * _seats) - i).clamp(0.0, 1.0);
      final you = i == 0;

      // Spoke from the table to each seat.
      canvas.drawLine(
        center,
        p,
        Paint()
          ..color = _Ink.glass(0.12 + 0.10 * local)
          ..strokeWidth = 1.2,
      );

      final r = size.width * 0.05 * (0.6 + 0.4 * local);
      canvas.drawCircle(
        p,
        r,
        Paint()..color = you ? _Ink.accent : _Ink.glass(0.10 + 0.20 * local),
      );
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = you ? _Ink.accent : _Ink.glass(0.55),
      );
    }

    // The table itself.
    final table = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.30,
        height: size.height * 0.20,
      ),
      const Radius.circular(Radii.md),
    );
    canvas.drawRRect(table, Paint()..color = _Ink.glass(0.08));
    canvas.drawRRect(
      table,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _Ink.glass(0.6),
    );
    // A crimson marker on the table — "this is your round".
    canvas.drawCircle(
      Offset(center.dx, center.dy),
      size.width * 0.018,
      Paint()..color = _Ink.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _SchedulePainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// 2. Attendance, signal or not.
// ---------------------------------------------------------------------------

class ScanArt extends StatelessWidget {
  const ScanArt({super.key});

  @override
  Widget build(BuildContext context) => LoopingArt(
        duration: const Duration(milliseconds: 2600),
        build: (t) => _ScanPainter(t),
      );
}

class _ScanPainter extends CustomPainter {
  final double t;
  _ScanPainter(this.t);

  // A fixed, QR-ish pattern. Not a real code — just enough to read as one.
  static const _grid = 5;
  static const _cells = <int>[
    1, 1, 0, 1, 1, //
    1, 0, 1, 0, 1, //
    0, 1, 1, 1, 0, //
    1, 0, 1, 0, 1, //
    1, 1, 0, 1, 1, //
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * 0.56;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );
    final badge = RRect.fromRectAndRadius(rect, const Radius.circular(Radii.lg));

    canvas.drawRRect(badge, Paint()..color = _Ink.glass(0.06));

    // Cells.
    final pad = side * 0.16;
    final cell = (side - pad * 2) / _grid;
    final scanY = rect.top + pad + _tri(t) * (side - pad * 2);
    for (var r = 0; r < _grid; r++) {
      for (var c = 0; c < _grid; c++) {
        if (_cells[r * _grid + c] == 0) continue;
        final cr = Rect.fromLTWH(
          rect.left + pad + c * cell + cell * 0.12,
          rect.top + pad + r * cell + cell * 0.12,
          cell * 0.76,
          cell * 0.76,
        );
        // Cells glow as the scan line crosses them.
        final near = 1 - ((cr.center.dy - scanY).abs() / (cell * 1.6)).clamp(0.0, 1.0);
        final color = Color.lerp(_Ink.glass(0.55), _Ink.accent, near)!;
        canvas.drawRRect(
          RRect.fromRectAndRadius(cr, const Radius.circular(3)),
          Paint()..color = color,
        );
      }
    }

    // Corner brackets.
    final b = side * 0.16;
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _Ink.accent;
    void corner(Offset o, double sx, double sy) {
      canvas.drawLine(o, o.translate(b * sx, 0), bracket);
      canvas.drawLine(o, o.translate(0, b * sy), bracket);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);

    // The scan line, with a soft bloom.
    canvas.drawLine(
      Offset(rect.left + pad, scanY),
      Offset(rect.right - pad, scanY),
      Paint()
        ..color = _Ink.accent
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// 3. Referrals in one tap.
// ---------------------------------------------------------------------------

class ReferralArt extends StatelessWidget {
  const ReferralArt({super.key});

  @override
  Widget build(BuildContext context) => LoopingArt(
        duration: const Duration(seconds: 3),
        build: (t) => _ReferralPainter(t),
      );
}

class _ReferralPainter extends CustomPainter {
  final double t;
  _ReferralPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.52;
    final left = Offset(size.width * 0.24, y);
    final right = Offset(size.width * 0.76, y);
    final r = size.width * 0.09;

    // Two members.
    void avatar(Offset o, bool active) {
      canvas.drawCircle(o, r, Paint()..color = _Ink.glass(active ? 0.16 : 0.10));
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = active ? _Ink.accent : _Ink.glass(0.6),
      );
      // A simple head-and-shoulders glyph.
      canvas.drawCircle(o.translate(0, -r * 0.22), r * 0.32, Paint()..color = _Ink.glass(0.85));
      canvas.drawArc(
        Rect.fromCircle(center: o.translate(0, r * 0.62), radius: r * 0.5),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.28
          ..strokeCap = StrokeCap.round
          ..color = _Ink.glass(0.85),
      );
    }

    // Dotted path between them.
    final dots = 9;
    for (var i = 1; i < dots; i++) {
      final p = Offset.lerp(left, right, i / dots)!;
      canvas.drawCircle(p, 1.6, Paint()..color = _Ink.glass(0.25));
    }

    final arrived = _tri(t) > 0.98; // brief moment at the far end
    avatar(left, false);
    avatar(right, arrived);

    // The referral card travelling across, eased so it settles at each end.
    final e = Curves.easeInOut.transform(_tri(t));
    final pos = Offset.lerp(
      left.translate(r + 6, 0),
      right.translate(-r - 6, 0),
      e,
    )!;
    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos, width: size.width * 0.16, height: size.width * 0.11),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..color = _Ink.accent
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(card, Paint()..color = _Ink.accentDeep);
    // A tiny "line of text" on the card.
    canvas.drawLine(
      pos.translate(-size.width * 0.05, 0),
      pos.translate(size.width * 0.05, 0),
      Paint()
        ..color = _Ink.glass(0.9)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ReferralPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// 4. Your conclave summary.
// ---------------------------------------------------------------------------

class SummaryArt extends StatelessWidget {
  const SummaryArt({super.key});

  @override
  Widget build(BuildContext context) => LoopingArt(
        duration: const Duration(seconds: 4),
        build: (t) => _SummaryPainter(t),
      );
}

class _SummaryPainter extends CustomPainter {
  final double t;
  _SummaryPainter(this.t);

  static const _heights = <double>[0.45, 0.72, 0.55, 1.0, 0.68];

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height * 0.74;
    final chartW = size.width * 0.62;
    final left = (size.width - chartW) / 2;
    final barW = chartW / (_heights.length * 1.7);
    final gap = (chartW - barW * _heights.length) / (_heights.length - 1);
    final maxH = size.height * 0.42;

    // Baseline.
    canvas.drawLine(
      Offset(left - barW * 0.4, baseline),
      Offset(left + chartW + barW * 0.4 - barW, baseline),
      Paint()
        ..color = _Ink.glass(0.25)
        ..strokeWidth = 1.2,
    );

    for (var i = 0; i < _heights.length; i++) {
      // Grow in with a stagger, then breathe gently.
      final grow = ((t * 2) - i * 0.12).clamp(0.0, 1.0);
      final breathe = 0.92 + 0.08 * math.sin(t * 2 * math.pi + i);
      final h = maxH * _heights[i] * Curves.easeOut.transform(grow) * breathe;
      final x = left + i * (barW + gap);
      final tallest = i == 3;

      final bar = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, baseline - h, barW, h),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(
        bar,
        Paint()..color = tallest ? _Ink.accent : _Ink.glass(0.30),
      );
      if (tallest) {
        canvas.drawRRect(
          bar,
          Paint()
            ..color = _Ink.accent.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        canvas.drawRRect(bar, Paint()..color = _Ink.accent);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SummaryPainter old) => old.t != t;
}
