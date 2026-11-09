import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'round_timer.dart';

/// What the round is doing, as far as a backdrop cares.
enum CardMood { bio, referral, move, paused }

/// One phase's silk: colour, highlight tint and how it moves.
class _SilkLook {
  final Color color;
  final Color sheenColor;
  final double speed;
  final double sheen;
  final double depth;
  final double scale;

  const _SilkLook({
    required this.color,
    required this.sheenColor,
    required this.speed,
    required this.sheen,
    required this.depth,
    required this.scale,
  });

  static _SilkLook lerp(_SilkLook a, _SilkLook b, double t) => _SilkLook(
        color: Color.lerp(a.color, b.color, t)!,
        sheenColor: Color.lerp(a.sheenColor, b.sheenColor, t)!,
        speed: ui.lerpDouble(a.speed, b.speed, t)!,
        sheen: ui.lerpDouble(a.sheen, b.sheen, t)!,
        depth: ui.lerpDouble(a.depth, b.depth, t)!,
        scale: ui.lerpDouble(a.scale, b.scale, t)!,
      );
}

const _looks = <CardMood, _SilkLook>{
  // Deep brand-red silk, calm flow.
  CardMood.bio: _SilkLook(
    color: Color(0xFFD92A44),
    sheenColor: Color(0xFFFFFFFF),
    speed: 4,
    sheen: 0.5,
    depth: 0.45,
    scale: 1.0,
  ),
  // Warmer red with gold highlights running along the folds.
  CardMood.referral: _SilkLook(
    color: Color(0xFFD5352E),
    sheenColor: Color(0xFFFFD27A),
    speed: 5,
    sheen: 0.9,
    depth: 0.45,
    scale: 1.0,
  ),
  // Faster, bigger sweep — the room is on the move.
  CardMood.move: _SilkLook(
    color: Color(0xFFC81E3A),
    sheenColor: Color(0xFFFFFFFF),
    speed: 7,
    sheen: 0.6,
    depth: 0.5,
    scale: 1.25,
  ),
  // Frozen and desaturated.
  CardMood.paused: _SilkLook(
    color: Color(0xFFA0767C),
    sheenColor: Color(0xFFE6E6E6),
    speed: 0,
    sheen: 0.25,
    depth: 0.35,
    scale: 1.0,
  ),
};

/// The living background of a card / the move screen: flowing silk rendered by
/// a GPU fragment shader (`shaders/silk.frag`, ported from React Bits' Silk).
///
/// A phase change never snaps: the look (colour, sheen, speed, depth) blends
/// from where it is to the new phase over ~0.9s, so bio → referral → move →
/// paused feel like one continuous fabric. Only the paint layer repaints.
class CardBackdrop extends StatefulWidget {
  final CardMood mood;

  /// The focused card (the current speaker) gets a little more sheen.
  final bool intense;

  /// Picks a different fold arrangement, so neighbouring cards aren't identical.
  final double seed;

  const CardBackdrop({
    super.key,
    required this.mood,
    this.intense = false,
    this.seed = 0,
  });

  @override
  State<CardBackdrop> createState() => _CardBackdropState();
}

class _CardBackdropState extends State<CardBackdrop>
    with TickerProviderStateMixin {
  static Future<ui.FragmentProgram>? _program;

  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  Duration _last = Duration.zero;

  late _SilkLook _from = _looks[widget.mood]!;
  late _SilkLook _to = _from;
  late final AnimationController _blend = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );

  _SilkLook get _current =>
      _SilkLook.lerp(_from, _to, Curves.easeInOut.transform(_blend.value));

  @override
  void initState() {
    super.initState();
    _program ??= ui.FragmentProgram.fromAsset('shaders/silk.frag');
    _program!.then((p) {
      if (mounted) setState(() => _shader = p.fragmentShader());
    }).catchError((Object _) {
      // A GPU/driver that can't compile the shader keeps the plain gradient
      // fallback painted below — never a crash.
    });
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final speed = _current.speed;
    // Paused (speed 0) and settled: time stops, so nothing repaints.
    if (speed > 0) _time.value += dt * 0.1 * speed;
  }

  @override
  void didUpdateWidget(covariant CardBackdrop old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      _from = _current;
      _to = _looks[widget.mood]!;
      _blend.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _blend.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SilkPainter(
          shader: _shader,
          repaint: Listenable.merge([_time, _blend]),
          look: () => _current,
          time: _time,
          seed: widget.seed,
          intense: widget.intense,
        ),
      ),
    );
  }
}

class _SilkPainter extends CustomPainter {
  final ui.FragmentShader? shader;
  final _SilkLook Function() look;
  final ValueNotifier<double> time;
  final double seed;
  final bool intense;

  _SilkPainter({
    required this.shader,
    required Listenable repaint,
    required this.look,
    required this.time,
    required this.seed,
    required this.intense,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final l = look();
    final rect = Offset.zero & size;
    final s = shader;
    if (s == null) {
      // Shader still loading (first frame or two): plain gradient stand-in.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [l.color, kDeckBottom],
          ).createShader(rect),
      );
      return;
    }
    void rgb(int i, Color c) {
      s.setFloat(i, c.r);
      s.setFloat(i + 1, c.g);
      s.setFloat(i + 2, c.b);
    }

    s
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value);
    rgb(3, l.color);
    rgb(6, l.sheenColor);
    s
      ..setFloat(9, l.scale)
      ..setFloat(10, 0.35) // diagonal folds
      ..setFloat(11, 1.1) // grain
      ..setFloat(12, l.sheen + (intense ? 0.15 : 0))
      ..setFloat(13, l.depth)
      ..setFloat(14, 1.0) // sway
      ..setFloat(15, 0.6) // fine ripples
      ..setFloat(16, seed);
    canvas.drawRect(rect, Paint()..shader = s);
  }

  @override
  bool shouldRepaint(covariant _SilkPainter old) =>
      old.shader != shader || old.seed != seed || old.intense != intense;
}
