import 'package:flutter/material.dart';

import '../../../core/theme/cool_icons.dart';

/// Small, real-looking slices of the app for the onboarding stage — each one
/// says what the feature does by showing it, not with an abstract drawing.
/// White surfaces on the silk stage, so they read like the app itself.

const _ink = Color(0xFF1B1B1F);
const _muted = Color(0xFF6B6770);
const _red = Color(0xFFB00E29);

BoxDecoration _plate([double r = 20]) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );

TextStyle _t(double size, FontWeight w, [Color c = _ink]) =>
    TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, height: 1.2);

class _Face extends StatelessWidget {
  final String initial;
  final Color tone;
  final double size;
  const _Face(this.initial, this.tone, {this.size = 34});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tone,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(initial, style: _t(size * 0.4, FontWeight.w800, Colors.white)),
      );
}

const _tones = [
  Color(0xFF3B5BDB),
  Color(0xFF0C8599),
  Color(0xFFE67700),
  Color(0xFF7048E8),
  Color(0xFF2B8A3E),
];

/// Page 0: the brand.
class WelcomeVisual extends StatelessWidget {
  const WelcomeVisual({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/app_mark_white.png',
        width: 170,
        semanticLabel: '1-2-1 Connect',
      );
}

/// Page 1: where you sit and who with.
class SeatVisual extends StatelessWidget {
  const SeatVisual({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: _plate(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ROUND 2 OF 5', style: _t(10, FontWeight.w800, _muted).copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text('Table 4', style: _t(26, FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: Stack(children: [
              for (var i = 0; i < 5; i++)
                Positioned(
                  left: i * 24.0,
                  child: _Face('ARSKP'[i], _tones[i]),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(CoolIcons.route, size: 14, color: _red),
              const SizedBox(width: 6),
              Text('Next: Table 7', style: _t(12, FontWeight.w800, _red)),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Page 2: captains scan you in, with or without signal.
class ScanVisual extends StatelessWidget {
  const ScanVisual({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _plate(24),
          child: SizedBox(
            width: 130,
            height: 130,
            child: CustomPaint(painter: _QrPainter()),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: _plate(999),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(CoolIcons.circleCheckFill, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 6),
            Text('Scanned  ·  4 of 5 here', style: _t(12, FontWeight.w800)),
          ]),
        ),
      ],
    );
  }
}

class _QrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _ink;
    final cell = size.width / 21;
    void finder(double x, double y) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, cell * 7, cell * 7), Radius.circular(cell * 1.6)), p);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x + cell, y + cell, cell * 5, cell * 5), Radius.circular(cell * 1.2)),
          Paint()..color = Colors.white);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x + cell * 2, y + cell * 2, cell * 3, cell * 3), Radius.circular(cell * 0.8)),
          p);
    }

    finder(0, 0);
    finder(cell * 14, 0);
    finder(0, cell * 14);
    // A fixed, pleasant pseudo-random module pattern.
    var seed = 7;
    for (var y = 0; y < 21; y++) {
      for (var x = 0; x < 21; x++) {
        final inFinder = (x < 8 && y < 8) || (x > 12 && y < 8) || (x < 8 && y > 12);
        if (inFinder) continue;
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        if (seed % 100 < 46) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x * cell + 0.6, y * cell + 0.6, cell - 1.2, cell - 1.2), Radius.circular(cell * 0.3)),
            p,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Page 3: a referral, passed across the table.
class ReferralVisual extends StatelessWidget {
  const ReferralVisual({super.key});

  @override
  Widget build(BuildContext context) {
    Widget person(String i, Color c, String name, String what) => Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: _plate(18),
          child: Row(children: [
            _Face(i, c, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: _t(13, FontWeight.w800)),
                Text(what, style: _t(11, FontWeight.w500, _muted)),
              ]),
            ),
          ]),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(offset: const Offset(-26, 0), child: person('A', _tones[0], 'Asha', 'Interior design')),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(CoolIcons.handshakeFill, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text('Referral passed', style: _t(12, FontWeight.w800, Colors.white)),
          ]),
        ),
        const SizedBox(height: 10),
        Transform.translate(offset: const Offset(26, 0), child: person('R', _tones[2], 'Ravi', 'Builder, Guntur')),
      ],
    );
  }
}

/// Page 4: what the day added up to.
class SummaryVisual extends StatelessWidget {
  const SummaryVisual({super.key});

  @override
  Widget build(BuildContext context) {
    Widget n(String v, String l) => Expanded(
          child: Column(children: [
            Text(v, style: _t(24, FontWeight.w800)),
            Text(l, style: _t(9, FontWeight.w800, _muted).copyWith(letterSpacing: 1)),
          ]),
        );
    final divider = Container(width: 1, height: 30, color: const Color(0xFFE6E1E3));
    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: _plate(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [n('13', 'GIVEN'), divider, n('5', 'RECEIVED'), divider, n('3', 'MUTUAL')]),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFFEFEAEC)),
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(
              width: 34 + 3 * 20,
              height: 30,
              child: Stack(children: [
                for (var i = 0; i < 4; i++) Positioned(left: i * 20.0, child: _Face('SKNM'[i], _tones[i + 1], size: 30)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('18 people met', style: _t(12, FontWeight.w800))),
          ]),
        ],
      ),
    );
  }
}
