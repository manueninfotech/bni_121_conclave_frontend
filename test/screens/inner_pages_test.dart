// Renders the inner (pushed) pages with sample data for design review:
//   flutter test test/screens/inner_pages_test.dart --update-goldens
import 'dart:io';

import 'package:conclave_1_2_1/core/theme/app_theme.dart';
import 'package:conclave_1_2_1/features/auth/data/auth_repository.dart';
import 'package:conclave_1_2_1/features/conclaves/data/conclave_repository.dart';
import 'package:conclave_1_2_1/features/conclaves/domain/conclave_model.dart';
import 'package:conclave_1_2_1/features/conclaves/presentation/conclave_register_screen.dart';
import 'package:conclave_1_2_1/features/members/data/members_repository.dart';
import 'package:conclave_1_2_1/features/members/data/my_referrals_repository.dart';
import 'package:conclave_1_2_1/features/members/data/one_to_ones_repository.dart';
import 'package:conclave_1_2_1/features/members/data/people_met_repository.dart';
import 'package:conclave_1_2_1/features/members/presentation/member_detail_screen.dart';
import 'package:conclave_1_2_1/features/members/presentation/my_card_screen.dart';
import 'package:conclave_1_2_1/features/members/presentation/my_referrals_screen.dart';
import 'package:conclave_1_2_1/features/members/presentation/one_to_ones_screen.dart';
import 'package:conclave_1_2_1/features/members/presentation/people_met_screen.dart';
import 'package:conclave_1_2_1/features/notifications/data/notifications_repository.dart';
import 'package:conclave_1_2_1/features/notifications/presentation/notifications_screen.dart';
import 'package:conclave_1_2_1/features/profile/data/profile_repository.dart';
import 'package:conclave_1_2_1/features/profile/presentation/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _font(String family, String path) async {
  final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await l.load();
}

