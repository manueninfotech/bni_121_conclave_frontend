import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/cached_stream.dart';
import '../../features/auth/data/auth_repository.dart';

/// Admin-managed settings the app needs (business categories, round timing,
/// auto-logout), from `GET /app-config`. Cached on the device and refreshed
/// every few minutes, so an admin change reaches phones without a release.
class AppConfig {
  final List<String> categories;
  final Map<String, dynamic> roundTiming;
  final int? autoLogoutHours;

  const AppConfig({required this.categories, required this.roundTiming, this.autoLogoutHours});

  factory AppConfig.fromJson(Object? json) {
    final m = json is Map ? json : const {};
    return AppConfig(
      categories: [
        for (final c in (m['categories'] is List ? m['categories'] as List : const []))
          if ((c?.toString().trim() ?? '').isNotEmpty) c.toString().trim(),
      ],
      roundTiming: m['roundTiming'] is Map ? Map<String, dynamic>.from(m['roundTiming'] as Map) : const {},
      autoLogoutHours: (m['autoLogoutHours'] as num?)?.toInt(),
    );
  }
}

final appConfigProvider = StreamProvider<AppConfig>((ref) {
  // Signed-in only (the endpoint needs a token); re-subscribe on account change.
  final uid = ref.watch(authStateProvider.select((a) => a.asData?.value?.uid));
  if (uid == null) return const Stream.empty();
  return cachedStream<AppConfig>(
    cacheKey: 'app-config',
    fetch: () => ApiClient.instance.getJson('/app-config'),
    parse: AppConfig.fromJson,
    refresh: const Duration(minutes: 5),
  );
});
