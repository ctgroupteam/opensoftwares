import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/svg_icons.dart';
import '../providers/crm_provider.dart';
import '../providers/team_filter_provider.dart';
import 'drawer/crm_drawer.dart';
import 'home/home_screen.dart';
import 'pipeline/pipeline_screen.dart';
import 'products/products_screen.dart';
import 'profile/profile_screen.dart';
import 'quick_alert/quick_alert_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selectedTeam = ref.watch(teamFilterProvider);
    final quickAlerts = ref.watch(quickAlertsProvider);
    final activeAlertCount = quickAlerts.where((a) => a.status == 'active').length;

    final List<Widget> tabs = [
      HomeScreen(onNavigateTab: (idx) => setState(() => _currentTabIndex = idx)),
      const PipelineScreen(),
      const ProductsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppConstants.pureWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppConstants.borderSubtle),
              ),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 8),
            const Text(
              'OpenSoftwares CRM',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          // Team Filter Pill (Gulbarga / Solapur / Both)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppConstants.backgroundLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppConstants.borderSubtle),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedTeam,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppConstants.textMuted),
                style: const TextStyle(
                  color: AppConstants.textBlack,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                items: AppConstants.teams.map((t) {
                  return DropdownMenuItem<String>(
                    value: t,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(t),
                    ),
                  );
                }).toList(),
                onChanged: (newTeam) {
                  if (newTeam != null) {
                    ref.read(teamFilterProvider.notifier).state = newTeam;
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Quick Alert Action Shortcut with Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const AppSvgIcon(
                  svg: AppSvgIcons.alert,
                  size: 20,
                  color: AppConstants.darkBlue,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuickAlertScreen()),
                  );
                },
              ),
              if (activeAlertCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppConstants.statusDanger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      '$activeAlertCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      drawer: const CrmDrawer(),
      body: IndexedStack(
        index: _currentTabIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: AppSvgIcon(
              svg: AppSvgIcons.home,
              size: 20,
              color: _currentTabIndex == 0 ? AppConstants.darkBlue : AppConstants.textMuted,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: AppSvgIcon(
              svg: AppSvgIcons.pipeline,
              size: 20,
              color: _currentTabIndex == 1 ? AppConstants.darkBlue : AppConstants.textMuted,
            ),
            label: 'Pipeline',
          ),
          BottomNavigationBarItem(
            icon: AppSvgIcon(
              svg: AppSvgIcons.products,
              size: 20,
              color: _currentTabIndex == 2 ? AppConstants.darkBlue : AppConstants.textMuted,
            ),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: AppSvgIcon(
              svg: AppSvgIcons.user,
              size: 20,
              color: _currentTabIndex == 3 ? AppConstants.darkBlue : AppConstants.textMuted,
            ),
            label: 'My Profile',
          ),
        ],
      ),
    );
  }
}

