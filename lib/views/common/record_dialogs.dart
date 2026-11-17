import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/crm_record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crm_provider.dart';

const List<String> kFounderNames = [
  'Yahya Mundewadi (Admin Founder)',
  'Founder 2',
  'Founder 3',
  'Founder 4',
  'Other (Enter Manually)',
];

const List<String> kRecordStatuses = [
  'pending',
  'work started',
  'done',
  'completed',
];

Color getStatusColor(String status) {
  final s = status.toLowerCase().trim();
  switch (s) {
    case 'work started':
    case 'work_started':
    case 'in_progress':
      return AppConstants.skyBlue;
    case 'done':
    case 'completed':
      return AppConstants.statusSuccess;
    case 'urgent':
      return AppConstants.statusDanger;
    case 'pending':
    default:
      return AppConstants.statusWarning;
  }
}

String formatStatus(String status) {
  final s = status.toLowerCase().trim();
  if (s == 'work_started' || s == 'work started') return 'Work Started';
  if (s == 'done') return 'Done';
  if (s == 'completed') return 'Completed';
  return 'Pending';
}

class StatusBadge extends StatelessWidget {
  final String status;
  final String? changedBy;
  final VoidCallback? onTap;

  const StatusBadge({
    super.key,
    required this.status,
    this.changedBy,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = getStatusColor(status);
    final label = formatStatus(status);

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (changedBy != null && changedBy!.trim().isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(
              '• by ${changedBy!.trim()}',
              style: const TextStyle(
                color: AppConstants.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: badge,
      );
    }
    return badge;
  }
}

class RecordDetailDialog extends ConsumerStatefulWidget {
  final CrmRecord record;
  const RecordDetailDialog({super.key, required this.record});

  @override
  ConsumerState<RecordDetailDialog> createState() => _RecordDetailDialogState();
}

class _RecordDetailDialogState extends ConsumerState<RecordDetailDialog> {
  late CrmRecord _record;
  late String _currentStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _currentStatus = _record.status.toLowerCase().trim();
    if (!kRecordStatuses.contains(_currentStatus)) {
      _currentStatus = 'pending';
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    final currentUser = ref.read(authProvider).profile;
    final changerName = (currentUser != null && currentUser.name.trim().isNotEmpty)
        ? currentUser.name.trim()
        : 'Yahya Mundewadi';

    final extra = Map<String, dynamic>.from(_record.extraData);
    extra['status_changed_by'] = changerName;
    extra['status_changed_at'] = DateTime.now().toIso8601String();

    final updated = _record.copyWith(
      status: newStatus,
      extraData: extra,
    );

    await ref.read(crmProvider.notifier).updateRecord(updated);

    if (mounted) {
      setState(() {
        _record = updated;
        _currentStatus = newStatus;
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to "${formatStatus(newStatus)}" by $changerName'),
          backgroundColor: AppConstants.statusSuccess,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showQuickAssignDialog(BuildContext context) {
    String selected = kFounderNames.first;
    final currentAssigned = _record.assignedPerson?.trim();
    final manualCtrl = TextEditingController();

    if (currentAssigned != null && currentAssigned.isNotEmpty) {
      if (kFounderNames.contains(currentAssigned)) {
        selected = currentAssigned;
      } else {
        selected = 'Other (Enter Manually)';
        manualCtrl.text = currentAssigned;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setQuickState) => AlertDialog(
          title: const Text('Assign Person', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose founder or type manual name:', style: TextStyle(fontSize: 12, color: AppConstants.textMuted)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selected,
                decoration: const InputDecoration(labelText: 'Assigned Person'),
                items: kFounderNames.map((n) => DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setQuickState(() => selected = v!),
              ),
              if (selected == 'Other (Enter Manually)') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: manualCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Type Assignee Name *',
                    hintText: 'Enter name',
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.darkBlue),
              onPressed: () async {
                final chosen = selected == 'Other (Enter Manually)'
                    ? manualCtrl.text.trim()
                    : selected;
                if (chosen.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an assignee name')),
                  );
                  return;
                }
                Navigator.pop(ctx);

                final messenger = ScaffoldMessenger.of(context);
                final currentUser = ref.read(authProvider).profile;
                final changerName = (currentUser != null && currentUser.name.trim().isNotEmpty)
                    ? currentUser.name.trim()
                    : 'Yahya Mundewadi';

                final extra = Map<String, dynamic>.from(_record.extraData);
                extra['assigned_to'] = chosen;
                extra['status_changed_by'] = changerName;
                extra['status_changed_at'] = DateTime.now().toIso8601String();

                final updated = _record.copyWith(
                  assignedTo: chosen,
                  extraData: extra,
                );

                await ref.read(crmProvider.notifier).updateRecord(updated);

                if (mounted) {
                  setState(() => _record = updated);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Assigned to $chosen successfully'),
                      backgroundColor: AppConstants.statusSuccess,
                    ),
                  );
                }
              },
              child: const Text('Save Assignment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    final assigned = r.assignedPerson ?? 'Unassigned (Tap to assign)';
    final changedBy = r.statusChangedBy;
    final changedAt = r.statusChangedAt != null
        ? DateFormat('dd MMM, hh:mm a').format(DateTime.tryParse(r.statusChangedAt!)?.toLocal() ?? DateTime.now())
        : null;
    final dateStr = r.dueDate != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(r.dueDate!.toLocal())
        : 'Not specified';

    final isDeadlineOverdue = r.dueDate != null &&
        r.dueDate!.isBefore(DateTime.now()) &&
        _currentStatus != 'done' &&
        _currentStatus != 'completed';

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppConstants.textBlack,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${r.entityType.toUpperCase()} • Team: ${r.team}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppConstants.skyBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: AppConstants.borderSubtle),
            const SizedBox(height: 8),

            // Force Status Change Section
            const Text(
              'Change Status:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppConstants.textBlack,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppConstants.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppConstants.borderSubtle),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currentStatus,
                  isExpanded: true,
                  items: kRecordStatuses.map((st) {
                    final color = getStatusColor(st);
                    return DropdownMenuItem(
                      value: st,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatStatus(st),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newVal) {
                    if (newVal != null && newVal != _currentStatus) {
                      _updateStatus(newVal);
                    }
                  },
                ),
              ),
            ),

            if (changedBy != null && changedBy.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_pin_outlined, size: 14, color: AppConstants.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Last changed by $changedBy${changedAt != null ? " ($changedAt)" : ""}',
                      style: const TextStyle(fontSize: 11, color: AppConstants.textMuted),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),
            const Divider(color: AppConstants.borderSubtle),
            const SizedBox(height: 8),

            // Assigned Person (Directly clickable to assign or change)
            InkWell(
              onTap: () => _showQuickAssignDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppConstants.skyBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppConstants.skyBlue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle, size: 20, color: AppConstants.skyBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ASSIGNED PERSON (TAP TO CHANGE)',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppConstants.skyBlue,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            assigned,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppConstants.textBlack,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined, size: 16, color: AppConstants.skyBlue),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Deadline / Due Date
            _buildInfoRow(
              Icons.event_outlined,
              'Deadline / Due Date',
              dateStr,
              trailing: isDeadlineOverdue
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppConstants.statusDanger.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'OVERDUE',
                        style: TextStyle(
                          color: AppConstants.statusDanger,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 10),

            // Description / Notes
            if (r.description != null && r.description!.trim().isNotEmpty) ...[
              _buildInfoRow(
                Icons.notes_outlined,
                'Description & Notes',
                r.description!.trim(),
              ),
              const SizedBox(height: 10),
            ],

            // Priority
            _buildInfoRow(
              Icons.flag_outlined,
              'Priority',
              r.priority.toUpperCase(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.delete_outline, size: 16, color: AppConstants.statusDanger),
          label: const Text('Delete', style: TextStyle(color: AppConstants.statusDanger)),
          onPressed: () {
            Navigator.pop(context);
            ref.read(crmProvider.notifier).deleteRecord(r.id);
          },
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.skyBlue),
          icon: const Icon(Icons.edit, size: 16, color: Colors.white),
          label: const Text('Edit Details', style: TextStyle(color: Colors.white)),
          onPressed: () {
            Navigator.pop(context);
            showEditRecordDialog(context, ref, r);
          },
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.darkBlue),
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppConstants.skyBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppConstants.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppConstants.textBlack,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}

void showRecordDetail(BuildContext context, CrmRecord record) {
  showDialog(
    context: context,
    builder: (_) => RecordDetailDialog(record: record),
  );
}

void showEditRecordDialog(BuildContext context, WidgetRef ref, CrmRecord record) {
  final titleCtrl = TextEditingController(text: record.title);
  final descCtrl = TextEditingController(text: record.description ?? '');
  final clientCtrl = TextEditingController(text: record.clientName ?? '');
  final manualAssignedCtrl = TextEditingController();

  String selectedFounder = kFounderNames.first;
  final currentAssigned = record.assignedPerson?.trim();
  if (currentAssigned != null && currentAssigned.isNotEmpty) {
    if (kFounderNames.contains(currentAssigned)) {
      selectedFounder = currentAssigned;
    } else {
      selectedFounder = 'Other (Enter Manually)';
      manualAssignedCtrl.text = currentAssigned;
    }
  }

  String status = record.status.toLowerCase().trim();
  if (!kRecordStatuses.contains(status)) status = 'pending';

  String priority = record.priority.toLowerCase().trim();
  if (!['low', 'normal', 'high', 'urgent'].contains(priority)) priority = 'normal';

  String team = record.team;
  if (!['Gulbarga', 'Solapur', 'Both'].contains(team)) team = 'Gulbarga';

  DateTime? deadline = record.dueDate;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text('Edit ${record.entityType.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              const SizedBox(height: 10),
              if (record.entityType != 'task') ...[
                TextField(
                  controller: clientCtrl,
                  decoration: const InputDecoration(labelText: 'Client / School / Agency Name'),
                ),
                const SizedBox(height: 10),
              ],
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

              // Status Dropdown
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

              // Deadline / Date Picker Button
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final pickedDate = await showDatePicker(
                    context: ctx,
                    initialDate: deadline ?? now.add(const Duration(days: 1)),
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 730)),
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
                              : 'Set Deadline Date & Time',
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
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a title')),
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
              final changerName = (currentUser != null && currentUser.name.trim().isNotEmpty)
                  ? currentUser.name.trim()
                  : 'Yahya Mundewadi';

              final extra = Map<String, dynamic>.from(record.extraData);
              extra['assigned_to'] = assignedName;
              extra['status_changed_by'] = changerName;
              extra['status_changed_at'] = DateTime.now().toIso8601String();
              if (deadline != null) {
                extra['deadline'] = deadline!.toIso8601String();
              } else {
                extra.remove('deadline');
              }

              Navigator.pop(ctx);

              final updated = record.copyWith(
                title: titleCtrl.text.trim(),
                clientName: clientCtrl.text.trim().isNotEmpty ? clientCtrl.text.trim() : record.clientName,
                description: descCtrl.text.trim(),
                assignedTo: assignedName,
                status: status,
                priority: priority,
                team: team,
                dueDate: deadline,
                extraData: extra,
              );

              await ref.read(crmProvider.notifier).updateRecord(updated);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Updated successfully. Assigned to $assignedName'),
                    backgroundColor: AppConstants.statusSuccess,
                  ),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    ),
  );
}

