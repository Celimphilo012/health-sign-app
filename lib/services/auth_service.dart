import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Current Firebase user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Register ──────────────────────────────────────────
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user!;

      // Update display name
      await user.updateDisplayName(name);

      // Save to Firestore
      final userModel = UserModel(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        role: role == 'nurse' ? UserRole.nurse : UserRole.patient,
        createdAt: DateTime.now(),
      );

      await _db.collection('users').doc(user.uid).set(userModel.toFirestore());

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ── Login ─────────────────────────────────────────────
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final doc = await _db.collection('users').doc(uid).get();

      // If Firestore doc missing, create it now
      if (!doc.exists) {
        final userModel = UserModel(
          uid: uid,
          name: credential.user!.displayName ?? email.split('@')[0],
          email: email.trim(),
          role: UserRole.patient, // default role
          createdAt: DateTime.now(),
        );
        await _db.collection('users').doc(uid).set(userModel.toFirestore());
        return userModel;
      }

      return UserModel.fromFirestore(doc);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ── Logout ────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ── Get user data from Firestore ──────────────────────
  Future<UserModel> getUserFromFirestore(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('User data not found');
    return UserModel.fromFirestore(doc);
  }

  // ── Error handler ─────────────────────────────────────
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
