import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/cached_stream.dart';
import '../../../core/config/api_config.dart';

import '../../auth/data/auth_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(FirebaseAuth.instance);
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

  /// Matchmaking: what business this member is looking for, and what they can
  /// offer. Free text, both optional.
  final String lookingFor;
  final String canOffer;

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
    required this.lookingFor,
    required this.canOffer,
    required this.country,
  });

  bool get isBni => membership == 'BNI';

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) {
    return UserProfile(
      uid: uid,
      name: (m['name'] ?? '') as String,
      photoUrl: ApiConfig.resolveUrl(m['photoUrl'] as String?),
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
      lookingFor: (m['lookingFor'] ?? '') as String,
      canOffer: (m['canOffer'] ?? '') as String,
      country: (m['country'] ?? 'India') as String,
    );
  }
}

class ProfileRepository {
  final FirebaseAuth _auth;

  ProfileRepository(this._auth);

  /// Pings listeners to refetch right after this device changes the profile,
  /// so an edit shows up immediately (not on the next periodic refresh).
  static final _changed = StreamController<void>.broadcast();

  /// Uploads a new profile photo (JPEG). The server stores it, records the
  /// link on the profile, deletes the previous photo, and audits the change.
  Future<void> uploadAvatar(XFile file) async {
    if (_auth.currentUser == null) throw Exception('You are not signed in.');
    final bytes = await file.readAsBytes();
    await _call(() => ApiClient.instance.send('PUT', '/me/photo', {
          'dataUrl': 'data:image/jpeg;base64,${base64Encode(bytes)}',
        }));
    _changed.add(null);
  }

  /// Removes the profile photo, reverting to the initials avatar.
  Future<void> removeAvatar() async {
    if (_auth.currentUser == null) throw Exception('You are not signed in.');
    await _call(() => ApiClient.instance.send('DELETE', '/me/photo'));
    _changed.add(null);
  }

  /// The signed-in member's profile: cached copy first (works offline), then
  /// the server's, refreshed every minute and right after any local edit.
  Stream<UserProfile?> watchMyProfile() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    final out = StreamController<UserProfile?>();
    StreamSubscription<UserProfile?>? inner;
    StreamSubscription<void>? edits;
    void subscribe() {
      inner?.cancel();
      inner = cachedStream<UserProfile?>(
        cacheKey: 'me-profile',
        fetch: () async {
          try {
            return await ApiClient.instance.getJson('/me/profile');
          } on ApiException catch (e) {
            if (e.status == 404) return null; // no profile yet
            rethrow;
          }
        },
        parse: (json) => json is Map ? UserProfile.fromMap(uid, Map<String, dynamic>.from(json)) : null,
        refresh: const Duration(minutes: 1),
      ).listen(out.add, onError: out.addError);
    }

    out.onListen = () {
      subscribe();
      edits = _changed.stream.listen((_) => subscribe());
    };
    out.onCancel = () async {
      await edits?.cancel();
      await inner?.cancel();
    };
    return out.stream;
  }

  static Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
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
    String lookingFor = '',
    String canOffer = '',
  }) async {
    if (_auth.currentUser == null) throw Exception('You are not signed in.');

    if (name.trim().isEmpty) throw Exception('Name cannot be empty.');
    if (businessCategory.trim().isEmpty) {
      throw Exception('Business category is required — it decides who you sit with.');
    }
    if (membership.trim().isEmpty) {
      throw Exception('Choose BNI or Non-BNI.');
    }

    await _call(() => ApiClient.instance.send('PUT', '/me', {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'phone': phone.trim(),
          'businessName': businessName.trim(),
          'businessCategory': businessCategory,
          // Same normalisation as registration: "Guntur", "guntur" and
          // "  GUNTUR  " must group as one place.
          'location': location.trim().toLowerCase(),
          'chapter': chapter?.trim().isEmpty ?? true ? null : chapter!.trim(),
          'region': region?.trim().isEmpty ?? true ? null : region!.trim(),
          'membership': membership,
          'lookingFor': lookingFor.trim(),
          'canOffer': canOffer.trim(),
        }));
    _changed.add(null);
  }
}