class _FakeNotifications implements NotificationsRepository {
  @override
  Future<void> markAllRead() async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _now = DateTime.now();

const _profile = UserProfile(
  uid: 'me',
  name: 'Bhanu Prakash',
  photoUrl: null,
  identifier: '',
  email: 'bhanu@example.com',
  phone: '+919876543210',
  businessName: 'Manuen Studio',
  businessCategory: 'Advertising',
  location: 'Guntur',
  chapter: 'Amaravati',
  region: 'Guntur Region',
  membership: 'BNI',
  lookingFor: 'Introductions to restaurant owners',
  canOffer: 'Brand identity and app design',
  country: 'IN',
);

const _member = Member(
  uid: 'm1',
  name: 'Ravi Teja',
  photoUrl: null,
  businessName: 'Teja Interiors',
  businessCategory: 'Interior Design',
  location: 'vijayawada',
  chapter: 'Krishna',
  region: 'Vijayawada Region',
  membership: 'BNI',
  lookingFor: 'Builders starting new residential projects',
  canOffer: 'Commercial interior fit-outs, turnkey offices',
);

final _conclave = Conclave(
  id: 'c1',
  name: 'Guntur Mega Conclave 2026',
  venueLocation: 'Sri Convention Hall, Guntur',
  date: _now.add(const Duration(days: 9)),
  startTime: DateTime(2026, 11, 20, 9, 30),
  status: ConclaveStatus.scheduled,
  isRegistrationOpen: true,
);

final _overrides = [
  authStateProvider.overrideWith((ref) => Stream.value(null)),
  myProfileProvider.overrideWith((ref) => Stream.value(_profile)),
  conclavesStreamProvider.overrideWith((ref) => Stream.value([_conclave])),
  membersProvider.overrideWith((ref) async => [_member]),
  notificationsRepositoryProvider.overrideWithValue(_FakeNotifications()),
  notificationsProvider.overrideWith((ref) async => NotificationsData(items: [
        AppNotification(
          id: '1',
          title: 'New referral from Ravi',
          body: 'A client needs an office fit-out in Brodipet.',
          type: 'referral_received',
          data: const {},
          read: false,
          createdAt: _now.subtract(const Duration(minutes: 12)),
        ),
        AppNotification(
          id: '2',
          title: '1-2-1 request',
          body: 'Sita Ram wants to meet on Friday at 11 AM.',
          type: 'one_to_one_request',
          data: const {},
          read: false,
          createdAt: _now.subtract(const Duration(hours: 3)),
        ),
        AppNotification(
          id: '3',
          title: 'Round 3 starts now',
          body: 'Go to Table 4.',
          type: 'round',
          data: const {},
          read: true,
          createdAt: _now.subtract(const Duration(days: 2)),
        ),
      ], unreadCount: 2)),
  myOneToOnesProvider.overrideWith((ref) async => [
        OneToOne(
          id: 'a',
          sent: false,
          otherUserId: 'x',
          otherName: 'Sita Ram',
          otherBusinessName: 'Ram Caterers',
          otherPhotoUrl: null,
          proposedAt: _now.add(const Duration(days: 2)),
          location: 'Coffee Day, Lakshmipuram',
          note: 'Would love to hear about your event clients.',
          status: OneToOneStatus.pending,
        ),
        OneToOne(
          id: 'b',
          sent: true,
          otherUserId: 'm1',
          otherName: 'Ravi Teja',
          otherBusinessName: 'Teja Interiors',
          otherPhotoUrl: null,
          proposedAt: _now.add(const Duration(days: 4)),
          location: 'His office',
          note: '',
          status: OneToOneStatus.accepted,
        ),
      ]),
  myReferralsProvider.overrideWith((ref) async => MyReferrals(given: [
        ReferralEntry(
          id: 'r1',
          conclaveId: 'c1',
          conclaveName: 'Guntur Mega Conclave',
          roundNumber: 2,
          otherName: 'Ravi Teja',
          otherBusinessName: 'Teja Interiors',
          notes: 'Office fit-out, 3,000 sq ft, call before 6 PM.',
          outcome: ReferralOutcome.closed,
          closedAmount: 240000,
          outcomeNote: '',
          createdAt: _now.subtract(const Duration(days: 10)),
        ),
        ReferralEntry(
          id: 'r2',
          conclaveId: 'c1',
          conclaveName: 'Guntur Mega Conclave',
          roundNumber: 4,
          otherName: 'Sita Ram',
          otherBusinessName: 'Ram Caterers',
          notes: '',
          outcome: ReferralOutcome.open,
          closedAmount: 0,
          outcomeNote: '',
          createdAt: _now.subtract(const Duration(days: 10)),
        ),
      ], received: const [])),
  peopleMetProvider('c1').overrideWith((ref) async => const [
        MetPerson(uid: 'm1', name: 'Ravi Teja', businessName: 'Teja Interiors', businessCategory: 'Interior Design', phone: '', rounds: [1, 4]),
        MetPerson(uid: 'x', name: 'Sita Ram', businessName: 'Ram Caterers', businessCategory: 'Catering', phone: '', rounds: [2]),
        MetPerson(uid: 'y', name: 'Kiran Kumar', businessName: 'KK Realty', businessCategory: 'Real Estate', phone: '', rounds: [3, 5]),
      ]),
];

void main() {
  setUpAll(() async {
    await _font('PlusJakartaSans', 'assets/fonts/PlusJakartaSans.ttf');
    await _font('Coolicons', 'assets/fonts/Coolicons.ttf');
  });

  final pages = <String, Widget>{
    'edit_profile': const EditProfileScreen(),
    'confirm_registration': const ConclaveRegisterScreen(conclaveId: 'c1'),
    'notifications': const NotificationsScreen(),
    'my_card': const MyCardScreen(),
    'people_met': const PeopleMetScreen(conclaveId: 'c1'),
    'member_detail': const MemberDetailScreen(memberId: 'm1'),
    'one_to_ones': const OneToOnesScreen(),
    'my_referrals': const MyReferralsScreen(),
  };

  for (final MapEntry(key: name, value: page) in pages.entries) {
    testWidgets('inner page: $name', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: page,
        ),
      ));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await expectLater(find.byWidget(page), matchesGoldenFile('goldens/inner_$name.png'));
    });
  }
}
