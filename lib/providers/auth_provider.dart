import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

enum SignUpResult { signedIn, needsConfirmation, error }

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isEmailConfirmed => _user?.emailConfirmedAt != null;

  AuthProvider() {
    _user = _supabase.auth.currentUser;
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  bool _emailNotConfirmed = false;
  bool get emailNotConfirmed => _emailNotConfirmed;

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _setError(null);
    _emailNotConfirmed = false;
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      _user = response.user;
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        _emailNotConfirmed = true;
        _setError('email_not_confirmed');   // sentinel value
      } else if (e.message.toLowerCase().contains('invalid login credentials')) {
        _setError('Incorrect email or password. Please try again.');
      } else {
        _setError(e.message);
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resendConfirmationEmail(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: 'medilocker://auth-callback',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Refreshes the session and returns true if email is now confirmed.
  Future<bool> checkEmailConfirmed() async {
    try {
      await _supabase.auth.refreshSession();
      final user = _supabase.auth.currentUser;
      if (user?.emailConfirmedAt != null) {
        _user = user;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<SignUpResult> signUpWithResult({
    required String email,
    required String password,
    required String fullName,
    String? bloodType,
    String? phoneNumber,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: 'medilocker://auth-callback',
        data: {
          'full_name': fullName,
          'blood_type': bloodType,
          'phone_number': phoneNumber,
        },
      );
      _user = response.user;

      // Create profile record
      if (_user != null) {
        await _supabase.from('profiles').upsert({
          'id': _user!.id,
          'email': email.trim(),
          'full_name': fullName,
          'blood_type': bloodType,
          'phone_number': phoneNumber,
          'allergies': [],
        });
      }

      _setLoading(false);

      // If session exists → user is already signed in (email confirm disabled)
      if (response.session != null) {
        return SignUpResult.signedIn;
      }
      // Otherwise email confirmation is required
      return SignUpResult.needsConfirmation;
    } on AuthException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return SignUpResult.error;
    } catch (e) {
      _setError('Registration failed. Please try again.');
      _setLoading(false);
      return SignUpResult.error;
    }
  }

  // Keep old method for backward compat
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? bloodType,
    String? phoneNumber,
  }) async {
    final result = await signUpWithResult(
      email: email,
      password: password,
      fullName: fullName,
      bloodType: bloodType,
      phoneNumber: phoneNumber,
    );
    return result == SignUpResult.signedIn || result == SignUpResult.needsConfirmation;
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to send reset email.');
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _user = null;
    notifyListeners();
  }
}
