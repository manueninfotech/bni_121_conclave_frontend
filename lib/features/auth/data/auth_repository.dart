import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    String? chapter,
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
    String? chapter,
  }) async {
    try {
      // Firebase has no "phone + password" sign-in, so the account is keyed by a
      // synthetic address built from the E.164 number. Phone.toAuthEmail is the
      // ONLY place that mapping exists — login and registration each deriving it
      // separately is exactly how "9515409973" and "+919515409973" became two
      // different accounts.
      final pseudoEmail = Phone.toAuthEmail(phone);
      final credential = EmailAuthProvider.credential(email: pseudoEmail, password: password);
      await user.linkWithCredential(credential);

      // Save profile
      await _saveProfileToFirestore(
        user.uid, phone, name, businessName, businessCategory, location, chapter,
      );

      await _session.recordLogin();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to set password');
    }
  }

  Future<void> _saveProfileToFirestore(
    String uid, String identifier, String name, String businessName, 
    String businessCategory, String location, String? chapter
  ) async {
    await _firestore.collection('users').doc(uid).set({
      'id': uid,
      'identifier': identifier,
      'name': name,
      'businessName': businessName,
      'businessCategory': businessCategory,
      'location': location.trim().toLowerCase(),
      'chapter': chapter,
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
      return await _auth.signInWithCredential(credential);
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
}
