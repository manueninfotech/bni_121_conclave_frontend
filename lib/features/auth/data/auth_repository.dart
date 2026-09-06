import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/domain/phone.dart';
import 'session_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
    ref.watch(sessionServiceProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final SessionService _session;

  AuthRepository(this._auth, this._firestore, this._session);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String businessName,
    required String businessCategory,
    required String location,
    /// The number we ask for even though they signed up by email — the admin
    /// needs to be able to call people on the day.
    required String phone,
    required String membership,
    String? chapter,
    String? region,
  }) async {
    try {
      // 1. Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception("Failed to create user.");

      // Send verification email
      await user.sendEmailVerification();

      // 2. Save additional profile data in Firestore
      await _saveProfileToFirestore(
        user.uid, email, name, businessName, businessCategory, location, chapter,
        email: email,
        phone: phone,
        region: region,
        membership: membership,
      );

      // Registering signs you in, so the auto-logout clock starts here too.
      await _session.recordLogin();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Authentication failed');
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  Future<void> registerProfileForPhoneUser({
    required User user,
    required String phone,
    required String password,
    required String name,
    required String businessName,
    required String businessCategory,
    required String location,
    /// The address we ask for even though they signed up by phone — without it
    /// there is no way to reach them, and no way to ever reset their password.
    required String email,
    required String membership,
    String? chapter,
    String? region,
  }) async {
    try {
      // Firebase has no "phone + password" sign-in, so the account is keyed by a
      // synthetic address built from the E.164 number. Phone.toAuthEmail is the
      // ONLY place that mapping exists — login and registration each deriving it
      // separately is exactly how "9515409973" and "+919515409973" became two
      // different accounts.
      final pseudoEmail = Phone.toAuthEmail(phone);
      final credential = EmailAuthProvider.credential(email: pseudoEmail, password: password);
      try {
        await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        // Recovery case: this account was authenticated by OTP on a previous,
        // interrupted attempt and the password was already linked. That's fine —
        // the goal (a phone account that can also sign in with a password) is
        // already met, so carry on and save the profile rather than failing.
        if (e.code != 'provider-already-linked' &&
            e.code != 'credential-already-in-use' &&
            e.code != 'email-already-in-use') {
          rethrow;
        }
      }

      // Save profile. `identifier` stays the synthetic address (that IS how they
      // sign in); the real email is stored separately.
      await _saveProfileToFirestore(
        user.uid, pseudoEmail, name, businessName, businessCategory, location, chapter,
        email: email,
        phone: phone,
        region: region,
        membership: membership,
      );

      await _session.recordLogin();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to set password');
    }
  }

  /// Saves the profile.
  ///
  /// BOTH contacts are stored, always — whichever one you signed up with, we ask
  /// for the other. That is in the original spec ("phonenumber/email (autofilled)
  /// and ask leftover") and it matters:
  ///
  ///  - A phone registration's `identifier` is a SYNTHETIC address
  ///    (919515409973@bni121.conclave) that no mailbox can receive. Without a
  ///    real email, the admin's registration list shows that string where a
  ///    contact should be, and nobody can reach the member.
  ///  - An email registration with no phone leaves the admin unable to call
  ///    anyone at the venue, which is what actually happens on the day.
  Future<void> _saveProfileToFirestore(
    String uid,
    String identifier,
    String name,
    String businessName,
    String businessCategory,
    String location,
    String? chapter, {
    required String email,
    required String phone,
    required String? region,
    required String membership,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'id': uid,
      // How they sign in. Synthetic for phone accounts — never show it to a human.
      'identifier': identifier,
      // Real, reachable contacts.
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'name': name,
      'businessName': businessName,
      'businessCategory': businessCategory,
      'location': location.trim().toLowerCase(),
      'chapter': chapter,
      'region': region,
      // "BNI" or "Non-BNI".
      'membership': membership,
      'country': 'India',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Signs in.
  ///
  /// [identifier] is either a real email address or an E.164 phone number
  /// (`+919515409973`) — the caller resolves the country code, because a bare
  /// ten digits is ambiguous and this app is going international.
  Future<void> login(String identifier, String password) async {
    try {
      final isPhone = identifier.startsWith('+') || Phone.looksLikePhone(identifier);
      final loginEmail =
          isPhone ? Phone.toAuthEmail(identifier) : identifier;

      final userCred = await _auth.signInWithEmailAndPassword(email: loginEmail, password: password);
      final user = userCred.user;

      // If it was a real email login, enforce email verification
      if (!isPhone && user != null && !user.emailVerified) {
        await _auth.signOut();
        throw Exception("Please verify your email before logging in. Check your inbox.");
      }

      // Starts the auto-logout clock, and marks the user active for the admin's
      // snapshot.
      await _session.recordLogin();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Login failed');
    }
  }

  Future<void> verifyPhone({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-resolve on Android
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserCredential> submitOtp(String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final cred = await _auth.signInWithCredential(credential);

      // OTP has just signed them in — but they are only PARTWAY through
      // registration (the profile and password come next). Record the login
      // time locally NOW, so the app's auto-logout check doesn't see a
      // signed-in user with no recorded login, decide the session is expired,
      // and sign them out before they can finish — which orphaned the auth
      // account and produced "no account found".
      await _session.markLocalLogin();
      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Invalid OTP');
    }
  }

  /// Sends a password reset link.
  ///
  /// Only works for accounts registered with a REAL email address. Phone
  /// registrations are stored against a synthetic address
  /// (`<digits>@bni121.conclave`) which no mailbox can receive, so there is
  /// nowhere to send the link — those users have to be reset by an admin.
  /// Silently "succeeding" for them would be worse than saying so.
  Future<void> sendPasswordReset(String identifier) async {
    final id = identifier.trim();
    if (id.isEmpty) throw Exception('Enter your email address first.');

    final isPhone = RegExp(r'^\+?[0-9]{10,15}$').hasMatch(id);
    if (isPhone) {
      throw Exception(
        'This account was registered with a phone number, so there is no email '
        'address to send a reset link to. Please contact the admin.',
      );
    }

    try {
      await _auth.sendPasswordResetEmail(email: id);
    } on FirebaseAuthException catch (e) {
      // Don't confirm or deny whether an address is registered — that would let
      // anyone enumerate members' email addresses.
      if (e.code == 'user-not-found') return;
      throw Exception(e.message ?? 'Could not send the reset email.');
    }
  }

  Future<void> logout() async {
    await _session.signOut();
  }

  /// Permanently deletes the signed-in member's account.
  ///
  /// The backend (using the Admin SDK) removes the profile document, its
  /// notifications, and the Firebase Auth login in one authenticated call — the
  /// client cannot delete its own Firestore document (security rules forbid it)
  /// and deleting the auth user client-side would need a fresh re-login. After it
  /// succeeds the local session is cleared, which drops the router to /login.
  ///
  /// Required by App Store Guideline 5.1.1(v): an app with account creation must
  /// let the user delete their account from within the app.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('You are not signed in.');
    final token = await user.getIdToken();
    try {
      await Dio().delete(
        '${ApiConfig.baseUrl}/me/account',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw Exception(
        'Could not delete your account. ${e.response?.statusCode ?? ''} '
        'Please try again, or contact the admin.',
      );
    }
    await _session.signOut();
  }
}
