import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../auth/data/auth_repository.dart';

/// One entry in the member's notification inbox.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        type: (j['type'] ?? '') as String,
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        read: (j['read'] ?? false) as bool,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String)?.toLocal(),
      );
}

class NotificationsData {
  final List<AppNotification> items;
  final int unreadCount;
  const NotificationsData({required this.items, required this.unreadCount});
  static const empty = NotificationsData(items: [], unreadCount: 0);
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(FirebaseAuth.instance);
});

final notificationsProvider = FutureProvider<NotificationsData>((ref) {
  ref.watch(authStateProvider.select((a) => a.asData?.value?.uid));
  return ref.watch(notificationsRepositoryProvider).list();
});

/// Just the unread count — handy for a badge without rebuilding on list content.
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).asData?.value.unreadCount ?? 0;
});

class NotificationsRepository {
  final FirebaseAuth _auth;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  NotificationsRepository(this._auth);

  Future<Options> _opts() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('You are not signed in.');
    final token = await user.getIdToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<NotificationsData> list() async {
    if (_auth.currentUser == null) return NotificationsData.empty;
    try {
      final res = await _dio.get(
        '${ApiConfig.baseUrl}/me/notifications',
        options: await _opts(),
      );
      final data = res.data as Map;
      final items = ((data['notifications'] as List?) ?? const [])
          .map((e) => AppNotification.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      return NotificationsData(
        items: items,
        unreadCount: (data['unreadCount'] as num?)?.toInt() ??
            items.where((n) => !n.read).length,
      );
    } on DioException {
      throw Exception('Could not load notifications.');
    }
  }

  Future<void> markAllRead() async {
    if (_auth.currentUser == null) return;
    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/me/notifications/read',
        options: await _opts(),
      );
    } on DioException {
      // Non-fatal — the badge just stays until the next successful sync.
    }
  }
}
