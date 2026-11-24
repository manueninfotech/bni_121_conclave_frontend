import 'package:conclave_1_2_1/core/theme/app_theme.dart';
import 'package:conclave_1_2_1/features/conclaves/domain/conclave_image.dart';
import 'package:conclave_1_2_1/features/conclaves/domain/conclave_model.dart';
import 'package:conclave_1_2_1/features/conclaves/presentation/conclave_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the cover and flyers; skips broken entries', () {
    final c = Conclave.fromFirestore({
      'name': 'Guntur Mega 1-2-1',
      'date': '2026-12-12T04:30:00Z',
      'status': 'registrationOpen',
      'coverImage': {
        'id': 'c1',
        'url': '/api/files/conclave-covers/x/image.jpg',
        'name': 'Cover',
      },
      'flyers': [
        {
          'id': 'f1',
          'url': '/api/files/conclave-flyers/a/image.jpg',
          'name': 'Agenda',
        },
        {'id': 'bad'},
        null,
        {
          'id': 'f2',
          'url': '/api/files/conclave-flyers/b/image.png',
          'name': 'Venue map',
        },
      ],
    }, 'conc-1');
    expect(c.coverImage?.name, 'Cover');
    expect(c.flyers.map((f) => f.name), ['Agenda', 'Venue map']);
    expect(
      Conclave.fromFirestore({
        'name': 'x',
        'date': '2026-12-12T04:30:00Z',
        'status': 'draft',
      }, 'c').coverImage,
      isNull,
    );
  });

  testWidgets(
    'tapping a flyer opens the full-screen viewer; swipe moves through them',
    (t) async {
      const flyers = [
        ConclaveImage(id: 'f1', url: 'https://files.example/a.jpg', name: 'A'),
        ConclaveImage(id: 'f2', url: 'https://files.example/b.jpg', name: 'B'),
      ];
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: FlyerStrip(
              flyers: flyers,
              conclaveId: 'conc-123456',
              conclaveName: 'C',
            ),
          ),
        ),
      );
      await t.tap(find.bySemanticsLabel('Flyer 1 of 2'));
      await t.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);
      await t.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await t.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
      expect(find.text('2 of 2'), findsNothing);
    },
  );
}
