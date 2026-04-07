import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ── Initialize: check if user is already logged in ───
  Future<void> initialize() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      try {
        _user = await _authService.getUserFromFirestore(firebaseUser.uid);
        _status = AuthStatus.authenticated;
      } catch (_) {
        _status = AuthStatus.unauthenticated;
        await _authService.logout();
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ── Register ──────────────────────────────────────────
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    _setLoading();
    try {
      _user = await _authService.register(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ── Login ─────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading();
    try {
      _user = await _authService.login(email: email, password: password);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  // Add inside AuthProvider class:

// ── Reset password ────────────────────────────────────
  Future<bool> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim(),
      );
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }
}
