// iOS edge swipe-back must work on pushed pages, and the keyboard catcher at
// the app root must not swallow it (both broke it before).
import 'package:conclave_1_2_1/app.dart' show slidePage;
import 'package:conclave_1_2_1/core/theme/app_theme.dart';
import 'package:conclave_1_2_1/core/widgets/keyboard_dismiss.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('edge swipe pops a pushed page; tap outside closes keyboard', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final root = GlobalKey<NavigatorState>();
    final router = GoRouter(navigatorKey: root, initialLocation: '/profile', routes: [
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => Scaffold(body: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (c, s) => const Scaffold(body: Center(child: Text('PROFILE'))),
              routes: [
                GoRoute(
                  path: 'edit',
                  parentNavigatorKey: root,
                  pageBuilder: (c, s) => slidePage(
                    s,
                    const Scaffold(
                      body: Padding(
                        padding: EdgeInsets.only(top: 100),
                        child: Column(children: [Text('EDIT'), TextField()]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => KeyboardDismissOnTap(child: child!),
    ));
    await tester.pumpAndSettle();
    router.push('/profile/edit');
    await tester.pumpAndSettle();

    // Tap the field, then a blank spot: focus goes away.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    bool fieldFocused() => tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;
    expect(fieldFocused(), isTrue);
    await tester.tapAt(const Offset(200, 500));
    await tester.pump();
    expect(fieldFocused(), isFalse);

    // Swipe in from the left edge: back to the profile.
    final g = await tester.startGesture(const Offset(5, 400));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('EDIT'), findsNothing);
    expect(find.text('PROFILE'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
