// Renders the create-account steps for design review:
//   flutter test test/screens/register_screen_test.dart --update-goldens
import 'dart:io';

import 'package:conclave_1_2_1/core/theme/app_theme.dart';
import 'package:conclave_1_2_1/core/widgets/category_picker.dart';
import 'package:conclave_1_2_1/features/auth/presentation/register_screen.dart';
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

  for (final (step, name) in [(0, 'credentials'), (1, 'otp'), (2, 'profile')]) {
    testWidgets('create account: $name', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: RegisterScreen(previewStep: step),
        ),
      ));
      await tester.pump(const Duration(seconds: 2));
      await expectLater(find.byType(RegisterScreen), matchesGoldenFile('goldens/register_$name.png'));
      if (step == 2) {
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -2000));
        await tester.pump(const Duration(seconds: 1));
        await expectLater(find.byType(RegisterScreen), matchesGoldenFile('goldens/register_profile_end.png'));
      }
    });
  }

  testWidgets('create account: category picker open', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const RegisterScreen(previewStep: 2),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Business category'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(CategoryPickerField));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Search categories'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/register_category_sheet.png'));
  });
}
