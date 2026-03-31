import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rangeguard_vn/core/supabase/supabase_config.dart';
import 'package:rangeguard_vn/core/constants/app_constants.dart';
import 'package:rangeguard_vn/models/user_model.dart';

class AuthRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String employeeId,
    required String unit,
    String role = AppConstants.roleRanger,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'employee_id': employeeId,
        'unit': unit,
        'role': role,
      },
    );

    if (response.user != null) {
      await _client.from(AppConstants.profilesTable).upsert({
        'id': response.user!.id,
        'email': email,
        'full_name': fullName,
        'employee_id': employeeId,
        'unit': unit,
        'role': role,
        'is_active': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    return response;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<UserProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final data = await _client
        .from(AppConstants.profilesTable)
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    final data = await _client
        .from(AppConstants.profilesTable)
        .update(profile.toMap())
        .eq('id', profile.id)
        .select()
        .single();
    return UserProfile.fromMap(data);
  }

  Future<List<UserProfile>> getAllRangers() async {
    final data = await _client
        .from(AppConstants.profilesTable)
        .select()
        .eq('is_active', true)
        .order('full_name');
    return data.map((e) => UserProfile.fromMap(e)).toList();
  }

  Future<String?> uploadAvatar(String userId, List<int> bytes,
      String fileName) async {
    final path = '$userId/avatar/$fileName';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
