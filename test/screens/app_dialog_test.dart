// Renders the app dialog for design review:
//   flutter test test/screens/app_dialog_test.dart --update-goldens
import 'dart:io';

import 'package:conclave_1_2_1/core/theme/app_theme.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';
import 'package:conclave_1_2_1/core/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  for (final destructive in [true, false]) {
    testWidgets('app dialog ${destructive ? 'destructive' : 'normal'}', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) => destructive
              ? showAppConfirm(context,
                  icon: CoolIcons.logOut,
                  title: 'Sign out?',
                  message: 'You will need to sign in again to take part in a conclave.',
                  confirmLabel: 'Sign out',
                  destructive: true)
              : showAppConfirm(context,
                  icon: CoolIcons.calendarCheck,
                  title: 'Add to your calendar?',
                  message: "You're registered, and we'll remind you an hour before.",
                  confirmLabel: 'Add to calendar',
                  cancelLabel: 'Not now'));
          return const Scaffold(body: SizedBox.expand());
        }),
      ));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/dialog_${destructive ? 'destructive' : 'normal'}.png'));
    });
  }
}
