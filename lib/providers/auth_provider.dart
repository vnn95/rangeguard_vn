import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rangeguard_vn/models/user_model.dart';
import 'package:rangeguard_vn/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authState = await ref.watch(authStateProvider.future);
  if (authState.session == null) return null;
  final repo = ref.watch(authRepositoryProvider);
  return repo.getCurrentProfile();
});

// Auth state notifier for login/register/logout actions
class AuthNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final profile = await _repo.getCurrentProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.signIn(email: email, password: password);
      final profile = await _repo.getCurrentProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String employeeId,
    required String unit,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.signUp(
        email: email,
        password: password,
        fullName: fullName,
        employeeId: employeeId,
        unit: unit,
      );
      final profile = await _repo.getCurrentProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> updateProfile(UserProfile profile) async {
    try {
      final updated = await _repo.updateProfile(profile);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserProfile?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
