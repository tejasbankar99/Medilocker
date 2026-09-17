import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class ProfileProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProfile(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) {
        _profile = UserProfile.fromJson(data as Map<String, dynamic>);
      }
    } catch (e) {
      _error = 'Failed to load profile.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile(UserProfile updated) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _supabase
          .from('profiles')
          .update(updated.toJson())
          .eq('id', updated.id);
      _profile = updated;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update profile.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearProfile() {
    _profile = null;
    notifyListeners();
  }
}
