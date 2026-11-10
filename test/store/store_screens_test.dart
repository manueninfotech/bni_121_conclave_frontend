// Renders the real app screens with fictional demo data for the App Store and
// Play Store listings. Raw screens land in store/raw/; tool/store/frame.py then
// adds the headline + device frame for each store size.
//   flutter test test/store/store_screens_test.dart --update-goldens
import 'dart:io';

import 'package:conclave_1_2_1/core/theme/app_theme.dart';
import 'package:conclave_1_2_1/core/widgets/scaffold_with_nav.dart';
import 'package:conclave_1_2_1/features/active_conclave/data/conclave_summary_repository.dart';
import 'package:conclave_1_2_1/features/active_conclave/data/sync_service.dart';
import 'package:conclave_1_2_1/features/active_conclave/domain/active_conclave_models.dart';
import 'package:conclave_1_2_1/features/active_conclave/domain/referral_models.dart';
import 'package:conclave_1_2_1/features/active_conclave/presentation/conclave_summary_screen.dart';
import 'package:conclave_1_2_1/features/active_conclave/presentation/round/round_deck_view.dart';
import 'package:conclave_1_2_1/features/active_conclave/presentation/summary/summary_journey.dart';
import 'package:conclave_1_2_1/features/auth/data/auth_repository.dart';
import 'package:conclave_1_2_1/features/conclaves/data/conclave_repository.dart';
import 'package:conclave_1_2_1/features/conclaves/domain/conclave_model.dart';
import 'package:conclave_1_2_1/features/conclaves/presentation/conclave_detail_screen.dart';
import 'package:conclave_1_2_1/features/conclaves/presentation/conclaves_list_screen.dart';
import 'package:conclave_1_2_1/features/home/presentation/home_screen.dart';
import 'package:conclave_1_2_1/features/members/data/my_referrals_repository.dart';
import 'package:conclave_1_2_1/features/members/data/one_to_ones_repository.dart';
import 'package:conclave_1_2_1/features/members/data/people_met_repository.dart';
import 'package:conclave_1_2_1/features/members/presentation/my_card_screen.dart';
import 'package:conclave_1_2_1/features/members/presentation/people_met_screen.dart';
import 'package:conclave_1_2_1/features/notifications/data/notifications_repository.dart';
import 'package:conclave_1_2_1/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _font(String family, String path) async {
  final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await l.load();
}

