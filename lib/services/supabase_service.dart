import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/crm_profile.dart';
import '../models/crm_record.dart';
import 'offline_cache_service.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // -------------------------------------------------------------
  // AUTH
  // -------------------------------------------------------------
  Future<AuthResponse> login(String mobile, String password) async {
    final email = AppConstants.formatEmail(mobile);
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password.trim(),
    );
    return response;
  }

  Future<void> logout() async {
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      // Remove device token from crm_notifications
      try {
        await client.from('crm_notifications').delete().eq('user_id', userId);
      } catch (_) {}
    }
    await client.auth.signOut();
    await OfflineCacheService.clearCache();
  }

  Future<CrmProfile?> getCurrentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    final response = await client
        .from('crm_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return CrmProfile.fromJson(response);
  }

  Future<void> changePassword(String newPassword) async {
    await client.auth.updateUser(UserAttributes(password: newPassword.trim()));
    final user = client.auth.currentUser;
    if (user != null) {
      await client
          .from('crm_profiles')
          .update({'first_login_change_required': false})
          .eq('id', user.id);
    }
  }

  // -------------------------------------------------------------
  // RECORDS (Full CRUD + Realtime + Cache)
  // -------------------------------------------------------------
  Future<List<CrmRecord>> fetchRecords({String? entityType, String? team}) async {
    var query = client.from('crm_records').select();

    if (entityType != null && entityType.isNotEmpty) {
      query = query.eq('entity_type', entityType);
    }
    if (team != null && team.isNotEmpty && team != 'Both') {
      query = query.or('team.eq.$team,team.eq.Both');
    }

    final data = await query.order('created_at', ascending: false);
    final records = (data as List)
        .map((e) => CrmRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    // Cache locally for offline resilience
    if (entityType == null) {
      await OfflineCacheService.cacheRecords(records);
    }
    return records;
  }

  Future<CrmRecord> createRecord(CrmRecord record) async {
    final userId = client.auth.currentUser?.id;
    final row = record.toJson();
    row.remove('id');
    row['created_by'] = userId;

    final res = await client.from('crm_records').insert(row).select().single();
    return CrmRecord.fromJson(res);
  }

  Future<CrmRecord> updateRecord(CrmRecord record) async {
    final row = record.toJson();
    final res = await client
        .from('crm_records')
        .update(row)
        .eq('id', record.id)
        .select()
        .single();
    return CrmRecord.fromJson(res);
  }

  Future<void> deleteRecord(String recordId) async {
    await client.from('crm_records').delete().eq('id', recordId);
  }

  // Quick Alert Acknowledgment RPC
  Future<void> acknowledgeAlert(String alertId, String action) async {
    final profile = await getCurrentProfile();
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    await client.rpc('crm_acknowledge_alert', params: {
      'p_alert_id': alertId,
      'p_user_id': userId,
      'p_user_name': profile?.name ?? 'User',
      'p_action': action,
    });
  }

  // Notice board "Seen by" tracker
  Future<void> markNoticeSeen(String noticeId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final res = await client
        .from('crm_records')
        .select('extra_data')
        .eq('id', noticeId)
        .maybeSingle();

    if (res != null) {
      final extra = Map<String, dynamic>.from(res['extra_data'] ?? {});
      final seen = List<String>.from(extra['seen_by'] ?? []);
      if (!seen.contains(userId)) {
        seen.add(userId);
        extra['seen_by'] = seen;
        await client
            .from('crm_records')
            .update({'extra_data': extra})
            .eq('id', noticeId);
      }
    }
  }

  // -------------------------------------------------------------
  // ADMIN PANEL MANAGEMENT (Zero secrets in app, secure RPC/Function)
  // -------------------------------------------------------------
  Future<List<CrmProfile>> getAllProfiles() async {
    final data = await client.from('crm_profiles').select().order('name');
    return (data as List)
        .map((e) => CrmProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> adminCreateUser({
    required String mobile,
    required String password,
    required String name,
    required String role,
    required String team,
    Map<String, dynamic>? permissions,
  }) async {
    // Uses the PostgreSQL secure definer RPC function created in migration
    await client.rpc('crm_admin_create_user', params: {
      'p_mobile': mobile.trim(),
      'p_password': password.trim(),
      'p_name': name.trim(),
      'p_role': role,
      'p_team': team,
      'p_permissions': permissions,
    });
  }

  Future<void> adminUpdateUser({
    required String userId,
    String? name,
    String? role,
    String? team,
    Map<String, dynamic>? permissions,
    bool? isDisabled,
    String? newPassword,
  }) async {
    await client.rpc('crm_admin_update_user', params: {
      'p_user_id': userId,
      'p_name': name,
      'p_role': role,
      'p_team': team,
      'p_permissions': permissions,
      'p_is_disabled': isDisabled,
      'p_new_password': newPassword?.isNotEmpty == true ? newPassword : null,
    });
  }

  // Realtime subscription setup
  RealtimeChannel subscribeToRecords(void Function() onEvent) {
    return client
        .channel('public:crm_records')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'crm_records',
          callback: (payload) {
            onEvent();
          },
        )
        .subscribe();
  }
}
