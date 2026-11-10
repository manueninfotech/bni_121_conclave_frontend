import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A living background of glass shards drifting along flowing ribbons, with
/// twinkling "+" survey markers — a lightweight, phone-friendly take on React
/// Bits' AeroShards (which needs WebGPU and per-pixel ray tracing).
///
/// Depth is faked with five layers: far shards are smaller, fainter and
/// softly blurred; near ones are crisp with a bright glass edge. A finger
/// pushes nearby shards aside. Honors "reduce motion" (renders still).
class AeroShards extends StatefulWidget {
  final Color shardColor;
  final Color accentColor;

  /// Share of shards drawn in [accentColor] (the rest are [shardColor]).
  final double accentShare;
  final Color backgroundColor;
  final int count;
  final double speed;
  final bool markers;
  final bool interactive;

  const AeroShards({
    super.key,
    // Architectural glass: graphite slivers, a few brand-red accents.
    this.shardColor = const Color(0xFF3A3F4A),
    this.accentColor = const Color(0xFFC8102E),
    this.accentShare = 0.12,
    this.backgroundColor = const Color(0xFFF8F6F5),
    this.count = 130,
    this.speed = 1,
    this.markers = true,
    this.interactive = true,
  });

  @override
  State<AeroShards> createState() => _AeroShardsState();
}

class _Shard {
  final int ribbon;
  final int depth; // 0 = far .. 4 = near
  double t; // 0..1 along the ribbon
  final double lateral; // offset across the ribbon (-1..1)
  final double size;
  double angle;
  final double spin;
  final List<Offset> poly; // unit polygon
  final double hue; // 0..1 shard -> accent
  _Shard({
    required this.ribbon,
    required this.depth,
    required this.t,
    required this.lateral,
    required this.size,
    required this.angle,
    required this.spin,
    required this.poly,
    required this.hue,
  });
}

class _AeroShardsState extends State<AeroShards> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  final _pointer = ValueNotifier<Offset?>(null);
  late List<_Shard> _shards;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _shards = _make(widget.count);
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      _time.value += dt * widget.speed;
    })
      ..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still && _ticker.isActive) _ticker.stop();
  }

  static List<_Shard> _make(int n) {
    final r = math.Random(121);
    return List.generate(n, (i) {
      // Elongated four-sided panes and slivers — architectural, not confetti.
      final long = 1.0 + r.nextDouble() * 1.4;
      final skew = (r.nextDouble() - 0.5) * 0.5;
      final poly = <Offset>[
        Offset(-long + skew, -0.42),
        Offset(long + skew, -0.42),
        Offset(long - skew, 0.42),
        Offset(-long - skew, 0.42),
      ];
      final depth = (math.pow(r.nextDouble(), 0.8) * 5).floor().clamp(0, 4);
      return _Shard(
        ribbon: r.nextInt(3),
        depth: depth,
        t: r.nextDouble(),
        lateral: (r.nextDouble() * 2 - 1),
        size: 4 + r.nextDouble() * 6,
        // Aligned with the flow (ribbons run left-to-right, slightly down).
        angle: 0.12 + (r.nextDouble() - 0.5) * 0.7,
        spin: (r.nextDouble() - 0.5) * 0.12,
        poly: poly,
        hue: r.nextDouble(), // < accentShare -> accent colour
      );
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paint = RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ShardsPainter(
          shards: _shards,
          accentShare: widget.accentShare,
          time: _time,
          pointer: _pointer,
          shard: widget.shardColor,
          accent: widget.accentColor,
          background: widget.backgroundColor,
          markers: widget.markers,
        ),
      ),
    );
    if (!widget.interactive) return paint;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _pointer.value = e.localPosition,
      onPointerMove: (e) => _pointer.value = e.localPosition,
      onPointerUp: (_) => _pointer.value = null,
      onPointerCancel: (_) => _pointer.value = null,
      child: paint,
    );
  }
}

class _ShardsPainter extends CustomPainter {
  final List<_Shard> shards;
  final double accentShare;
  final ValueNotifier<double> time;
  final ValueNotifier<Offset?> pointer;
  final Color shard;
  final Color accent;
  final Color background;
  final bool markers;

  _ShardsPainter({
    required this.shards,
    required this.accentShare,
    required this.time,
    required this.pointer,
    required this.shard,
    required this.accent,
    required this.background,
    required this.markers,
  }) : super(repaint: Listenable.merge([time, pointer]));

