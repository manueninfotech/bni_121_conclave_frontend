// Renders onboarding pages to PNGs for design review:
//   flutter test test/screens/onboarding_screen_test.dart --update-goldens
import 'dart:io';

import 'package:conclave_1_2_1/core/theme/app_theme.dart';
import 'package:conclave_1_2_1/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _font(String family, String path) async {
  final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await l.load();
}

void main() {
  setUpAll(() async {
    await _font('PlusJakartaSans', 'assets/fonts/PlusJakartaSans.ttf');
    await _font('Coolicons', 'assets/fonts/Coolicons.ttf');
  });

  testWidgets('onboarding pages', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const OnboardingScreen(),
      ),
    ));
    // Let asset images (the app mark) decode before capturing.
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(OnboardingScreen));
      await precacheImage(const AssetImage('assets/images/app_mark.png'), ctx);
      await precacheImage(const AssetImage('assets/images/app_mark_white.png'), ctx);
    });
    await tester.pump(const Duration(milliseconds: 1600));
    for (var i = 0; i < 5; i++) {
      await expectLater(find.byType(OnboardingScreen), matchesGoldenFile('goldens/onboarding_$i.png'));
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 1600));
    }
  });
}
