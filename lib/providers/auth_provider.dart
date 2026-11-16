import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/crm_profile.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import 'crm_provider.dart';

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
  final Ref _ref;

  AuthNotifier(this._ref) : super(AuthState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        var profile = await SupabaseService.instance.getCurrentProfile();
        if (profile == null) {
          await Future.delayed(const Duration(milliseconds: 500));
          profile = await SupabaseService.instance.getCurrentProfile();
        }

        if (profile != null) {
          if (profile.isDisabled) {
            await SupabaseService.instance.logout();
            state = AuthState(isLoading: false, errorMessage: 'Account is disabled.');
            return;
          }
          state = AuthState(user: currentUser, profile: profile, isLoading: false);
          _ref.read(crmProvider.notifier).refresh(showLoading: false);
          await NotificationService.instance.syncDeviceToken();
          return;
        }
      }
    } catch (e) {
      debugPrint('AuthNotifier init error: $e');
    }
    state = AuthState(isLoading: false);
  }

  Future<bool> login(String mobile, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cleanMobile = AppConstants.sanitizeMobile(mobile);
      final response = await SupabaseService.instance.login(cleanMobile, password);
      if (response.user != null) {
        var profile = await SupabaseService.instance.getCurrentProfile();
        
        // Resilience retry
        if (profile == null) {
          await Future.delayed(const Duration(milliseconds: 500));
          profile = await SupabaseService.instance.getCurrentProfile();
        }

        // Automatic profile resolution if profile table has sync lag
        if (profile == null) {
          final meta = response.user!.userMetadata ?? {};
          final role = (cleanMobile == AppConstants.adminFixedNumber || meta['role'] == 'admin_founder')
              ? 'admin_founder'
              : (meta['role'] ?? 'founder');
          final name = meta['name'] ?? (role == 'admin_founder' ? 'Yahya Mundewadi' : 'Team Member');

          try {
            await Supabase.instance.client.from('crm_profiles').upsert({
              'id': response.user!.id,
              'mobile_number': cleanMobile,
              'name': name,
              'role': role,
              'team': 'Both',
              'is_disabled': false,
            });
            profile = await SupabaseService.instance.getCurrentProfile();
          } catch (e) {
            debugPrint('Fallback profile upsert: $e');
          }
        }

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

        // Immediate CRM refresh on successful login
        _ref.read(crmProvider.notifier).refresh(showLoading: true);
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
    _ref.read(crmProvider.notifier).clear();
    state = AuthState(isLoading: false);
  }

  Future<void> refreshProfile() async {
    final profile = await SupabaseService.instance.getCurrentProfile();
    state = state.copyWith(profile: profile);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

