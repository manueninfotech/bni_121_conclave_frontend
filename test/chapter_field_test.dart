import 'package:conclave_1_2_1/core/theme/app_theme.dart';
import 'package:conclave_1_2_1/core/widgets/chapter_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<TextEditingController> pump(
    WidgetTester t,
    List<String> chapters, [
    String initial = '',
  ]) async {
    final c = TextEditingController(text: initial);
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ChapterField(controller: c, chapters: chapters),
          ),
        ),
      ),
    );
    return c;
  }

  testWidgets('no list: a plain text field', (t) async {
    final c = await pump(t, const []);
    await t.enterText(find.byType(TextFormField), 'BNI Krishna');
    expect(c.text, 'BNI Krishna');
  });

  testWidgets('with a list: pick a chapter from the sheet', (t) async {
    final c = await pump(t, const ['BNI Amaravati', 'BNI Krishna']);
    await t.tap(find.text('Chapter (optional)'));
    await t.pumpAndSettle();
    expect(find.text('Your chapter'), findsOneWidget);
    await t.tap(find.text('BNI Krishna'));
    await t.pumpAndSettle();
    expect(c.text, 'BNI Krishna');
  });

  testWidgets('a chapter missing from the list can still be typed', (t) async {
    final c = await pump(t, const ['BNI Amaravati']);
    await t.tap(find.text('Chapter (optional)'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'BNI Tenali');
    await t.pumpAndSettle();
    await t.tap(find.text('Use "BNI Tenali"'));
    await t.pumpAndSettle();
    expect(c.text, 'BNI Tenali');
  });

  testWidgets('clear removes the chapter', (t) async {
    final c = await pump(t, const ['BNI Amaravati'], 'BNI Amaravati');
    await t.tap(find.byTooltip('Clear chapter'));
    await t.pump();
    expect(c.text, '');
  });
}
