import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/svg_icons.dart';
import '../../core/theme.dart';
import '../../models/crm_record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crm_provider.dart';
import '../../services/notification_service.dart';

class HomeScreen extends ConsumerWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  void _showRemindDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    String target = 'all';
    DateTime selectedTime = DateTime.now().add(const Duration(hours: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create Remind Alert',
                    style: TextStyle(
                      color: AppConstants.textBlack,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Title',
                  hintText: 'e.g. Follow-up with ABC School',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes / Context',
                  hintText: 'Enter details...',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Target Audience',
                style: TextStyle(
                  color: AppConstants.textBlack,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'Gulbarga', label: Text('Gulbarga')),
                  ButtonSegment(value: 'Solapur', label: Text('Solapur')),
                ],
                selected: {target},
                onSelectionChanged: (val) => setModalState(() => target = val.first),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) return;
                  Navigator.pop(ctx);

                  final newRecord = CrmRecord(
                    id: '',
                    entityType: 'notice',
                    title: '[REMINDER] ${titleController.text.trim()}',
                    description: noteController.text.trim(),
                    team: target == 'all' ? 'Both' : target,
                    status: 'active',
                    priority: 'high',
                    dueDate: selectedTime,
                    extraData: {
                      'is_reminder': true,
                      'reminder_time': selectedTime.toIso8601String(),
                    },
                  );

                  await ref.read(crmProvider.notifier).addRecord(newRecord);
                  
                  // Trigger immediate heads-up popup on device with sound
                  await NotificationService.instance.showHeadsUpNotification(
                    title: '[REMINDER] ${titleController.text.trim()}',
                    body: noteController.text.trim().isNotEmpty
                        ? noteController.text.trim()
                        : 'Reminder scheduled for ${DateFormat('hh:mm a').format(selectedTime)}',
                    type: 'reminders',
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reminder broadcasted to devices!'),
                        backgroundColor: AppConstants.statusSuccess,
                      ),
                    );
                  }
                },
                child: const Text('Broadcast Reminder'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final followups = ref.watch(clientFollowupsProvider);
    final meetings = ref.watch(meetingsProvider);
    final collections = ref.watch(collectionsProvider);
    final activityLogs = ref.watch(activityLogsProvider);
    final userProfile = ref.watch(authProvider).profile;

    // Filter calculations
    final pendingTasks = tasks.where((t) => t.status != 'done' && t.status != 'completed').length;
    final pendingFollowups = followups.where((f) => f.status != 'done').length;
    final upcomingMeetings = meetings.length;
    final totalCollectionsDue = collections.fold<double>(
        0.0, (sum, c) => sum + (c.amountDue - c.amountReceived));

    return GradientBackdrop(
      child: RefreshIndicator(
        onRefresh: () => ref.read(crmProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userProfile?.name != null ? 'Hello, ${userProfile!.name}' : 'Welcome Back',
                      style: const TextStyle(
                        color: AppConstants.textBlack,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${userProfile?.role.replaceAll('_', ' ').toUpperCase() ?? "FOUNDER"} • ${userProfile?.team ?? "ALL TEAMS"}',
                      style: const TextStyle(
                        color: AppConstants.skyBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                // Remind Button
                ElevatedButton.icon(
                  onPressed: () => _showRemindDialog(context, ref),
                  icon: const AppSvgIcon(
                    svg: AppSvgIcons.bellRing,
                    size: 16,
                    color: AppConstants.pureWhite,
                  ),
                  label: const Text('Remind'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.darkBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4 Executive Metrics Cards Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _buildMetricCard(
                  title: "Today's Tasks",
                  value: '$pendingTasks',
                  subtitle: 'Pending action',
                  svgIcon: AppSvgIcons.tasks,
                  accentColor: AppConstants.skyBlue,
                  onTap: () => onNavigateTab?.call(0),
                ),
                _buildMetricCard(
                  title: 'Pending Follow-ups',
                  value: '$pendingFollowups',
                  subtitle: 'Client pipeline',
                  svgIcon: AppSvgIcons.clock,
                  accentColor: AppConstants.statusWarning,
                  onTap: () => onNavigateTab?.call(1),
                ),
                _buildMetricCard(
                  title: 'Upcoming Meetings',
                  value: '$upcomingMeetings',
                  subtitle: 'Scheduled syncs',
                  svgIcon: AppSvgIcons.calendar,
                  accentColor: AppConstants.accentCyan,
                  onTap: () => onNavigateTab?.call(1),
                ),
                _buildMetricCard(
                  title: 'Collections Due',
                  value: '₹${NumberFormat('#,##,###').format(totalCollectionsDue)}',
                  subtitle: '${collections.length} invoices',
                  svgIcon: AppSvgIcons.money,
                  accentColor: AppConstants.statusSuccess,
                  onTap: () => onNavigateTab?.call(1),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section: Today's Tasks
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Critical Tasks',
                  style: TextStyle(
                    color: AppConstants.textBlack,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () => _showAddTaskDialog(context, ref),
                  child: const Text('+ Add Task', style: TextStyle(color: AppConstants.darkBlue)),
                ),
              ],
            ),
            if (tasks.isEmpty)
              _buildEmptyState('No pending tasks for your team')
            else
              ...tasks.take(4).map((task) => _buildTaskItem(context, ref, task)),

            const SizedBox(height: 20),

            // Section: Recent Activity Feed
            const Text(
              'Live Activity Feed',
              style: TextStyle(
                color: AppConstants.textBlack,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (activityLogs.isEmpty)
              _buildEmptyState('No recent activity recorded yet')
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activityLogs.take(6).length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppConstants.borderSubtle),
                  itemBuilder: (context, index) {
                    final log = activityLogs[index];
                    final dateStr = log.createdAt != null
                        ? DateFormat('hh:mm a, dd MMM').format(log.createdAt!.toLocal())
                        : 'Just now';
                    return ListTile(
                      dense: true,
                      leading: const CircleAvatar(
                        radius: 14,
                        backgroundColor: AppConstants.backgroundLight,
                        child: AppSvgIcon(
                          svg: AppSvgIcons.notice,
                          size: 14,
                          color: AppConstants.darkBlue,
                        ),
                      ),
                      title: Text(
                        log.title,
                        style: const TextStyle(
                          color: AppConstants.textBlack,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${log.description ?? ""} • $dateStr',
                        style: const TextStyle(
                          color: AppConstants.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required String svgIcon,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: AppSvgIcon(svg: svgIcon, size: 16, color: accentColor),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: AppConstants.textMuted),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppConstants.textBlack,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, WidgetRef ref, CrmRecord task) {
    final isDone = task.status == 'done' || task.status == 'completed';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Checkbox(
          value: isDone,
          activeColor: AppConstants.darkBlue,
          onChanged: (val) {
            final updated = task.copyWith(status: val == true ? 'done' : 'pending');
            ref.read(crmProvider.notifier).updateRecord(updated);
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            color: AppConstants.textBlack,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          'Priority: ${task.priority.toUpperCase()} • Team: ${task.team}',
          style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: AppConstants.textMuted),
          onPressed: () => ref.read(crmProvider.notifier).deleteRecord(task.id),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.borderSubtle),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'normal';
    String team = 'Gulbarga';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Team Task', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (v) => setDialogState(() => priority = v!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: team,
                  decoration: const InputDecoration(labelText: 'Team'),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final task = CrmRecord(
                  id: '',
                  entityType: 'task',
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  priority: priority,
                  team: team,
                  status: 'pending',
                );
                ref.read(crmProvider.notifier).addRecord(task);
              },
              child: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }
}

