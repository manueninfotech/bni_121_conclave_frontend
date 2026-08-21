import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    FirebaseStorage.instance,
  );
});

/// The signed-in user's profile, as a live stream.
///
/// A stream rather than a one-shot `get()`: the old profile screen used a
/// FutureBuilder, so an edit didn't show up until the screen was rebuilt from
/// scratch.
///
/// It WATCHES auth state so it re-subscribes whenever the signed-in user
/// changes. Without that, this provider bound to `currentUser` exactly once —
/// and since the app starts signed-out, that was `null`. It then kept returning
/// null even after a successful login, so the profile screen showed "no account
/// found" until the whole app was restarted.
final myProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watchMyProfile();
});

class UserProfile {
  final String uid;
  final String name;

  /// Download URL of the member's profile photo, or null for the initials
  /// avatar. Safe to show anywhere — it carries no contact information.
  final String? photoUrl;

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

  /// Optional BNI region (e.g. "Guntur Region") — separate from chapter, used to
  /// tell members from different areas apart.
  final String? region;

  /// "BNI" or "Non-BNI". Chosen at registration; empty only for accounts created
  /// before the field existed.
  final String membership;

  final String country;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.identifier,
    required this.email,
    required this.phone,
    required this.businessName,
    required this.businessCategory,
    required this.location,
    required this.chapter,
    required this.region,
    required this.membership,
    required this.country,
  });

  bool get isBni => membership == 'BNI';

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) {
    return UserProfile(
      uid: uid,
      name: (m['name'] ?? '') as String,
      photoUrl: (m['photoUrl'] as String?)?.isEmpty ?? true
          ? null
          : m['photoUrl'] as String,
      identifier: (m['identifier'] ?? '') as String,
      // Fall back to identifier for accounts created before both were collected.
      email: (m['email'] ?? '') as String,
      phone: (m['phone'] ?? '') as String,
      businessName: (m['businessName'] ?? '') as String,
      businessCategory: (m['businessCategory'] ?? '') as String,
      location: (m['location'] ?? '') as String,
      chapter: m['chapter'] as String?,
      region: (m['region'] as String?)?.isEmpty ?? true
          ? null
          : m['region'] as String,
      membership: (m['membership'] ?? '') as String,
      country: (m['country'] ?? 'India') as String,
    );
  }
}

class ProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  ProfileRepository(this._firestore, this._auth, this._storage);

  /// Uploads a new profile photo and records it on the user document.
  ///
  /// The image is sent to `avatars/{uid}/profile.jpg` — a stable path, so a new
  /// photo overwrites the old rather than accumulating files. The download URL
  /// is written to `users/{uid}.photoUrl`; because the profile is a live stream,
  /// every avatar in the app updates the moment this returns.
  Future<void> uploadAvatar(XFile file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('You are not signed in.');

    final bytes = await file.readAsBytes();
    final ref = _storage.ref('avatars/$uid/profile.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();

    await _firestore.collection('users').doc(uid).set({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Removes the profile photo, reverting to the initials avatar.
  Future<void> removeAvatar() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('You are not signed in.');

    // Best-effort delete of the stored file; the source of truth is the doc
    // field, so clearing that is what actually removes it from the app.
    try {
      await _storage.ref('avatars/$uid/profile.jpg').delete();
    } catch (_) {}

    await _firestore.collection('users').doc(uid).set({
      'photoUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

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
    required String membership,
    String? chapter,
    String? region,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('You are not signed in.');

    if (name.trim().isEmpty) throw Exception('Name cannot be empty.');
    if (businessCategory.trim().isEmpty) {
      throw Exception('Business category is required — it decides who you sit with.');
    }
    if (membership.trim().isEmpty) {
      throw Exception('Choose BNI or Non-BNI.');
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
      'region': region?.trim().isEmpty ?? true ? null : region!.trim(),
      'membership': membership,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
