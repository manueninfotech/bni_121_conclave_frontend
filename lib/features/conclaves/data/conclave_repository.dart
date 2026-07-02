import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<void> registerForConclave(String conclaveId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Must be logged in to register.");

    await _firestore
        .collection('conclaves')
        .doc(conclaveId)
        .collection('registrations')
        .doc(user.uid)
        .set({
      'registeredAt': FieldValue.serverTimestamp(),
      'role': 'member', // Default role upon registration
      'status': 'pending',
    });
  }
}
