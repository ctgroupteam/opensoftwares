import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/crm_profile.dart';
import '../models/crm_record.dart';
import '../services/offline_cache_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';

class CrmState {
  final List<CrmRecord> records;
  final bool isLoading;
  final String? error;

  CrmState({
    this.records = const [],
    this.isLoading = false,
    this.error,
  });

  CrmState copyWith({
    List<CrmRecord>? records,
    bool? isLoading,
    String? error,
  }) {
    return CrmState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CrmNotifier extends StateNotifier<CrmState> {
  RealtimeChannel? _subscription;

  CrmNotifier() : super(CrmState(isLoading: true)) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 1. Instant offline cache load
    final cached = await OfflineCacheService.getCachedRecords();
    if (cached.isNotEmpty) {
      state = CrmState(records: cached, isLoading: false);
    }

    // 2. Network fetch
    await refresh();

    // 3. Supabase Realtime Stream
    _subscription = SupabaseService.instance.subscribeToRecords(() {
      refresh(showLoading: false);
    });
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final fresh = await SupabaseService.instance.fetchRecords();
      state = CrmState(records: fresh, isLoading: false);
      final tasks = fresh.where((r) => r.entityType == 'task').toList();
      NotificationService.instance.checkTaskDeadlines(tasks);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addRecord(CrmRecord record) async {
    try {
      final created = await SupabaseService.instance.createRecord(record);
      state = state.copyWith(records: [created, ...state.records]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateRecord(CrmRecord record) async {
    try {
      final updated = await SupabaseService.instance.updateRecord(record);
      final updatedList = state.records
          .map((r) => r.id == updated.id ? updated : r)
          .toList();
      state = state.copyWith(records: updatedList);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteRecord(String recordId) async {
    try {
      await SupabaseService.instance.deleteRecord(recordId);
      final updatedList =
          state.records.where((r) => r.id != recordId).toList();
      state = state.copyWith(records: updatedList);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateAppConfigExtraData(Map<String, dynamic> newFields) async {
    for (final r in state.records) {
      if (r.title == '[APP_CONFIG]' || r.extraData['is_app_config'] == true) {
        final merged = Map<String, dynamic>.from(r.extraData)..addAll(newFields);
        final updated = r.copyWith(extraData: merged);
        await updateRecord(updated);
        return;
      }
    }
  }

  void clear() {
    state = CrmState(records: [], isLoading: false);
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}

final crmProvider = StateNotifierProvider<CrmNotifier, CrmState>((ref) {
  return CrmNotifier();
});

// Filtered Selectors (Unified Company View)
final teamFilteredRecordsProvider = Provider<List<CrmRecord>>((ref) {
  return ref.watch(crmProvider).records;
});

final productsProvider = Provider<List<CrmRecord>>((ref) {
  final records = ref.watch(teamFilteredRecordsProvider);
  return records.where((r) => r.entityType == 'product').toList();
});

final tasksProvider = Provider<List<CrmRecord>>((ref) {
  final records = ref.watch(teamFilteredRecordsProvider);
  return records.where((r) => r.entityType == 'task').toList();
});

final leadsProvider = Provider<List<CrmRecord>>((ref) {
  final records = ref.watch(teamFilteredRecordsProvider);
  return records.where((r) => r.entityType == 'lead').toList();
});

final channelPartnersProvider = Provider<List<CrmRecord>>((ref) {
  final records = ref.watch(teamFilteredRecordsProvider);
  return records.where((r) => r.entityType == 'partner').toList();
});

final partnerVisitsProvider = Provider<List<CrmRecord>>((ref) {
  final records = ref.watch(teamFilteredRecordsProvider);
  return records.where((r) => r.entityType == 'partner_visit').toList();
});

final clientFollowupsProvider = Provider<List<CrmRecord>>((ref) {
  final records = ref.watch(teamFilteredRecordsProvider);
  return records.where((r) => r.entityType == 'followup').toList();
});

final collectionsProvider = Provider<List<CrmRecord>>((ref) {
  final records = ref.watch(teamFilteredRecordsProvider);
  return records.where((r) => r.entityType == 'collection').toList();
});

final meetingsProvider = Provider<List<CrmRecord>>((ref) {
  final records = ref.watch(teamFilteredRecordsProvider);
  return records.where((r) => r.entityType == 'meeting').toList();
});

final noticesProvider = Provider<List<CrmRecord>>((ref) {
  final records = ref.watch(teamFilteredRecordsProvider);
  return records
      .where((r) =>
          r.entityType == 'notice' &&
          r.title != '[APP_CONFIG]' &&
          r.extraData['is_app_config'] != true)
      .toList();
});

final dynamicAppConfigProvider = Provider<Map<String, dynamic>>((ref) {
  final records = ref.watch(crmProvider).records;
  for (final r in records) {
    if (r.title == '[APP_CONFIG]' || r.extraData['is_app_config'] == true) {
      return r.extraData;
    }
  }
  return const {
    'header_tag': 'Live Cloud Synced',
    'home_banner_subtitle': 'Enterprise Live Sync Active',
    'system_status_text': 'All Systems Operational',
    'system_status_color': 'green',
    'announcement_banner': 'Welcome to OpenSoftwares CRM',
    'show_announcement': false,
  };
});

final quickAlertsProvider = Provider<List<CrmRecord>>((ref) {
  final records = ref.watch(teamFilteredRecordsProvider);
  return records.where((r) => r.entityType == 'quick_alert').toList();
});

final activityLogsProvider = Provider<List<CrmRecord>>((ref) {
  final records = ref.watch(crmProvider).records;
  return records.where((r) => r.entityType == 'activity_log').toList();
});

class ProfilesNotifier extends StateNotifier<List<CrmProfile>> {
  ProfilesNotifier() : super([]) {
    loadProfiles();
  }

  Future<void> loadProfiles() async {
    try {
      final profiles = await SupabaseService.instance.getAllProfiles();
      if (mounted) state = profiles;
    } catch (_) {}
  }
}

final profilesProvider =
    StateNotifierProvider<ProfilesNotifier, List<CrmProfile>>((ref) {
  return ProfilesNotifier();
});

final assigneeOptionsProvider = Provider<List<String>>((ref) {
  final profiles = ref.watch(profilesProvider);
  final names = <String>[];
  for (final p in profiles) {
    final name = p.name.trim();
    if (name.isNotEmpty && !names.contains(name)) {
      names.add(name);
    }
  }
  if (names.isEmpty) {
    names.addAll([
      'Yahya Mundewadi',
      'Shoaib Maindargi',
      'Zubair Ahmed',
      'Sulaiman Sikandar',
    ]);
  }
  names.add('Other (Enter Manually)');
  return names;
});

