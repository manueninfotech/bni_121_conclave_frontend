import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../auth/data/auth_repository.dart';

/// One member as shown in the directory.
///
/// Deliberately carries NO contact details — the backend never sends email or
/// phone to this endpoint, so there is nothing sensitive to leak here.
class Member {
  final String uid;
  final String name;
  final String? photoUrl;
  final String businessName;
  final String businessCategory;
  final String location;
  final String? chapter;

  const Member({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.businessName,
    required this.businessCategory,
    required this.location,
    required this.chapter,
  });

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        uid: (j['uid'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        photoUrl: (j['photoUrl'] as String?)?.isEmpty ?? true
            ? null
            : j['photoUrl'] as String,
        businessName: (j['businessName'] ?? '') as String,
        businessCategory: (j['businessCategory'] ?? '') as String,
        location: (j['location'] ?? '') as String,
        chapter: (j['chapter'] as String?)?.isEmpty ?? true
            ? null
            : j['chapter'] as String,
      );

  /// Everything the search box matches against.
  String get searchable =>
      '$name $businessName $businessCategory $location'.toLowerCase();
}

final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  return MembersRepository(FirebaseAuth.instance);
});

/// The whole directory. Re-fetches when the signed-in user changes.
final membersProvider = FutureProvider<List<Member>>((ref) {
  ref.watch(authStateProvider.select((a) => a.asData?.value?.uid));
  return ref.watch(membersRepositoryProvider).listMembers();
});

class MembersRepository {
  final FirebaseAuth _auth;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  MembersRepository(this._auth);

  Future<List<Member>> listMembers() async {
    final user = _auth.currentUser;
    if (user == null) return const [];

    final token = await user.getIdToken();
    try {
      final res = await _dio.get(
        '${ApiConfig.baseUrl}/members',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      final list = (data is Map ? data['members'] : data) as List? ?? const [];
      return list
          .map((e) => Member.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['error'] ?? '').toString()
          : '';
      throw Exception(msg.isNotEmpty
          ? msg
          : 'Could not load the member directory. Check your connection.');
    }
  }
}