  // Per depth layer: scale, opacity, blur sigma, parallax speed.
  static const _scale = [0.45, 0.62, 0.8, 1.0, 1.3];
  static const _alpha = [0.06, 0.1, 0.15, 0.22, 0.3];
  static const _blur = [2.6, 1.6, 0.8, 0.0, 0.0];
  static const _pace = [0.35, 0.5, 0.7, 0.9, 1.15];

  /// A ribbon's centre line at x (0..1 across), drifting over time.
  Offset _ribbon(int i, double u, Size s, double t) {
    final base = [0.16, 0.34, 0.52][i];
    final amp = [0.06, 0.08, 0.06][i];
    final f = [1.3, 1.0, 1.6][i];
    final y = base +
        amp * math.sin(u * math.pi * 2 * f + t * 0.35 + i * 1.7) +
        0.03 * math.sin(u * math.pi * 7 + t * 0.9 + i);
    // Ribbons lean slightly diagonal.
    return Offset(u * (s.width + 80) - 40, (y + (u - 0.5) * 0.12) * s.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = time.value;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    if (markers) _paintMarkers(canvas, size, t);

    final p = pointer.value;
    final ordered = [...shards]..sort((a, b) => a.depth.compareTo(b.depth));
    final fill = Paint()..isAntiAlias = true;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (final s in ordered) {
      final u = (s.t + t * 0.018 * _pace[s.depth]) % 1.0;
      var c = _ribbon(s.ribbon, u, size, t);
      // Spread across the ribbon, wider for near layers; a slow billow.
      final spread = size.height * (0.012 + 0.007 * s.depth);
      c += Offset(0, s.lateral * spread + math.sin(t * 0.8 + s.t * 20) * 6);

      // Finger pushes shards aside.
      if (p != null) {
        final d = c - p;
        final dist = d.distance;
        const radius = 110.0;
        if (dist < radius && dist > 0.1) {
          c += d / dist * (radius - dist) * 0.55 * (0.4 + s.depth * 0.15);
        }
      }

      final k = s.size * _scale[s.depth];
      final a = s.angle + t * s.spin;
      final path = Path();
      for (var i = 0; i < s.poly.length; i++) {
        final v = s.poly[i];
        final rot = Offset(
          v.dx * math.cos(a) - v.dy * math.sin(a),
          v.dx * math.sin(a) + v.dy * math.cos(a),
        );
        final q = c + rot * k;
        i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
      }
      path.close();

      final alpha = _alpha[s.depth];
      final isAccent = s.hue < accentShare;
      final tint = isAccent ? accent : shard;
      // Glass: a light-to-tint gradient across the shard.
      fill
        ..maskFilter = _blur[s.depth] > 0 ? MaskFilter.blur(BlurStyle.normal, _blur[s.depth]) : null
        ..shader = ui.Gradient.linear(
          c - Offset(k, k),
          c + Offset(k, k),
          [
            Colors.white.withValues(alpha: alpha * 0.9),
            tint.withValues(alpha: alpha),
          ],
        );
      canvas.drawPath(path, fill);

      if (s.depth >= 3) {
        edge
          ..strokeWidth = s.depth == 4 ? 1.1 : 0.8
          ..color = Colors.white.withValues(alpha: 0.75);
        canvas.drawPath(path, edge);
      }
    }
  }

  void _paintMarkers(Canvas canvas, Size size, double t) {
    const spacing = 34.0;
    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;
    final bar = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final h = ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff;
        if (h % 3 != 0) continue; // sparse lattice
        final o = Offset(x * spacing + (h % 7) - 3, y * spacing + (h % 5) - 2);
        // Glow near a ribbon, plus a slow random twinkle.
        var near = 0.0;
        for (var r = 0; r < 3; r++) {
          final rp = _ribbon(r, (o.dx + 40) / (size.width + 80), size, t);
          final d = (rp.dy - o.dy).abs();
          near = math.max(near, (1 - d / (size.height * 0.07)).clamp(0.0, 1.0));
        }
        final twinkle = 0.5 + 0.5 * math.sin(t * 1.6 + (h % 1000) / 160);
        final a = (0.06 + near * 0.32 * twinkle).clamp(0.0, 0.45);
        if (a < 0.07) continue;
        bar.color = shard.withValues(alpha: a * 0.8);
        const r = 3.0;
        canvas.drawLine(o - const Offset(r, 0), o + const Offset(r, 0), bar);
        canvas.drawLine(o - const Offset(0, r), o + const Offset(0, r), bar);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShardsPainter old) =>
      old.shard != shard || old.accent != accent || old.background != background;
}
