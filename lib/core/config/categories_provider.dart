import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/business_categories.dart';
import 'app_config_provider.dart';

/// Business-category list, managed by admins in the panel and served by the
/// backend (`GET /app-config`, cached on the device). Cleaned, de-duplicated and
/// sorted A–Z with "Other" last. The bundled [bniBusinessCategories] is the
/// offline / first-run fallback, so the picker is never empty.
final _categoriesDocProvider = Provider<List<String>?>((ref) {
  final raw = ref.watch(appConfigProvider).asData?.value.categories;
  if (raw == null) return null;
  final seen = <String>{};
  final list = <String>[];
  for (final s in raw) {
    if (seen.add(s.toLowerCase())) list.add(s);
  }
  list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final otherIdx = list.indexWhere((c) => c.toLowerCase() == 'other');
  if (otherIdx >= 0) list.add(list.removeAt(otherIdx));
  return list;
});

/// Always a non-empty category list: the admin-managed list when available,
/// otherwise the bundled fallback. Consumers read this and never touch the raw
/// stream, so they never see a loading/empty state.
final categoriesProvider = Provider<List<String>>((ref) {
  final list = ref.watch(_categoriesDocProvider);
  return (list == null || list.isEmpty) ? bniBusinessCategories : list;
});