class _FakeSync implements SyncService {
  @override
  Future<void> syncNow(String conclaveId) async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _now = DateTime.now();
DateTime _day(int d, [int h = 9, int m = 0]) {
  final t = _now.add(Duration(days: d));
  return DateTime(t.year, t.month, t.day, h, m);
}

const _me = UserProfile(
  uid: 'me',
  name: 'Arjun Reddy',
  photoUrl: null,
  identifier: '',
  email: 'arjun@reddyarchitects.in',
  phone: '+919800000001',
  businessName: 'Reddy Architects',
  businessCategory: 'Architecture',
  location: 'Guntur',
  chapter: 'Amaravati',
  region: 'Guntur Region',
  membership: 'BNI',
  lookingFor: 'Builders starting new residential projects',
  canOffer: 'Residential and commercial design',
  country: 'IN',
);

Conclave _c(String id, String name, String venue, DateTime date, ConclaveStatus status,
        {bool registered = false, int round = 0, int regs = 48, int refs = 0}) =>
    Conclave(
      id: id,
      name: name,
      venueLocation: venue,
      region: 'Guntur',
      coordinator: 'Conclave team',
      description: 'A morning of structured 1-2-1s across chapters.',
      date: date,
      startTime: DateTime(date.year, date.month, date.day, 9),
      endTime: DateTime(date.year, date.month, date.day, 12, 30),
      status: status,
      isRegistrationOpen: status == ConclaveStatus.registrationOpen,
      personsPerTable: 6,
      roundCount: 6,
      currentRound: round,
      registrationCount: regs,
      memberLimit: 72,
      referralCount: refs,
      isRegistered: registered,
      userRole: registered ? ConclaveRole.member : null,
      userTableNumber: registered ? 4 : null,
    );

final _upcoming = [
  _c('up1', 'Vijayawada Growth Conclave', 'Murali Fortune, Vijayawada', _day(5), ConclaveStatus.registrationOpen,
      registered: true, regs: 58),
  _c('up2', 'Amaravati Leaders Meet', 'CK Convention, Mangalagiri', _day(12), ConclaveStatus.registrationOpen, regs: 38),
  _c('up3', 'Ongole Business Connect', 'Sai Grand, Ongole', _day(19), ConclaveStatus.registrationOpen, regs: 24),
  _c('up4', 'Nellore Networking Day', 'VPR Convention, Nellore', _day(26), ConclaveStatus.registrationOpen, regs: 12),
  _c('past', 'Tenali Connect 2026', 'Sri Sai Function Hall, Tenali', _day(-30), ConclaveStatus.completed,
      registered: true, round: 6, regs: 54, refs: 37),
];

final _conclaves = [
  _c('live', 'Guntur Business Conclave', 'Tanvika Convention, Guntur', _day(0), ConclaveStatus.running,
      registered: true, round: 3, regs: 66, refs: 41),
  _c('up1', 'Vijayawada Growth Conclave', 'Murali Fortune, Vijayawada', _day(12), ConclaveStatus.registrationOpen, regs: 38),
  _c('up2', 'Amaravati Leaders Meet', 'CK Convention, Mangalagiri', _day(26), ConclaveStatus.registrationOpen, regs: 21),
  _c('past', 'Tenali Connect 2026', 'Sri Sai Function Hall, Tenali', _day(-30), ConclaveStatus.completed,
      registered: true, round: 6, regs: 54, refs: 37),
];

TableSeat _seat(int id, String name, String biz, String cat, {bool self = false, bool captain = false, String? ask}) =>
    TableSeat(
      userId: 'u$id',
      participantId: id,
      name: name,
      businessName: biz,
      category: cat,
      isCaptain: captain,
      isSelf: self,
      ask: ask,
    );

final _seats = [
  _seat(1, 'Arjun Reddy', 'Reddy Architects', 'Architecture', self: true),
  _seat(2, 'Priya Sharma', 'Sharma Chartered Accountants', 'Chartered Accountant',
      ask: 'Introductions to restaurant owners opening a second outlet'),
  _seat(3, 'Kiran Kumar', 'KK Realty', 'Real Estate', ask: 'Families looking for 3BHK homes near Brodipet'),
  _seat(4, 'Lakshmi Devi', 'Devi Caterers', 'Catering', ask: 'Corporate offices planning annual day events'),
  _seat(5, 'Rahul Varma', 'Varma Insurance', 'Insurance', ask: 'Business owners with 20+ staff'),
  _seat(6, 'Sneha Rao', 'Rao Digital', 'Digital Marketing', captain: true, ask: 'Clinics that want more patient bookings'),
];

ActiveRound _round(Duration elapsed) => ActiveRound(
      conclaveId: 'live',
      roundNumber: 3,
      totalRounds: 6,
      tableNumber: 4,
      nextTableNumber: 7,
      startTime: _now.subtract(elapsed),
      timing: RoundTiming.forRound(personsPerTable: 6),
      seats: _seats,
      isCaptain: false,
      currentUserId: 'u1',
      currentParticipantId: 1,
    );

final _people = [
  for (final s in _seats.skip(1))
    ScheduleParticipant(
      participantId: s.participantId,
      uid: s.userId,
      name: s.name,
      phone: '',
      businessName: s.businessName,
      businessCategory: s.category,
    ),
];

Referral _ref(String id, String other, String biz, {required bool given, int round = 2}) => Referral(
      id: id,
      conclaveId: 'past',
      roundNumber: round,
      fromUserId: given ? 'u1' : 'x',
      toUserId: given ? 'x' : 'u1',
      otherName: other,
      otherBusinessName: biz,
      notes: '',
      createdAt: _day(-30, 10),
      synced: true,
    );

final _overrides = [
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      myProfileProvider.overrideWith((ref) => Stream.value(_me)),
      conclavesStreamProvider.overrideWith((ref) => Stream.value(_conclaves)),
      notificationsProvider.overrideWith((ref) async => const NotificationsData(items: [], unreadCount: 2)),
      myOneToOnesProvider.overrideWith((ref) async => [
            OneToOne(
              id: 'a',
              sent: false,
              otherUserId: 'u2',
              otherName: 'Priya Sharma',
              otherBusinessName: 'Sharma Chartered Accountants',
              otherPhotoUrl: null,
              proposedAt: _day(2, 11),
              location: 'Coffee Day, Lakshmipuram',
              note: '',
              status: OneToOneStatus.accepted,
            ),
          ]),
      myReferralsProvider.overrideWith((ref) async => MyReferrals(given: [
            for (var i = 0; i < 7; i++)
              ReferralEntry(
                id: 'g$i',
                conclaveId: 'past',
                conclaveName: 'Tenali Connect 2026',
                roundNumber: i % 6 + 1,
                otherName: 'Member $i',
                otherBusinessName: '',
                notes: '',
                outcome: i < 2 ? ReferralOutcome.closed : ReferralOutcome.open,
                closedAmount: i < 2 ? 180000 : 0,
                outcomeNote: '',
                createdAt: _day(-30, 10),
              ),
          ], received: [
            for (var i = 0; i < 5; i++)
              ReferralEntry(
                id: 'r$i',
                conclaveId: 'past',
                conclaveName: 'Tenali Connect 2026',
                roundNumber: i + 1,
                otherName: 'Member $i',
                otherBusinessName: '',
                notes: '',
                outcome: i < 2 ? ReferralOutcome.closed : ReferralOutcome.open,
                closedAmount: [240000, 185000][i.clamp(0, 1)],
                outcomeNote: '',
                createdAt: _day(-30, 10),
              ),
          ])),
      syncServiceProvider.overrideWithValue(_FakeSync()),
      conclaveSummaryProvider('past').overrideWith((ref) async => ConclaveSummary(
            attendance: [
              for (var r = 1; r <= 6; r++) RoundAttendance(roundNumber: r, isPresent: true, synced: true),
            ],
            referrals: ReferralSummary(
              given: [
                _ref('1', 'Priya Sharma', 'Sharma Chartered Accountants', given: true, round: 1),
                _ref('2', 'Kiran Kumar', 'KK Realty', given: true, round: 2),
                _ref('3', 'Lakshmi Devi', 'Devi Caterers', given: true, round: 4),
                _ref('4', 'Sneha Rao', 'Rao Digital', given: true, round: 5),
              ],
              received: [
                _ref('5', 'Rahul Varma', 'Varma Insurance', given: false, round: 3),
                _ref('6', 'Kiran Kumar', 'KK Realty', given: false, round: 2),
                _ref('7', 'Sneha Rao', 'Rao Digital', given: false, round: 5),
              ],
              mutualUids: const {'x'},
            ),
          )),
      summaryJourneyProvider('past').overrideWith((ref) async => SummaryJourney(
            conclaveName: 'Tenali Connect 2026',
            rounds: [
              for (var r = 1; r <= 6; r++)
                RoundStop(roundNumber: r, tableNumber: [4, 7, 2, 9, 5, 1][r - 1], wasCaptain: false, tablemates: 5),
            ],
            people: _people,
          )),
      peopleMetProvider('past').overrideWith((ref) async => [
            for (final s in _seats.skip(1))
              MetPerson(
                uid: s.userId,
                name: s.name,
                businessName: s.businessName,
                businessCategory: s.category,
                phone: '',
                rounds: [s.participantId % 6 + 1],
              ),
          ]),
    ];

/// A tab root with the floating tab bar over it, as in the app.
Widget _tab(int index, Widget page) => Scaffold(
      body: Stack(children: [
        page,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 12),
            child: Center(child: AppNavPill(currentIndex: index, onTap: (_) {})),
          ),
        ),
      ]),
    );

