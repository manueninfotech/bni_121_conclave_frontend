import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/conclave_model.dart';

/// When an upcoming conclave happens, relative to today.
enum ConclaveWhen { any, thisWeek, thisMonth, later }

extension ConclaveWhenLabel on ConclaveWhen {
  String get label => switch (this) {
        ConclaveWhen.any => 'Any time',
        ConclaveWhen.thisWeek => 'This week',
        ConclaveWhen.thisMonth => 'This month',
        ConclaveWhen.later => 'Later',
      };
}

/// The Conclaves tab filters. Kept for the app session (they survive moving
/// between tabs) and reset on restart.
class ConclaveFilters {
  final String query;
  final bool mineOnly;
  final String? region;
  final ConclaveWhen when;

  const ConclaveFilters({
    this.query = '',
    this.mineOnly = false,
    this.region,
    this.when = ConclaveWhen.any,
  });

  bool get isActive =>
      query.trim().isNotEmpty || mineOnly || region != null || when != ConclaveWhen.any;

  ConclaveFilters copyWith({
    String? query,
    bool? mineOnly,
    String? region,
    bool clearRegion = false,
    ConclaveWhen? when,
  }) =>
      ConclaveFilters(
        query: query ?? this.query,
        mineOnly: mineOnly ?? this.mineOnly,
        region: clearRegion ? null : (region ?? this.region),
        when: when ?? this.when,
      );

  /// Whether [c] passes. [upcoming] gates the date filter (it only applies to
  /// conclaves still ahead).
  bool matches(Conclave c, {required bool upcoming, DateTime? now}) {
    if (mineOnly && !c.isRegistered) return false;
    if (region != null && c.region != region) return false;
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty &&
        !c.name.toLowerCase().contains(q) &&
        !c.venueLocation.toLowerCase().contains(q) &&
        !c.region.toLowerCase().contains(q)) {
      return false;
    }
    if (upcoming && when != ConclaveWhen.any) {
      final today = now ?? DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      final day = DateTime(c.date.year, c.date.month, c.date.day);
      final weekEnd = start.add(Duration(days: 8 - start.weekday)); // through Sunday
      final monthEnd = DateTime(start.year, start.month + 1, 1);
      final inWeek = day.isBefore(weekEnd);
      final inMonth = day.isBefore(monthEnd);
      switch (when) {
        case ConclaveWhen.thisWeek:
          if (!inWeek) return false;
        case ConclaveWhen.thisMonth:
          if (!inMonth) return false;
        case ConclaveWhen.later:
          if (inMonth) return false;
        case ConclaveWhen.any:
          break;
      }
    }
    return true;
  }
}

class ConclaveFiltersNotifier extends Notifier<ConclaveFilters> {
  @override
  ConclaveFilters build() => const ConclaveFilters();

  void setQuery(String q) => state = state.copyWith(query: q);
  void toggleMine() => state = state.copyWith(mineOnly: !state.mineOnly);
  void setRegion(String? r) =>
      state = r == null ? state.copyWith(clearRegion: true) : state.copyWith(region: r);
  void setWhen(ConclaveWhen w) => state = state.copyWith(when: w);
  void clear() => state = const ConclaveFilters();
}

final conclaveFiltersProvider =
    NotifierProvider<ConclaveFiltersNotifier, ConclaveFilters>(ConclaveFiltersNotifier.new);
