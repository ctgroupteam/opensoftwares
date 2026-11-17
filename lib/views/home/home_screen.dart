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
import '../common/record_dialogs.dart';

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
    final appConfig = ref.watch(dynamicAppConfigProvider);

    // Dynamic Server-Driven Values from Supabase
    final statusText = appConfig['system_status_text']?.toString() ?? 'Enterprise Live Sync Active';
    final announcement = appConfig['announcement_banner']?.toString() ?? '';
    final showAnnouncement = appConfig['show_announcement'] == true;

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
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppConstants.statusSuccess,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: AppConstants.statusSuccess,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
            if (showAnnouncement && announcement.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppConstants.skyBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppConstants.skyBlue.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign_outlined, size: 18, color: AppConstants.darkBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        announcement,
                        style: const TextStyle(
                          color: AppConstants.textBlack,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    final assigned = task.assignedPerson ?? 'Team';
    final changedBy = task.statusChangedBy;
    final dueDateStr = task.dueDate != null
        ? DateFormat('dd MMM, hh:mm a').format(task.dueDate!.toLocal())
        : null;
    final isOverdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !isDone;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => showRecordDetail(context, task),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: isDone,
                    activeColor: AppConstants.darkBlue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: (val) {
                      final currentUser = ref.read(authProvider).profile;
                      final changerName = (currentUser != null && currentUser.name.trim().isNotEmpty)
                          ? currentUser.name.trim()
                          : 'Yahya Mundewadi';
                      final extra = Map<String, dynamic>.from(task.extraData);
                      extra['status_changed_by'] = changerName;
                      extra['status_changed_at'] = DateTime.now().toIso8601String();
                      final updated = task.copyWith(
                        status: val == true ? 'done' : 'pending',
                        extraData: extra,
                      );
                      ref.read(crmProvider.notifier).updateRecord(updated);
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: AppConstants.textBlack,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (task.description != null && task.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            task.description!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 18, color: AppConstants.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => showRecordDetail(context, task),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  StatusBadge(
                    status: task.status,
                    changedBy: changedBy,
                    onTap: () => showRecordDetail(context, task),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppConstants.skyBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Assigned: $assigned',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.darkBlue,
                      ),
                    ),
                  ),
                ],
              ),
              if (dueDateStr != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 13,
                      color: isOverdue ? AppConstants.statusDanger : AppConstants.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Deadline: $dueDateStr',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
                        color: isOverdue ? AppConstants.statusDanger : AppConstants.textMuted,
                      ),
                    ),
                    if (isOverdue) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppConstants.statusDanger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'OVERDUE',
                          style: TextStyle(
                            color: AppConstants.statusDanger,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
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
    final manualAssignedCtrl = TextEditingController();
    String priority = 'normal';
    String team = 'Gulbarga';
    String status = 'pending';
    String selectedFounder = kFounderNames.first;
    DateTime? deadline;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Team Task', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Task Title *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description / Notes'),
                ),
                const SizedBox(height: 12),

                // Assigned Person Dropdown
                DropdownButtonFormField<String>(
                  value: selectedFounder,
                  decoration: const InputDecoration(labelText: 'Assigned Person'),
                  items: kFounderNames.map((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setDialogState(() => selectedFounder = v!),
                ),
                if (selectedFounder == 'Other (Enter Manually)') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: manualAssignedCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Type Assignee Name *',
                      hintText: 'Enter name',
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Initial Status
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: kRecordStatuses.map((st) {
                    final color = getStatusColor(st);
                    return DropdownMenuItem(
                      value: st,
                      child: Text(formatStatus(st), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                    );
                  }).toList(),
                  onChanged: (v) => setDialogState(() => status = v!),
                ),
                const SizedBox(height: 10),

                // Deadline Picker Button
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final pickedDate = await showDatePicker(
                      context: ctx,
                      initialDate: deadline ?? now.add(const Duration(days: 1)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (pickedDate != null && ctx.mounted) {
                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(deadline ?? now.add(const Duration(hours: 4))),
                      );
                      if (pickedTime != null) {
                        setDialogState(() {
                          deadline = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppConstants.borderSubtle),
                      borderRadius: BorderRadius.circular(8),
                      color: AppConstants.backgroundLight,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 18, color: AppConstants.skyBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            deadline != null
                                ? 'Deadline: ${DateFormat("dd MMM yyyy, hh:mm a").format(deadline!)}'
                                : 'Choose Deadline Date & Time',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: deadline != null ? FontWeight.w700 : FontWeight.w500,
                              color: deadline != null ? AppConstants.textBlack : AppConstants.textMuted,
                            ),
                          ),
                        ),
                        if (deadline != null)
                          GestureDetector(
                            onTap: () => setDialogState(() => deadline = null),
                            child: const Icon(Icons.clear, size: 16, color: AppConstants.textMuted),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Priority & Team
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
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
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: team,
                        decoration: const InputDecoration(labelText: 'Team'),
                        items: const [
                          DropdownMenuItem(value: 'Gulbarga', child: Text('Gulbarga')),
                          DropdownMenuItem(value: 'Solapur', child: Text('Solapur')),
                          DropdownMenuItem(value: 'Both', child: Text('Both')),
                        ],
                        onChanged: (v) => setDialogState(() => team = v!),
                      ),
                    ),
                  ],
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
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.darkBlue),
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter task title')),
                  );
                  return;
                }
                final assignedName = selectedFounder == 'Other (Enter Manually)'
                    ? manualAssignedCtrl.text.trim()
                    : selectedFounder;

                if (selectedFounder == 'Other (Enter Manually)' && assignedName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter the assignee name')),
                  );
                  return;
                }

                final currentUser = ref.read(authProvider).profile;
                final creatorName = (currentUser != null && currentUser.name.trim().isNotEmpty)
                    ? currentUser.name.trim()
                    : 'Yahya Mundewadi';

                Navigator.pop(ctx);
                final task = CrmRecord(
                  id: '',
                  entityType: 'task',
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  priority: priority,
                  team: team,
                  status: status,
                  assignedTo: assignedName,
                  dueDate: deadline,
                  extraData: {
                    'assigned_to': assignedName,
                    'status_changed_by': creatorName,
                    'status_changed_at': DateTime.now().toIso8601String(),
                    if (deadline != null) 'deadline': deadline!.toIso8601String(),
                  },
                );
                ref.read(crmProvider.notifier).addRecord(task);

                // Show confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Task added and assigned to $assignedName'),
                    backgroundColor: AppConstants.statusSuccess,
                  ),
                );
              },
              child: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }
}

