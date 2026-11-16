import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/crm_profile.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

class AuthState {
  final bool isLoading;
  final User? user;
  final CrmProfile? profile;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.user,
    this.profile,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null && profile != null;

  AuthState copyWith({
    bool? isLoading,
    User? user,
    CrmProfile? profile,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      final profile = await SupabaseService.instance.getCurrentProfile();
      state = AuthState(user: currentUser, profile: profile, isLoading: false);
      await NotificationService.instance.syncDeviceToken();
    } else {
      state = AuthState(isLoading: false);
    }
  }

  Future<bool> login(String mobile, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await SupabaseService.instance.login(mobile, password);
      if (response.user != null) {
        final profile = await SupabaseService.instance.getCurrentProfile();
        if (profile?.isDisabled == true) {
          await SupabaseService.instance.logout();
          state = AuthState(
            isLoading: false,
            errorMessage: 'Account is disabled. Please contact Admin Founder.',
          );
          return false;
        }

        state = AuthState(
          user: response.user,
          profile: profile,
          isLoading: false,
        );
        await NotificationService.instance.syncDeviceToken();
        return true;
      }
      state = AuthState(isLoading: false, errorMessage: 'Invalid credentials');
      return false;
    } catch (e) {
      state = AuthState(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await SupabaseService.instance.logout();
    state = AuthState(isLoading: false);
  }

  Future<void> refreshProfile() async {
    final profile = await SupabaseService.instance.getCurrentProfile();
    state = state.copyWith(profile: profile);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
