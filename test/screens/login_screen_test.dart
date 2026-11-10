// Renders the sign-in screen for design review:
//   flutter test test/screens/login_screen_test.dart --update-goldens
import 'dart:io';

import 'package:conclave_1_2_1/core/theme/app_theme.dart';
import 'package:conclave_1_2_1/features/auth/presentation/login_screen.dart';
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

  testWidgets('sign-in screen', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const LoginScreen(),
      ),
    ));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/images/app_mark.png'), tester.element(find.byType(LoginScreen)));
    });
    await tester.pump(const Duration(seconds: 2));
    await expectLater(find.byType(LoginScreen), matchesGoldenFile('goldens/login.png'));
  });
}
