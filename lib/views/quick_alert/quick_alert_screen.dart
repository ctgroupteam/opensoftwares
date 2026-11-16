import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/svg_icons.dart';
import '../../core/theme.dart';
import '../../models/crm_record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crm_provider.dart';
import '../../services/supabase_service.dart';

class QuickAlertScreen extends ConsumerStatefulWidget {
  const QuickAlertScreen({super.key});

  @override
  ConsumerState<QuickAlertScreen> createState() => _QuickAlertScreenState();
}

class _QuickAlertScreenState extends ConsumerState<QuickAlertScreen> {
  final _messageController = TextEditingController();
  String _selectedAudience = 'all'; // 'all', 'Gulbarga', 'Solapur'
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendQuickAlert() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    setState(() => _isSending = true);
    final user = ref.read(authProvider).profile;

    final alertRecord = CrmRecord(
      id: '',
      entityType: 'quick_alert',
      title: msg,
      description: 'Urgent alarm alert sent by ${user?.name ?? "Founder"}',
      team: _selectedAudience == 'all' ? 'Both' : _selectedAudience,
      status: 'active',
      priority: 'urgent',
      extraData: {
        'require_ack': true,
        'sender_name': user?.name ?? 'Founder',
        'sender_id': user?.id,
        'acknowledged_by': [],
      },
    );

    try {
      await ref.read(crmProvider.notifier).addRecord(alertRecord);
      _messageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insistent Quick Alert dispatched with repeating alarm!'),
            backgroundColor: AppConstants.statusSuccess,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(quickAlertsProvider);
    final currentUser = ref.watch(authProvider).profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Alert Broadcaster'),
      ),
      body: GradientBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Compose Alert Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppConstants.statusDanger.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const AppSvgIcon(
                            svg: AppSvgIcons.alert,
                            size: 18,
                            color: AppConstants.statusDanger,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instant High-Priority Alarm',
                                style: TextStyle(
                                  color: AppConstants.textBlack,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Repeats continuously on recipients\' devices until seen',
                                style: TextStyle(
                                  color: AppConstants.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _messageController,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'Short Urgent Message (4-5 words)',
                        hintText: 'e.g. Emergency sync in 10 minutes',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Select Recipients',
                      style: TextStyle(
                        color: AppConstants.textBlack,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All Teams')),
                        ButtonSegment(value: 'Gulbarga', label: Text('Gulbarga')),
                        ButtonSegment(value: 'Solapur', label: Text('Solapur')),
                      ],
                      selected: {_selectedAudience},
                      onSelectionChanged: (val) =>
                          setState(() => _selectedAudience = val.first),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.darkBlue,
                      ),
                      onPressed: _isSending ? null : _sendQuickAlert,
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const AppSvgIcon(
                              svg: AppSvgIcons.send,
                              size: 16,
                              color: Colors.white,
                            ),
                      label: Text(_isSending ? 'Broadcasting...' : 'Broadcast Alarm Alert'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Live Alert Tracker
            const Text(
              'Active & Recent Quick Alerts',
              style: TextStyle(
                color: AppConstants.textBlack,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (alerts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No active quick alerts broadcasted',
                    style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
                  ),
                ),
              )
            else
              ...alerts.map((al) => _buildAlertCard(al, currentUser?.id)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(CrmRecord alert, String? currentUserId) {
    final acks = alert.acknowledgedBy;
    final timeStr = alert.createdAt != null
        ? DateFormat('hh:mm a, dd MMM').format(alert.createdAt!.toLocal())
        : 'Just now';

    final hasUserAcked = acks.any((a) => a['user_id'] == currentUserId);

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
                  child: Text(
                    alert.title,
                    style: const TextStyle(
                      color: AppConstants.textBlack,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppConstants.statusDanger.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    alert.team.toUpperCase(),
                    style: const TextStyle(
                      color: AppConstants.statusDanger,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${alert.description ?? ""} • $timeStr',
              style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
            ),
            const Divider(height: 16, color: AppConstants.borderSubtle),

            // Acknowledgment Action for current user
            if (!hasUserAcked) ...[
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.statusSuccess,
                      side: const BorderSide(color: AppConstants.statusSuccess),
                    ),
                    onPressed: () {
                      SupabaseService.instance.acknowledgeAlert(alert.id, 'Seen');
                    },
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Mark Seen'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      SupabaseService.instance.acknowledgeAlert(alert.id, 'Snoozed');
                    },
                    icon: const Icon(Icons.snooze, size: 14),
                    label: const Text('Snooze'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Real-time acknowledgment roster
            Text(
              'Acknowledged by (${acks.length}):',
              style: const TextStyle(
                color: AppConstants.textBlack,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            if (acks.isEmpty)
              const Text(
                'Waiting for recipients to acknowledge...',
                style: TextStyle(color: AppConstants.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: acks.map((ack) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppConstants.statusSuccess.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${ack['name'] ?? "User"} (${ack['action'] ?? "Seen"})',
                      style: const TextStyle(
                        color: AppConstants.statusSuccess,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

