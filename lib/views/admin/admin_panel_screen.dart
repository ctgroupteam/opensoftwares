import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/svg_icons.dart';
import '../../core/theme.dart';
import '../../models/crm_profile.dart';
import '../../services/supabase_service.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  bool _isUnlocked = false;
  final _passcodeController = TextEditingController();
  String? _unlockError;

  List<CrmProfile> _users = [];
  bool _isLoadingUsers = false;

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  void _verifySecondPassword() {
    final entered = _passcodeController.text.trim();
    if (entered == '#kotlin') {
      setState(() {
        _isUnlocked = true;
        _unlockError = null;
      });
      _fetchUsers();
    } else {
      setState(() => _unlockError = 'Incorrect Admin Passcode');
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final profiles = await SupabaseService.instance.getAllProfiles();
      setState(() => _users = profiles);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Panel Authentication')),
        body: GradientBackdrop(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConstants.darkBlue.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const AppSvgIcon(
                          svg: AppSvgIcons.shield,
                          size: 28,
                          color: AppConstants.darkBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Admin Founder Verification',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppConstants.textBlack,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter your secondary admin passcode to access root system controls.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppConstants.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_unlockError != null) ...[
                        Text(
                          _unlockError!,
                          style: const TextStyle(
                            color: AppConstants.statusDanger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: _passcodeController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Enter Admin Passcode',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                        onSubmitted: (_) => _verifySecondPassword(),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _verifySecondPassword,
                        child: const Text('Unlock Console'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Unlocked Console
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console (Yahya Mundewadi)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppConstants.darkBlue,
        foregroundColor: AppConstants.pureWhite,
        onPressed: _showCreateUserDialog,
        icon: const AppSvgIcon(svg: AppSvgIcons.plus, size: 16, color: Colors.white),
        label: const Text('New User'),
      ),
      body: GradientBackdrop(
        child: _isLoadingUsers
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Team Directory & Access Control',
                        style: TextStyle(
                          color: AppConstants.textBlack,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_users.length} accounts',
                        style: const TextStyle(
                          color: AppConstants.skyBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._users.map((profile) => _buildUserCard(profile)),
                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }

  Widget _buildUserCard(CrmProfile profile) {
    final isRootAdmin = profile.mobileNumber == AppConstants.adminFixedNumber;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          color: AppConstants.textBlack,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isRootAdmin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppConstants.darkBlue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ROOT',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: profile.isDisabled
                        ? AppConstants.statusDanger.withOpacity(0.12)
                        : AppConstants.statusSuccess.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    profile.isDisabled ? 'DISABLED' : 'ACTIVE',
                    style: TextStyle(
                      color: profile.isDisabled
                          ? AppConstants.statusDanger
                          : AppConstants.statusSuccess,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '+91 ${profile.mobileNumber} • Role: ${profile.role} • Team: ${profile.team}',
              style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
            ),
            const Divider(height: 18, color: AppConstants.borderSubtle),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.lock_reset, size: 16),
                  label: const Text('Reset Pass'),
                  onPressed: () => _showResetPasswordDialog(profile),
                ),
                if (!isRootAdmin) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: Icon(
                      profile.isDisabled ? Icons.check_circle_outline : Icons.block,
                      size: 16,
                      color: profile.isDisabled ? AppConstants.statusSuccess : AppConstants.statusWarning,
                    ),
                    label: Text(profile.isDisabled ? 'Enable' : 'Disable'),
                    onPressed: () async {
                      await SupabaseService.instance.adminUpdateUser(
                        userId: profile.id,
                        isDisabled: !profile.isDisabled,
                      );
                      _fetchUsers();
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateUserDialog() {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'founder';
    String team = 'Gulbarga';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create User Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 10),
                TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number (10 digits)')),
                const SizedBox(height: 10),
                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Assigned Password')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'founder', child: Text('Founders')),
                    DropdownMenuItem(value: 'channel_partner', child: Text('Channel Partner')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: team,
                  decoration: const InputDecoration(labelText: 'Assigned Team'),
                  items: const [
                    DropdownMenuItem(value: 'Gulbarga', child: Text('Gulbarga')),
                    DropdownMenuItem(value: 'Solapur', child: Text('Solapur')),
                    DropdownMenuItem(value: 'Both', child: Text('Both')),
                  ],
                  onChanged: (v) => setDialogState(() => team = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || mobileCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await SupabaseService.instance.adminCreateUser(
                  mobile: mobileCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  role: role,
                  team: team,
                );
                _fetchUsers();
              },
              child: const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(CrmProfile profile) {
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password: ${profile.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        content: TextField(
          controller: passCtrl,
          decoration: const InputDecoration(labelText: 'New Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (passCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await SupabaseService.instance.adminUpdateUser(
                userId: profile.id,
                newPassword: passCtrl.text.trim(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated successfully!'), backgroundColor: AppConstants.statusSuccess),
                );
              }
            },
            child: const Text('Save Password'),
          ),
        ],
      ),
    );
  }
}
