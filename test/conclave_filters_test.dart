import 'package:conclave_1_2_1/features/conclaves/data/conclave_filters.dart';
import 'package:conclave_1_2_1/features/conclaves/domain/conclave_model.dart';
import 'package:flutter_test/flutter_test.dart';

Conclave c(DateTime date, {String name = 'Guntur Conclave', String region = 'Guntur', bool mine = false}) =>
    Conclave(
      id: name,
      name: name,
      venueLocation: 'Hotel Grand',
      region: region,
      date: date,
      status: ConclaveStatus.registrationOpen,
      isRegistrationOpen: true,
      isRegistered: mine,
    );

void main() {
  // Wednesday 12 Nov 2026.
  final now = DateTime(2026, 11, 12, 10);

  test('this week runs through Sunday', () {
    const f = ConclaveFilters(when: ConclaveWhen.thisWeek);
    expect(f.matches(c(DateTime(2026, 11, 16 - 1)), upcoming: true, now: now), isTrue); // Sun 15
    expect(f.matches(c(DateTime(2026, 11, 16)), upcoming: true, now: now), isFalse); // Mon 16
  });

  test('this month vs later split at the month boundary', () {
    const month = ConclaveFilters(when: ConclaveWhen.thisMonth);
    const later = ConclaveFilters(when: ConclaveWhen.later);
    expect(month.matches(c(DateTime(2026, 11, 30)), upcoming: true, now: now), isTrue);
    expect(month.matches(c(DateTime(2026, 12, 1)), upcoming: true, now: now), isFalse);
    expect(later.matches(c(DateTime(2026, 12, 1)), upcoming: true, now: now), isTrue);
    expect(later.matches(c(DateTime(2026, 11, 30)), upcoming: true, now: now), isFalse);
  });

  test('December rolls into next year', () {
    const month = ConclaveFilters(when: ConclaveWhen.thisMonth);
    final dec = DateTime(2026, 12, 20);
    expect(month.matches(c(DateTime(2026, 12, 31)), upcoming: true, now: dec), isTrue);
    expect(month.matches(c(DateTime(2027, 1, 1)), upcoming: true, now: dec), isFalse);
  });

  test('date filter only applies to upcoming', () {
    const f = ConclaveFilters(when: ConclaveWhen.thisWeek);
    expect(f.matches(c(DateTime(2027, 5, 1)), upcoming: false, now: now), isTrue);
  });

  test('search, mine and region', () {
    expect(const ConclaveFilters(query: 'grand').matches(c(now), upcoming: true), isTrue);
    expect(const ConclaveFilters(query: 'vijayawada').matches(c(now), upcoming: true), isFalse);
    expect(const ConclaveFilters(mineOnly: true).matches(c(now), upcoming: true), isFalse);
    expect(const ConclaveFilters(mineOnly: true).matches(c(now, mine: true), upcoming: true), isTrue);
    expect(const ConclaveFilters(region: 'Guntur').matches(c(now), upcoming: true), isTrue);
    expect(const ConclaveFilters(region: 'Vizag').matches(c(now), upcoming: true), isFalse);
  });
}
