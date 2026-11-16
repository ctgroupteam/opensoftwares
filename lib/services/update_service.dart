import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';

class UpdateService {
  static final UpdateService instance = UpdateService._internal();
  UpdateService._internal();

  bool _isChecking = false;

  Future<void> checkForUpdates(BuildContext context, {bool silent = false}) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final uri = Uri.parse('https://api.github.com/repos/${AppConstants.githubRepo}/releases/latest');
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final latestTag = (data['tag_name'] as String? ?? '').replaceAll('v', '').trim();
        final releaseNotes = data['body'] as String? ?? 'Enhancements and operational fixes.';
        final assets = data['assets'] as List<dynamic>? ?? [];

        // Find APK download asset
        String? apkDownloadUrl;
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            apkDownloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
        apkDownloadUrl ??= data['html_url'] as String?;

        final currentVersion = AppConstants.appVersion.replaceAll('v', '').trim();

        if (_isNewerVersion(currentVersion, latestTag) && context.mounted) {
          _showUpdateDialog(context, latestTag, releaseNotes, apkDownloadUrl);
        } else if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('App is up to date (v$currentVersion). No new update.'),
              backgroundColor: AppConstants.statusSuccess,
            ),
          );
        }
      } else if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No GitHub release found yet. You are running the latest build.'),
            backgroundColor: AppConstants.darkBlue,
          ),
        );
      }
    } catch (e) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update check failed: $e'),
            backgroundColor: AppConstants.statusDanger,
          ),
        );
      }
    } finally {
      _isChecking = false;
    }
  }

  bool _isNewerVersion(String current, String latest) {
    if (latest.isEmpty || current.isEmpty) return false;
    try {
      final curParts = current.split('.').map(int.parse).toList();
      final latParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < curParts.length ? curParts[i] : 0;
        final l = i < latParts.length ? latParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }

  void _showUpdateDialog(
    BuildContext context,
    String latestVersion,
    String releaseNotes,
    String? downloadUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppConstants.skyBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.system_update_alt, color: AppConstants.skyBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Update Available (v$latestVersion)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A new version of ${AppConstants.appName} is ready on GitHub. Update now to get the latest features.',
              style: TextStyle(fontSize: 13, color: AppConstants.textBlack),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConstants.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppConstants.borderSubtle),
              ),
              child: Text(
                releaseNotes,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppConstants.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.darkBlue),
            onPressed: () async {
              Navigator.pop(ctx);
              if (downloadUrl != null) {
                final uri = Uri.parse(downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}

