import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/svg_icons.dart';
import '../../providers/auth_provider.dart';
import '../../providers/team_filter_provider.dart';
import '../admin/admin_panel_screen.dart';
import '../quick_alert/quick_alert_screen.dart';
import 'drawer_subscreens.dart';

class CrmDrawer extends ConsumerWidget {
  const CrmDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).profile;
    final isAdmin = user?.isAdminFounder ?? false;

    return Drawer(
      backgroundColor: AppConstants.pureWhite,
      child: Column(
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
            decoration: BoxDecoration(
              color: AppConstants.pureWhite,
              border: const Border(bottom: BorderSide(color: AppConstants.borderSubtle)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppConstants.skyBlue.withOpacity(0.08),
                  AppConstants.pureWhite,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppConstants.pureWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppConstants.borderSubtle),
                  ),
                  child: Image.asset('assets/images/logo.png'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          color: AppConstants.textBlack,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.name ?? 'Founder',
                        style: const TextStyle(
                          color: AppConstants.skyBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Drawer Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  context,
                  svg: AppSvgIcons.chat,
                  title: 'Team Updates & Chat',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamUpdatesScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  svg: AppSvgIcons.calendar,
                  title: 'Meetings & Syncs',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MeetingsScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  svg: AppSvgIcons.money,
                  title: 'Collections Ledger',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionsLedgerScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  svg: AppSvgIcons.notice,
                  title: 'Notice Board',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticeBoardScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  svg: AppSvgIcons.report,
                  title: 'Executive Reports',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExecutiveReportsScreen()));
                  },
                ),
                const Divider(height: 16, color: AppConstants.borderSubtle),
                _buildDrawerItem(
                  context,
                  svg: AppSvgIcons.pipeline,
                  title: 'Gulbarga Team',
                  onTap: () {
                    ref.read(teamFilterProvider.notifier).state = 'Gulbarga';
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerItem(
                  context,
                  svg: AppSvgIcons.pipeline,
                  title: 'Solapur Team',
                  onTap: () {
                    ref.read(teamFilterProvider.notifier).state = 'Solapur';
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 16, color: AppConstants.borderSubtle),
                _buildDrawerItem(
                  context,
                  svg: AppSvgIcons.alert,
                  title: 'Quick Alert Broadcaster',
                  accentColor: AppConstants.statusDanger,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickAlertScreen()));
                  },
                ),
                if (isAdmin) ...[
                  _buildDrawerItem(
                    context,
                    svg: AppSvgIcons.shield,
                    title: 'Admin Panel (Root)',
                    accentColor: AppConstants.darkBlue,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
                    },
                  ),
                ],
              ],
            ),
          ),

          // Pinned Drawer Footer: Developer Attribution
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppConstants.backgroundLight,
              border: Border(top: BorderSide(color: AppConstants.borderSubtle)),
            ),
            child: Row(
              children: [
                AppSvgIcon(svg: AppSvgIcons.settings, size: 16, color: AppConstants.textMuted),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Created & Designed by',
                        style: TextStyle(color: AppConstants.textMuted, fontSize: 10),
                      ),
                      Text(
                        AppConstants.developerAttribution,
                        style: TextStyle(
                          color: AppConstants.darkBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required String svg,
    required String title,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    return ListTile(
      dense: true,
      leading: AppSvgIcon(
        svg: svg,
        size: 18,
        color: accentColor ?? AppConstants.textBlack,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: accentColor ?? AppConstants.textBlack,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 11, color: AppConstants.borderSubtle),
      onTap: onTap,
    );
  }
}
