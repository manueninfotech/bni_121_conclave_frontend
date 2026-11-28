import 'package:conclave_1_2_1/core/widgets/keyboard_dismiss.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dragging a list closes the keyboard', (t) async {
    await t.pumpWidget(
      MaterialApp(
        builder: (_, child) => KeyboardDismissOnTap(child: child!),
        home: Scaffold(
          body: ListView(
            children: [
              const TextField(key: Key('f')),
              for (var i = 0; i < 40; i++)
                SizedBox(height: 60, child: Text('row $i')),
            ],
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const Key('f')));
    await t.pump();
    expect(FocusManager.instance.primaryFocus?.hasPrimaryFocus, isTrue);
    expect(t.testTextInput.isVisible, isTrue);
    await t.drag(find.text('row 5'), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(t.testTextInput.isVisible, isFalse);
  });

  testWidgets('a bottom sheet list closes it too (country picker)', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        builder: (_, child) => KeyboardDismissOnTap(child: child!),
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold();
          },
        ),
      ),
    );
    showModalBottomSheet(
      context: ctx,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: 500,
        child: Column(
          children: [
            const TextField(key: Key('search')),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 50, child: Text('country $i')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('search')));
    await t.pump();
    expect(t.testTextInput.isVisible, isTrue);
    await t.drag(find.text('country 3'), const Offset(0, -200));
    await t.pumpAndSettle();
    expect(t.testTextInput.isVisible, isFalse);
  });

  testWidgets('scrolling inside a multi-line field keeps it open', (t) async {
    final c = TextEditingController(text: List.filled(40, 'line').join('\n'));
    await t.pumpWidget(
      MaterialApp(
        builder: (_, child) => KeyboardDismissOnTap(child: child!),
        home: Scaffold(
          body: TextField(key: const Key('note'), controller: c, maxLines: 4),
        ),
      ),
    );
    await t.tap(find.byKey(const Key('note')));
    await t.pump();
    await t.drag(find.byKey(const Key('note')), const Offset(0, -40));
    await t.pumpAndSettle();
    expect(t.testTextInput.isVisible, isTrue);
  });
}
