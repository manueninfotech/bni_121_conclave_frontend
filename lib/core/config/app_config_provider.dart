import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/cached_stream.dart';
import '../../features/auth/data/auth_repository.dart';

/// Admin-managed settings the app needs (business categories, round timing,
/// auto-logout), from `GET /app-config`. Cached on the device and refreshed
/// every few minutes, so an admin change reaches phones without a release.
class AppConfig {
  final List<String> categories;

  /// Organiser-managed BNI chapters. Empty = no list yet (the app shows a text
  /// field instead of a picker).
  final List<String> chapters;
  final Map<String, dynamic> roundTiming;
  final int? autoLogoutHours;

  const AppConfig({
    required this.categories,
    required this.roundTiming,
    this.autoLogoutHours,
    this.chapters = const [],
  });

  factory AppConfig.fromJson(Object? json) {
    final m = json is Map ? json : const {};
    return AppConfig(
      categories: [
        for (final c
            in (m['categories'] is List ? m['categories'] as List : const []))
          if ((c?.toString().trim() ?? '').isNotEmpty) c.toString().trim(),
      ],
      roundTiming: m['roundTiming'] is Map
          ? Map<String, dynamic>.from(m['roundTiming'] as Map)
          : const {},
      autoLogoutHours: (m['autoLogoutHours'] as num?)?.toInt(),
      chapters: [
        for (final c
            in (m['chapters'] is List ? m['chapters'] as List : const []))
          if ((c?.toString().trim() ?? '').isNotEmpty) c.toString().trim(),
      ],
    );
  }
}

final appConfigProvider = StreamProvider<AppConfig>((ref) {
  // Public endpoint: loads signed out too, so email sign-up (which creates the
  // account only after the form) still gets the chapter list. Re-subscribes
  // on account change, since the device cache is kept per account.
  ref.watch(authStateProvider.select((a) => a.asData?.value?.uid));
  return cachedStream<AppConfig>(
    cacheKey: 'app-config',
    fetch: () => ApiClient.instance.getJson('/app-config'),
    parse: AppConfig.fromJson,
    refresh: const Duration(minutes: 5),
  );
});

/// The chapter pick list; empty until an organiser adds chapters in the panel.
final chaptersProvider = Provider<List<String>>(
  (ref) => ref.watch(appConfigProvider).asData?.value.chapters ?? const [],
);
