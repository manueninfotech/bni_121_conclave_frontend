import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});

/// The signed-in user's profile, as a live stream.
///
/// A stream rather than a one-shot `get()`: the old profile screen used a
/// FutureBuilder, so an edit didn't show up until the screen was rebuilt from
/// scratch.
final myProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).watchMyProfile();
});

class UserProfile {
  final String uid;
  final String name;

  /// How they sign in. For a phone account this is a SYNTHETIC address
  /// (919515409973@bni121.conclave) — never show it to a human.
  final String identifier;

  /// Real, reachable contacts. Both are collected at registration regardless of
  /// which one was used to sign up.
  final String email;
  final String phone;

  final String businessName;
  final String businessCategory;
  final String location;
  final String? chapter;
  final String country;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.identifier,
    required this.email,
    required this.phone,
    required this.businessName,
    required this.businessCategory,
    required this.location,
    required this.chapter,
    required this.country,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) {
    return UserProfile(
      uid: uid,
      name: (m['name'] ?? '') as String,
      identifier: (m['identifier'] ?? '') as String,
      // Fall back to identifier for accounts created before both were collected.
      email: (m['email'] ?? '') as String,
      phone: (m['phone'] ?? '') as String,
      businessName: (m['businessName'] ?? '') as String,
      businessCategory: (m['businessCategory'] ?? '') as String,
      location: (m['location'] ?? '') as String,
      chapter: m['chapter'] as String?,
      country: (m['country'] ?? 'India') as String,
    );
  }
}

class ProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ProfileRepository(this._firestore, this._auth);

  Stream<UserProfile?> watchMyProfile() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : UserProfile.fromMap(uid, data);
    });
  }

  /// Updates the editable parts of a profile.
  ///
  /// `businessCategory` matters more than it looks: it is the field the matching
  /// engine seats people by, and the ONLY thing enforcing table diversity. A
  /// wrong choice at registration used to be permanent, because there was no way
  /// to change it.
  ///
  /// Editing it is safe for a conclave already in progress: the participant
  /// snapshot is frozen into the conclave document when the schedule is
  /// generated, so a change here affects future conclaves only. It cannot
  /// retroactively corrupt a running event.
  Future<void> updateProfile({
    required String name,
    required String businessName,
    required String businessCategory,
    required String location,
    /// Contact details. Editable because they change — people move numbers and
    /// mailboxes — and because the admin's ability to reach someone depends on
    /// them being current.
    required String email,
    required String phone,
    String? chapter,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('You are not signed in.');

    if (name.trim().isEmpty) throw Exception('Name cannot be empty.');
    if (businessCategory.trim().isEmpty) {
      throw Exception('Business category is required — it decides who you sit with.');
    }

    await _firestore.collection('users').doc(uid).update({
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'businessName': businessName.trim(),
      'businessCategory': businessCategory,
      // Same normalisation as registration: "Guntur", "guntur" and "  GUNTUR  "
      // must group as one place.
      'location': location.trim().toLowerCase(),
      'chapter': chapter?.trim().isEmpty ?? true ? null : chapter!.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
