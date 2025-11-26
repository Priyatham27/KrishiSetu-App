// lib/services/auth_service.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // Email / Password auth
  Future<UserCredential> signUpWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  // Phone OTP flow
  Future<void> verifyPhone({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onVerified, // auto verification
    required void Function(FirebaseAuthException error) onFailed,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) {
        // Auto verification (Android)
        try {
          onVerified(credential);
        } catch (_) {}
      },
      verificationFailed: (e) => onFailed(e),
      codeSent: (verificationId, resendToken) => onCodeSent(verificationId, resendToken),
      codeAutoRetrievalTimeout: (v) {},
      timeout: timeout,
    );
  }

  Future<UserCredential> signInWithSmsCode(String verificationId, String smsCode) {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    return _auth.signInWithCredential(credential);
  }

  String? currentUid() {}

  signInAnonymously() {}
}
