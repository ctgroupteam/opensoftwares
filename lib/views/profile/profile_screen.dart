import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/svg_icons.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crm_provider.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../services/update_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _showChangePasswordDialog(BuildContext context) {
    final newPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: newPassCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (newPassCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await SupabaseService.instance.changePassword(newPassCtrl.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password updated successfully!'),
                    backgroundColor: AppConstants.statusSuccess,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.profile;
    final allTasks = ref.watch(tasksProvider);
    final personalTasks = allTasks
        .where((t) => t.assignedTo == user?.id || t.createdBy == user?.id)
        .toList();

    return GradientBackdrop(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Profile Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppConstants.darkBlue,
                    child: Text(
                      user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: AppConstants.pureWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: const TextStyle(
                            color: AppConstants.textBlack,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+91 ${user?.mobileNumber ?? ""}',
                          style: const TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppConstants.darkBlue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user?.role.replaceAll('_', ' ').toUpperCase() ?? 'FOUNDER',
                                style: const TextStyle(
                                  color: AppConstants.darkBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppConstants.skyBlue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user?.team ?? 'Gulbarga',
                                style: const TextStyle(
                                  color: AppConstants.skyBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Notification Settings Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device & System Settings',
                    style: TextStyle(
                      color: AppConstants.textBlack,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1. Allow Notifications Native Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Push Notification Permission',
                              style: TextStyle(
                                color: AppConstants.textBlack,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Enable system push notifications for urgent alerts',
                              style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.darkBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final granted = await NotificationService.instance.requestPermission();
                          await NotificationService.instance.syncDeviceToken();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(granted
                                  ? 'Notification permission granted & token synchronized!'
                                  : 'Please allow notifications in Android Settings.'),
                              backgroundColor: granted ? AppConstants.statusSuccess : AppConstants.statusWarning,
                            ),
                          );
                        },
                        child: const Text('Allow', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppConstants.borderSubtle),

                  // 2. Five Custom Sound Testers (Heads-Up Screen Popups)
                  const Text(
                    'Test Notification Sounds On Device (5 Tones)',
                    style: TextStyle(
                      color: AppConstants.textBlack,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: AppConstants.statusDanger),
                        label: const Text('Alarm Tone', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: AppConstants.backgroundLight,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await NotificationService.instance.sendTestNotification('alarm');
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Alarm Siren notification popped up on screen!'), backgroundColor: AppConstants.statusSuccess),
                          );
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.notifications_active_outlined, size: 16, color: AppConstants.skyBlue),
                        label: const Text('Reminder Chime', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: AppConstants.backgroundLight,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await NotificationService.instance.sendTestNotification('reminder');
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Reminder Chime notification popped up on screen!'), backgroundColor: AppConstants.statusSuccess),
                          );
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_month_outlined, size: 16, color: AppConstants.accentCyan),
                        label: const Text('Meeting Bell', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: AppConstants.backgroundLight,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await NotificationService.instance.sendTestNotification('meeting');
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Meeting Triad Bell notification popped up on screen!'), backgroundColor: AppConstants.statusSuccess),
                          );
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.check_circle_outline, size: 16, color: AppConstants.statusSuccess),
                        label: const Text('Task Pop', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: AppConstants.backgroundLight,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await NotificationService.instance.sendTestNotification('task');
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Task Pop notification popped up on screen!'), backgroundColor: AppConstants.statusSuccess),
                          );
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.campaign_outlined, size: 16, color: AppConstants.statusWarning),
                        label: const Text('Notice Harmonics', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: AppConstants.backgroundLight,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await NotificationService.instance.sendTestNotification('notice');
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Notice Crystal Chime notification popped up on screen!'), backgroundColor: AppConstants.statusSuccess),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppConstants.borderSubtle),

                  // 3. GitHub In-App Auto-Updater
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.system_update_alt, size: 20, color: AppConstants.skyBlue),
                    title: const Text(
                      'Check for Updates (GitHub)',
                      style: TextStyle(
                        color: AppConstants.textBlack,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Direct cloud updates via GitHub repository without rebuilding APK',
                      style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppConstants.skyBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'v${AppConstants.appVersion}',
                        style: TextStyle(
                          color: AppConstants.skyBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    onTap: () => UpdateService.instance.checkForUpdates(context, silent: false),
                  ),
                  const Divider(height: 14, color: AppConstants.borderSubtle),

                  // 4. Change Password
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_reset, size: 20, color: AppConstants.darkBlue),
                    title: const Text(
                      'Change Account Password',
                      style: TextStyle(
                        color: AppConstants.textBlack,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppConstants.textMuted),
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Personal Tasks Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Tasks',
                        style: TextStyle(
                          color: AppConstants.textBlack,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${personalTasks.length} assigned',
                        style: const TextStyle(color: AppConstants.skyBlue, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (personalTasks.isEmpty)
                    const Text('No pending tasks assigned directly to you', style: TextStyle(color: AppConstants.textMuted, fontSize: 12))
                  else
                    ...personalTasks.take(4).map((t) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text('Priority: ${t.priority} • Status: ${t.status}'),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Logout Action
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppConstants.statusDanger),
              foregroundColor: AppConstants.statusDanger,
            ),
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const AppSvgIcon(
              svg: AppSvgIcons.logout,
              size: 16,
              color: AppConstants.statusDanger,
            ),
            label: const Text('Sign Out'),
          ),
          const SizedBox(height: 36),

          // Developer Attribution in Settings at bottom
          const Center(
            child: Column(
              children: [
                Text(
                  'Software Crafted By',
                  style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                ),
                SizedBox(height: 2),
                Text(
                  AppConstants.developerAttribution,
                  style: TextStyle(
                    color: AppConstants.darkBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Enterprise Build v1.0.0',
                  style: TextStyle(color: AppConstants.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
