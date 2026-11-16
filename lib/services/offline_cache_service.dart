import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crm_record.dart';

class OfflineCacheService {
  static const String _keyRecords = 'cached_crm_records';

  static Future<void> cacheRecords(List<CrmRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = records.map((r) => r.toJson()).toList();
      await prefs.setString(_keyRecords, jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<CrmRecord>> getCachedRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyRecords);
      if (str == null || str.isEmpty) return [];
      final list = jsonDecode(str) as List<dynamic>;
      return list
          .map((item) => CrmRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRecords);
  }
}
