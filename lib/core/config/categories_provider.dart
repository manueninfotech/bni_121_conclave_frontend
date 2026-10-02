import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/business_categories.dart';

/// Live business-category list.
///
/// Admins manage categories from the panel; they are stored in Firestore at
/// `settings/businessCategories` (field `categories: string[]`) and the app
/// picks them up in **real time** — no app release needed. (`settings/*` is
/// already readable by any signed-in user, so this needs no rules change.) The
/// bundled [bniBusinessCategories] is the offline / first-run / empty fallback,
/// so the picker is never empty and registration never breaks even if the
/// document is missing or unreadable.
final _categoriesDocProvider = StreamProvider<List<String>>((ref) {
  return FirebaseFirestore.instance
      .collection('settings')
      .doc('businessCategories')
      .snapshots()
      .map((doc) {
    final raw = doc.data()?['categories'];
    if (raw is! List) return const <String>[];

    // Clean + de-dupe (case-insensitively), keep the first spelling seen.
    final seen = <String>{};
    final list = <String>[];
    for (final e in raw) {
      final s = e?.toString().trim() ?? '';
      if (s.isEmpty) continue;
      if (seen.add(s.toLowerCase())) list.add(s);
    }

    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    // Keep the catch-all at the very end, whatever its casing.
    final otherIdx = list.indexWhere((c) => c.toLowerCase() == 'other');
    if (otherIdx >= 0) list.add(list.removeAt(otherIdx));
    return list;
  });
});

/// Always a non-empty category list: the live Firestore list when available,
/// otherwise the bundled fallback. Consumers read this and never touch the raw
/// stream, so they never see a loading/empty state.
final categoriesProvider = Provider<List<String>>((ref) {
  final list = ref.watch(_categoriesDocProvider).asData?.value;
  return (list == null || list.isEmpty) ? bniBusinessCategories : list;
});
