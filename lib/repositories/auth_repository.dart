import 'dart:typed_data';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rangeguard_vn/core/supabase/supabase_config.dart';
import 'package:rangeguard_vn/core/constants/app_constants.dart';
import 'package:rangeguard_vn/models/user_model.dart';

final _log = Logger();

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
    // Bước 1: Tạo user trong Supabase Auth
    // Trigger handle_new_user() sẽ tự tạo profile cơ bản
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

    // Bước 2: Upsert profile với đầy đủ thông tin
    // Dùng try/catch vì trigger đã tạo profile rồi (tránh conflict)
    if (response.user != null) {
      try {
        await _client.from(AppConstants.profilesTable).upsert(
          {
            'id': response.user!.id,
            'email': email,
            'full_name': fullName,
            'employee_id': employeeId,
            'unit': unit,
            'role': role,
            'is_active': true,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'id',
        );
      } catch (e) {
        // Không throw ở đây - user đã tạo thành công trong auth
        // Profile sẽ được sync lần sau
        _log.w('Profile upsert after signup failed (non-critical): $e');
      }
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

    try {
      final data = await _client
          .from(AppConstants.profilesTable)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        // Profile chưa có → tạo từ auth metadata
        return await _createProfileFromAuth(user);
      }
      return UserProfile.fromMap(data);
    } catch (e) {
      _log.e('getCurrentProfile error: $e');
      // Fallback: trả về profile tạm từ auth data
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        fullName: user.userMetadata?['full_name'] as String? ?? '',
        employeeId: user.userMetadata?['employee_id'] as String? ?? '',
        unit: user.userMetadata?['unit'] as String? ?? '',
        role: user.userMetadata?['role'] as String? ?? AppConstants.roleRanger,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<UserProfile?> _createProfileFromAuth(User user) async {
    final meta = user.userMetadata ?? {};
    try {
      final data = await _client
          .from(AppConstants.profilesTable)
          .upsert({
            'id': user.id,
            'email': user.email ?? '',
            'full_name': meta['full_name'] as String? ?? '',
            'employee_id': meta['employee_id'] as String? ?? '',
            'unit': meta['unit'] as String? ?? '',
            'role': meta['role'] as String? ?? AppConstants.roleRanger,
            'is_active': true,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'id')
          .select()
          .maybeSingle();
      if (data == null) return null;
      return UserProfile.fromMap(data);
    } catch (e) {
      _log.e('_createProfileFromAuth error: $e');
      return null;
    }
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
        .order('full_name');
    return data.map((e) => UserProfile.fromMap(e)).toList();
  }

  /// Admin tạo tài khoản tuần tra viên mới qua RPC server-side.
  /// Không dùng client phụ → tránh lỗi PKCE async storage.
  Future<UserProfile> createRanger({
    required String email,
    required String password,
    required String fullName,
    required String employeeId,
    required String unit,
    String role = AppConstants.roleRanger,
    String? phone,
    String? stationId,
  }) async {
    // Gọi hàm SECURITY DEFINER trên Supabase – tạo auth.users +
    // auth.identities + profiles trong một transaction duy nhất.
    final newUserId = await _client.rpc('create_ranger_account', params: {
      'p_email':       email.trim().toLowerCase(),
      'p_password':    password,
      'p_full_name':   fullName.trim(),
      'p_employee_id': employeeId.trim(),
      'p_unit':        unit.trim(),
      'p_role':        role,
      'p_phone':       phone?.trim(),
      'p_station_id':  stationId,
    });

    // Trả về profile vừa tạo
    final data = await _client
        .from(AppConstants.profilesTable)
        .select()
        .eq('id', newUserId as String)
        .single();
    return UserProfile.fromMap(data);
  }

  Future<void> toggleRangerActive(String id, bool isActive) async {
    await _client
        .from(AppConstants.profilesTable)
        .update({'is_active': isActive})
        .eq('id', id);
  }

  Future<String?> uploadAvatar(
      String userId, Uint8List bytes, String fileName) async {
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
