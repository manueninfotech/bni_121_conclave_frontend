import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';

final feedbackRepositoryProvider =
    Provider<FeedbackRepository>((ref) => FeedbackRepository());

/// Posts a member's post-conclave feedback to the backend.
class FeedbackRepository {
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  Future<void> submit(
    String conclaveId, {
    required int rating, // 1–5
    String? timing, // 'short' | 'right' | 'long'
    int? referrals,
    String? comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please sign in to share feedback.');
    final token = await user.getIdToken();

    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/conclaves/$conclaveId/feedback',
        data: {
          'rating': rating,
          'timing': ?timing,
          'referrals': ?referrals,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? e.response?.data['error'] : null;
      throw Exception(msg ?? 'Could not send feedback. Try again.');
    }
  }
}