Widget _deck(Duration elapsed) => Scaffold(
      body: RoundDeckView(
        round: _round(elapsed),
        now: _now,
        attendance: const {'u1': true, 'u2': true, 'u3': true, 'u4': true, 'u5': true, 'u6': true},
        referred: const {'u3'},
        noted: const {},
        pendingSync: 0,
        onSync: () {},
        onAttendance: (_, _) {},
        onRefer: (_) {},
        onAddNote: (_) {},
        onScan: () {},
        onScanArrivals: () {},
      ),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _font('PlusJakartaSans', 'assets/fonts/PlusJakartaSans.ttf');
    await _font('Coolicons', 'assets/fonts/Coolicons.ttf');
  });

  // Bio phase: 6 people x 60 s, so 90 s in = Priya (2nd) speaking.
  // Referral slot opens after 6 min: 6 min 40 s in.
  final extra = <String, List<dynamic>>{
    '04_conclaves': [conclavesStreamProvider.overrideWith((ref) => Stream.value(_upcoming))],
  };
  final screens = <String, Widget Function()>{
    '01_home': () => _tab(0, const HomeScreen()),
    '02_round': () => _deck(const Duration(seconds: 95)),
    '03_referral': () => _deck(const Duration(minutes: 6, seconds: 40)),
    '04_conclaves': () => _tab(1, const ConclavesListScreen()),
    '05_detail': () => const ConclaveDetailScreen(conclaveId: 'up2'),
    '06_summary': () => const ConclaveSummaryScreen(conclaveId: 'past'),
    '07_people': () => const PeopleMetScreen(conclaveId: 'past'),
    '08_card': () => const MyCardScreen(),
  };

  for (final MapEntry(key: name, value: build) in screens.entries) {
    testWidgets('store screen $name', (tester) async {
      // iPhone 16 Pro Max: 440 x 956 pt @3x = 1320 x 2868.
      tester.view.physicalSize = const Size(1320, 2868);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [..._overrides.where((o) => !(extra[name]?.isNotEmpty ?? false) || !identical(o, _overrides[2])), ...?extra[name]],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Builder(builder: (_) => build()),
        ),
      ));
      await tester.runAsync(() async {
        for (final a in ['assets/images/app_mark.png', 'assets/images/app_mark_white.png', 'assets/images/manuen_logo.png']) {
          await precacheImage(AssetImage(a), tester.element(find.byType(MaterialApp)));
        }
      });
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../store/raw/$name.png'));
    });
  }
}
