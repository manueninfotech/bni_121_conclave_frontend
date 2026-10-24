import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/cached_stream.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/conclave_model.dart';

final conclaveRepositoryProvider = Provider<ConclaveRepository>((ref) {
  return ConclaveRepository(FirebaseAuth.instance);
});

final conclavesStreamProvider = StreamProvider<List<Conclave>>((ref) {
  // Re-subscribe when the signed-in user changes. getConclaves() stamps each
  // conclave with THIS user's registration ("Registered", role, table), so a
  // logout→login on the same device (no restart) must not leave the previous
  // account's flags on the list.
  ref.watch(authStateProvider.select((a) => a.asData?.value?.uid));
  return ref.watch(conclaveRepositoryProvider).getConclaves();
});

class ConclaveRepository {
  final FirebaseAuth _auth;

  ConclaveRepository(this._auth);

  /// Every conclave, newest first, flagged with this member's registration
  /// (registered / role / table) — from `GET /conclaves`, cached on the device
  /// so the list opens offline, refreshed every 30 seconds while on screen.
  Stream<List<Conclave>> getConclaves() {
    return cachedStream<List<Conclave>>(
      cacheKey: 'conclaves',
      fetch: () => ApiClient.instance.getList('/conclaves'),
      parse: (json) {
        final list = <Conclave>[];
        for (final raw in (json is List ? json : const [])) {
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw);
          var c = Conclave.fromFirestore(m, (m['id'] ?? '') as String);
          if (m['isRegistered'] == true) {
            c = c.copyWith(
              isRegistered: true,
              userRole: ConclaveRole.fromString((m['myRole'] ?? 'member') as String),
              userTableNumber: (m['myTableNumber'] as num?)?.toInt(),
            );
          }
          list.add(c);
        }
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      },
    );
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

    try {
      await ApiClient.instance.send('POST', '/conclaves/$conclaveId/register', {
        'payment': ?payment,
        if (utrNumber != null && utrNumber.trim().isNotEmpty) 'utrNumber': utrNumber.trim(),
      });
    } on ApiException catch (e) {
      // Only a genuine clash — one that names the conflicting conclave — is a
      // RegistrationConflict. The backend returns 409 for other reasons too
      // (e.g. registration closed); those surface with their own message.
      final conflict = e.details['conflictsWith'];
      final conflictName = conflict is Map ? conflict['name'] as String? : null;
      if (e.status == 409 && conflictName != null && conflictName.isNotEmpty) {
        throw RegistrationConflict(e.message, conflictName: conflictName);
      }
      throw Exception(e.isOffline ? 'Could not reach the server to register. Try again.' : e.message);
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
