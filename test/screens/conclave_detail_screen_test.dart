// Renders the conclave page to PNGs for design review (no device needed):
//   flutter test test/screens/conclave_detail_screen_test.dart --update-goldens
// Images land in test/screens/goldens/.
import 'dart:io';

import 'package:conclave_1_2_1/core/theme/app_theme.dart';
import 'package:conclave_1_2_1/features/conclaves/data/conclave_repository.dart';
import 'package:conclave_1_2_1/features/conclaves/domain/conclave_model.dart';
import 'package:conclave_1_2_1/features/conclaves/presentation/conclave_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}

Conclave _conclave(ConclaveStatus status, {bool registered = false}) => Conclave(
      id: 'c1',
      name: 'Guntur Business Conclave',
      venueLocation: 'Tanvika Convention, Amaravathi Road, Guntur',
      region: 'Guntur',
      coordinator: 'Ganesh Anumukonda',
      description: 'A morning of structured 1-2-1s across Guntur chapters.',
      date: DateTime(2026, 11, 20),
      startTime: DateTime(2026, 11, 20, 9),
      endTime: DateTime(2026, 11, 20, 12),
      status: status,
      isRegistrationOpen: status == ConclaveStatus.registrationOpen,
      personsPerTable: 5,
      roundCount: 4,
      currentRound: 2,
      registrationCount: 42,
      memberLimit: 60,
      referralCount: 17,
      isRegistered: registered,
      userRole: registered ? ConclaveRole.member : null,
      userTableNumber: registered ? 3 : null,
    );

void main() {
  setUpAll(() async {
    await _loadFont('PlusJakartaSans', 'assets/fonts/PlusJakartaSans.ttf');
    await _loadFont('Coolicons', 'assets/fonts/Coolicons.ttf');
  });

  for (final (name, status, registered) in [
    ('past', ConclaveStatus.completed, false),
    ('upcoming', ConclaveStatus.registrationOpen, false),
    ('registered', ConclaveStatus.registrationClosed, true),
    ('live', ConclaveStatus.running, true),
  ]) {
    testWidgets('conclave page: $name', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556); // iPhone 15/16 Pro
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          conclavesStreamProvider.overrideWith(
            (ref) => Stream.value([_conclave(status, registered: registered)]),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const ConclaveDetailScreen(conclaveId: 'c1'),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await expectLater(
        find.byType(ConclaveDetailScreen),
        matchesGoldenFile('goldens/conclave_detail_$name.png'),
      );
    });
  }
}
