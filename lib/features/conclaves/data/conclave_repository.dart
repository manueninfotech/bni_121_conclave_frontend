import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/config/api_config.dart';
import '../domain/conclave_model.dart';

final conclaveRepositoryProvider = Provider<ConclaveRepository>((ref) {
  return ConclaveRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});

final conclavesStreamProvider = StreamProvider<List<Conclave>>((ref) {
  return ref.watch(conclaveRepositoryProvider).getConclaves();
});

class ConclaveRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  ConclaveRepository(this._firestore, this._auth);

  Stream<List<Conclave>> getConclaves() {
    return _firestore.collection('conclaves').snapshots().asyncMap((snapshot) async {
      final user = _auth.currentUser;
      final List<Conclave> conclaves = [];

      for (var doc in snapshot.docs) {
        var conclave = Conclave.fromFirestore(doc.data(), doc.id);

        if (user != null) {
          // Check if user is registered for this conclave
          final registrationDoc = await _firestore
              .collection('conclaves')
              .doc(doc.id)
              .collection('registrations')
              .doc(user.uid)
              .get();

          if (registrationDoc.exists) {
            final regData = registrationDoc.data()!;
            conclave = conclave.copyWith(
              isRegistered: true,
              userRole: ConclaveRole.fromString(regData['role'] ?? 'member'),
              userTableNumber: regData['tableNumber'],
            );
          }
        }
        conclaves.add(conclave);
      }
      
      // Sort by date descending
      conclaves.sort((a, b) => b.date.compareTo(a.date));
      return conclaves;
    });
  }

  /// Registers the signed-in member for a conclave.
  ///
  /// This goes through the backend rather than writing to Firestore directly,
  /// because it enforces a rule a single client cannot check: you may not hold
  /// registrations for two conclaves whose times OVERLAP. Nobody can attend
  /// both, and registrations cannot be withdrawn — the schedule seats and pairs
  /// you, so a no-show leaves a hole in other people's tables.
  ///
  /// Throws [RegistrationConflict] when it clashes with an existing registration.
  ///
  /// [payment] is included only for paid conclaves: either the Razorpay proof
  /// (`{method:'online', orderId, paymentId, signature}`) for the backend to
  /// verify, or `{method:'offline'}` (optionally with a `utrNumber`) which the
  /// backend records as pending for an admin to reconcile. Free conclaves pass
  /// nothing and register as before.
  Future<void> registerForConclave(
    String conclaveId, {
    Map<String, dynamic>? payment,
    String? utrNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to register.');

    final token = await user.getIdToken();

    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/conclaves/$conclaveId/register',
        data: {
          'payment': ?payment,
          if (utrNumber != null && utrNumber.trim().isNotEmpty)
            'utrNumber': utrNumber.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 409 && data is Map) {
        throw RegistrationConflict(
          (data['error'] ?? 'This conclave clashes with another registration.')
              as String,
          conflictName: (data['conflictsWith']?['name'] ?? '') as String,
        );
      }
      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }
      throw Exception('Could not reach the server to register. Try again.');
    }
  }
}

/// The member is already registered for an overlapping conclave.
class RegistrationConflict implements Exception {
  final String message;
  final String conflictName;

  RegistrationConflict(this.message, {this.conflictName = ''});

  @override
  String toString() => message;
}
