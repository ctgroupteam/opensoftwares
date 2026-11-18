import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'OpenSoftwares CRM';
  static const String appVersion = '1.0.7';
  static const String developerAttribution = 'Yahya Mundewadi - yahya.in';
  static const String adminFixedNumber = '9307426215';

  // GitHub Repository Reference
  static const String githubRepo = 'ctgroupteam/opensoftwares';

  // Supabase Configuration
  static const String supabaseUrl = 'https://jjraluhoybumzpdikark.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpqcmFsdWhveWJ1bXpwZGlrYXJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIzOTMxODMsImV4cCI6MjA5Nzk2OTE4M30.N1_17ZWppfiHlyhZUjkmvoYf98_1qyiAWJ5uEihQx2M';

  // Branding Palette
  static const Color darkBlue = Color(0xFF0A192F);
  static const Color navyBlue = Color(0xFF1E293B);
  static const Color skyBlue = Color(0xFF0284C7);
  static const Color lightSkyBlue = Color(0xFF38BDF8);
  static const Color accentCyan = Color(0xFF00B4D8);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color borderSubtle = Color(0xFFE2E8F0);
  static const Color textBlack = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusDanger = Color(0xFFEF4444);

  // Teams
  static const List<String> teams = ['Gulbarga', 'Solapur', 'Both'];

  // Mobile sanitizer helper (strips +91, 0, spaces, dashes)
  static String sanitizeMobile(String mobile) {
    var cleaned = mobile.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 12 && cleaned.startsWith('91')) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.length == 11 && cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  // Email alias helper
  static String formatEmail(String mobile) {
    final sanitized = sanitizeMobile(mobile);
    return '$sanitized@opensoftwares.app';
  }
}

