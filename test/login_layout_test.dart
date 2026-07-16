import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conclave_1_2_1/core/theme/app_theme.dart';
import 'package:conclave_1_2_1/core/theme/tokens.dart';
import 'package:conclave_1_2_1/core/widgets/responsive.dart';

/// Layout regressions, caught here rather than on a phone.
///
/// Two shipped bugs motivate this file:
///
///  - `ContentWidth` used a plain `Center`, which centres on BOTH axes, so any
///    screen that put it above a scroll view got its content floating in the
///    middle of a huge void.
///  - A `Spacer` inside a `SingleChildScrollView` threw "non-zero flex but
///    incoming height constraints are unbounded" and took the whole form down
///    with it — the screen rendered as a header over blank space.
///
/// Both are the kind of thing an analyzer cannot see and a screenshot catches
/// only after it has wasted someone's time.
void main() {
  /// Sizes the actual test surface.
  ///
  /// Wrapping in `MediaQuery(size:)` does NOT do this — the surface stays at its
  /// default 800x600 and every measurement is quietly taken against the wrong
  /// viewport, which is a great way to write a test that passes and proves
  /// nothing.
  void setSurface(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget host(Widget child) =>
      MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));

  group('ContentWidth', () {
    testWidgets('pins content to the top by default', (tester) async {
      setSurface(tester, const Size(400, 800));
      await tester.pumpWidget(host(
        const ContentWidth(
          max: 440,
          child: SizedBox(height: 100, child: Text('top')),
        ),
      ));

      final box = tester.getRect(find.text('top'));
      // Would sit near y=350 if it were centring vertically.
      expect(box.top, lessThan(50),
          reason: 'ContentWidth must not centre vertically by default');
    });

    testWidgets('centres vertically only when asked', (tester) async {
      setSurface(tester, const Size(400, 800));
      await tester.pumpWidget(host(
        const ContentWidth(
          max: 440,
          centerVertically: true,
          child: SizedBox(height: 100, child: Text('mid')),
        ),
      ));

      expect(tester.getRect(find.text('mid')).center.dy, closeTo(400, 60));
    });

    testWidgets('constrains width on a wide viewport', (tester) async {
      setSurface(tester, const Size(1200, 800));
      await tester.pumpWidget(host(
        const ContentWidth(
          max: 440,
          child: SizedBox(height: 40, child: Text('wide')),
        ),
      ));

      // Measure the CHILD, not the first ConstrainedBox in the tree — Scaffold
      // and friends contribute their own, and the first one is the viewport.
      final w = tester.getSize(find.text('wide')).width;
      expect(w, lessThanOrEqualTo(440),
          reason: 'content must not stretch across a wide screen');
    });
  });

  group('Spacer inside a scroll view', () {
    // The exact shape the login screen uses. Without IntrinsicHeight this throws.
    testWidgets('IntrinsicHeight bounds the height so Spacer works',
        (tester) async {
      setSurface(tester, const Size(400, 800));
      await tester.pumpWidget(host(
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Text('form'),
                    const Spacer(),
                    const Text('footer'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);

      // The Spacer must actually push the footer down, not collapse.
      final form = tester.getRect(find.text('form'));
      final footer = tester.getRect(find.text('footer'));
      expect(footer.top - form.bottom, greaterThan(400),
          reason: 'Spacer should fill the space between form and footer');
    });
  });

  group('Full-bleed panels', () {
    // Shipped twice: a hero panel inside a Column shrink-wrapped to its text and
    // left pale margins down both sides, which also stranded the light status-bar
    // icons on a light background. Column's default crossAxisAlignment is
    // `center`, so anything meant to be full-bleed must say `stretch`.
    testWidgets('a Column child fills the width only with stretch',
        (tester) async {
      setSurface(tester, const Size(400, 800));

      await tester.pumpWidget(host(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const Key('panel'),
              height: 120,
              color: Colors.black,
              child: const Text('hero'),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ));

      expect(tester.getSize(find.byKey(const Key('panel'))).width, 400,
          reason: 'a full-bleed panel must span the viewport');
    });

    testWidgets('without stretch it shrink-wraps — the bug', (tester) async {
      setSurface(tester, const Size(400, 800));

      await tester.pumpWidget(host(
        Column(
          children: [
            Container(
              key: const Key('panel'),
              height: 120,
              color: Colors.black,
              child: const Text('hero'),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ));

      // Pinned so the reason for `stretch` above is not mysterious later.
      expect(tester.getSize(find.byKey(const Key('panel'))).width, lessThan(400));
    });
  });

  group('PrimaryButton', () {
    // The theme deliberately does not force button width (a global
    // double.infinity minimumSize throws inside a Row), so a CTA that forgets to
    // say "full width" shrinks to intrinsic size and sits marooned mid-screen.
    testWidgets('fills its parent width', (tester) async {
      setSurface(tester, const Size(400, 800));
      await tester.pumpWidget(host(
        const Padding(
          padding: EdgeInsets.all(Gap.xl),
          child: PrimaryButton(label: 'Sign in'),
        ),
      ));

      final w = tester.getSize(find.byType(PrimaryButton)).width;
      expect(w, closeTo(400 - Gap.xl * 2, 1));
    });

    testWidgets('shows a spinner and blocks taps while loading', (tester) async {
      setSurface(tester, const Size(400, 800));
      var taps = 0;
      await tester.pumpWidget(host(
        PrimaryButton(label: 'Sign in', loading: true, onPressed: () => taps++),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      expect(taps, 0, reason: 'a loading button must not fire again');
    });
  });

  group('AdaptiveRow', () {
    testWidgets('stays a row at the default text size', (tester) async {
      setSurface(tester, const Size(400, 800));
      await tester.pumpWidget(host(
        const AdaptiveRow(children: [Text('a'), Text('b')]),
      ));

      expect(tester.getRect(find.text('a')).top,
          closeTo(tester.getRect(find.text('b')).top, 1));
    });

    testWidgets('stacks when the user scales text up', (tester) async {
      setSurface(tester, const Size(400, 800));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: AdaptiveRow(children: [Text('a'), Text('b')]),
            ),
          ),
        ),
      );

      // Stacked: 'b' sits below 'a' rather than beside it. This is what stops
      // the yellow-and-black overflow stripes at large font sizes.
      expect(tester.getRect(find.text('b')).top,
          greaterThan(tester.getRect(find.text('a')).bottom - 1));
    });
  });
}
