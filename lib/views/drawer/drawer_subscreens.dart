import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/svg_icons.dart';
import '../../core/theme.dart';
import '../../models/crm_profile.dart';
import '../../models/crm_record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crm_provider.dart';
import '../../services/supabase_service.dart';

// -------------------------------------------------------------
// 1. TEAM UPDATES & CHAT
// -------------------------------------------------------------
class TeamUpdatesScreen extends ConsumerStatefulWidget {
  const TeamUpdatesScreen({super.key});

  @override
  ConsumerState<TeamUpdatesScreen> createState() => _TeamUpdatesScreenState();
}

class _TeamUpdatesScreenState extends ConsumerState<TeamUpdatesScreen> {
  final _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _postUpdate() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(authProvider).profile;

    final rec = CrmRecord(
      id: '',
      entityType: 'notice',
      title: 'Update from ${user?.name ?? "Founder"}',
      description: text,
      team: 'Both',
      extraData: {'is_chat': true, 'author_name': user?.name ?? "Founder"},
    );
    ref.read(crmProvider.notifier).addRecord(rec);
    _msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final notices = ref.watch(noticesProvider);
    final updates = notices.where((n) => n.extraData['is_chat'] == true).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Team Updates & Live Chat')),
      body: GradientBackdrop(
        child: Column(
          children: [
            Expanded(
              child: updates.isEmpty
                  ? const Center(child: Text('No team messages yet', style: TextStyle(color: AppConstants.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: updates.length,
                      itemBuilder: (ctx, i) {
                        final u = updates[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      u.extraData['author_name'] ?? 'Founder',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    Text(
                                      u.createdAt != null
                                          ? DateFormat('hh:mm a').format(u.createdAt!.toLocal())
                                          : '',
                                      style: const TextStyle(color: AppConstants.textMuted, fontSize: 10),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(u.description ?? '', style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: AppConstants.pureWhite,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Share update with founders...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppConstants.darkBlue),
                    icon: const AppSvgIcon(svg: AppSvgIcons.send, size: 16, color: Colors.white),
                    onPressed: _postUpdate,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. MEETINGS SCREEN (With Auto-Reminders)
// -------------------------------------------------------------
class MeetingsScreen extends ConsumerWidget {
  const MeetingsScreen({super.key});

  void _showAddMeetingDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    DateTime meetingTime = DateTime.now().add(const Duration(hours: 2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule Meeting', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Meeting Title')),
            const SizedBox(height: 10),
            TextField(controller: linkCtrl, decoration: const InputDecoration(labelText: 'Google Meet / Location Link')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final m = CrmRecord(
                id: '',
                entityType: 'meeting',
                title: titleCtrl.text.trim(),
                description: linkCtrl.text.trim(),
                meetingTime: meetingTime,
                extraData: {
                  'auto_reminders': ['1_day_before', '1_hour_before', '15_min_before'],
                  'location': linkCtrl.text.trim(),
                },
              );
              ref.read(crmProvider.notifier).addRecord(m);
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetings = ref.watch(meetingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Meetings')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppConstants.darkBlue,
        foregroundColor: AppConstants.pureWhite,
        onPressed: () => _showAddMeetingDialog(context, ref),
        icon: const AppSvgIcon(svg: AppSvgIcons.plus, size: 16, color: Colors.white),
        label: const Text('Schedule'),
      ),
      body: GradientBackdrop(
        child: meetings.isEmpty
            ? const Center(child: Text('No scheduled meetings', style: TextStyle(color: AppConstants.textMuted)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: meetings.length,
                itemBuilder: (ctx, i) {
                  final m = meetings[i];
                  final timeStr = m.meetingTime != null
                      ? DateFormat('dd MMM, hh:mm a').format(m.meetingTime!)
                      : 'Scheduled';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppConstants.backgroundLight,
                        child: AppSvgIcon(svg: AppSvgIcons.calendar, size: 16, color: AppConstants.darkBlue),
                      ),
                      title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text('Time: $timeStr\nLink: ${m.description ?? "Physical"}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppConstants.textMuted),
                        onPressed: () => ref.read(crmProvider.notifier).deleteRecord(m.id),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. COLLECTIONS LEDGER SCREEN
// -------------------------------------------------------------
class CollectionsLedgerScreen extends ConsumerWidget {
  const CollectionsLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    final totalDue = collections.fold<double>(0.0, (sum, c) => sum + c.amountDue);
    final totalRec = collections.fold<double>(0.0, (sum, c) => sum + c.amountReceived);
    final balance = totalDue - totalRec;

    return Scaffold(
      appBar: AppBar(title: const Text('Collections Ledger')),
      body: GradientBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Outstanding', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                        Text(
                          '₹${NumberFormat('#,##,###').format(balance)}',
                          style: const TextStyle(color: AppConstants.statusDanger, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppConstants.borderSubtle),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Invoiced: ₹${NumberFormat('#,##,###').format(totalDue)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Received: ₹${NumberFormat('#,##,###').format(totalRec)}', style: const TextStyle(color: AppConstants.statusSuccess, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...collections.map((c) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(c.clientName ?? c.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text('Due: ₹${NumberFormat('#,##,###').format(c.amountDue)} • Received: ₹${NumberFormat('#,##,###').format(c.amountReceived)}'),
                    trailing: Text(
                      '₹${NumberFormat('#,##,###').format(c.amountDue - c.amountReceived)}',
                      style: const TextStyle(color: AppConstants.statusDanger, fontWeight: FontWeight.w700),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. NOTICE BOARD SCREEN (With "Seen By" Tracking)
// -------------------------------------------------------------
class NoticeBoardScreen extends ConsumerWidget {
  const NoticeBoardScreen({super.key});

  void _showAddNoticeDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post Notice', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Notice Title')),
            const SizedBox(height: 10),
            TextField(controller: contentCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Content')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final n = CrmRecord(
                id: '',
                entityType: 'notice',
                title: titleCtrl.text.trim(),
                description: contentCtrl.text.trim(),
                team: 'Both',
                extraData: {'seen_by': []},
              );
              ref.read(crmProvider.notifier).addRecord(n);
            },
            child: const Text('Post Notice'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(noticesProvider);
    final currentUserId = ref.watch(authProvider).user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Company Notice Board')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppConstants.darkBlue,
        foregroundColor: AppConstants.pureWhite,
        onPressed: () => _showAddNoticeDialog(context, ref),
        icon: const AppSvgIcon(svg: AppSvgIcons.plus, size: 16, color: Colors.white),
        label: const Text('Post Notice'),
      ),
      body: GradientBackdrop(
        child: notices.isEmpty
            ? const Center(child: Text('No notices posted', style: TextStyle(color: AppConstants.textMuted)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notices.length,
                itemBuilder: (ctx, i) {
                  final n = notices[i];
                  final seenCount = n.seenBy.length;
                  final hasSeen = currentUserId != null && n.seenBy.contains(currentUserId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  n.title,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppConstants.skyBlue.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$seenCount seen',
                                  style: const TextStyle(color: AppConstants.skyBlue, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(n.description ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
                          const Divider(height: 18, color: AppConstants.borderSubtle),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                n.createdAt != null
                                    ? DateFormat('dd MMM yyyy').format(n.createdAt!)
                                    : 'Recent',
                                style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                              ),
                              if (!hasSeen)
                                TextButton(
                                  onPressed: () => SupabaseService.instance.markNoticeSeen(n.id),
                                  child: const Text('Mark as Read', style: TextStyle(fontSize: 12)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 5. EXECUTIVE REPORTS SCREEN
// -------------------------------------------------------------
class ExecutiveReportsScreen extends ConsumerWidget {
  const ExecutiveReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final leads = ref.watch(leadsProvider);
    final partners = ref.watch(channelPartnersProvider);
    final collections = ref.watch(collectionsProvider);

    final wonLeads = leads.where((l) => l.leadStage == 'Won').length;
    final totalCollectionsDue = collections.fold<double>(0.0, (sum, c) => sum + c.amountDue);

    return Scaffold(
      appBar: AppBar(title: const Text('Executive Operations Report')),
      body: GradientBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pipeline Conversion Summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 14),
                    _buildReportRow('Active Software Products', '${products.length} catalog suites'),
                    _buildReportRow('Registered Channel Partners', '${partners.length} agencies'),
                    _buildReportRow('Total Active Leads', '${leads.length} accounts'),
                    _buildReportRow('Closed Won Contracts', '$wonLeads deals'),
                    _buildReportRow('Total Revenue Invoiced', '₹${NumberFormat('#,##,###').format(totalCollectionsDue)}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppConstants.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppConstants.textBlack, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 6. DEDICATED REGIONAL TEAM OPERATIONS SCREEN (Gulbarga / Solapur)
// -------------------------------------------------------------
class TeamViewScreen extends ConsumerStatefulWidget {
  final String teamName;
  const TeamViewScreen({super.key, required this.teamName});

  @override
  ConsumerState<TeamViewScreen> createState() => _TeamViewScreenState();
}

class _TeamViewScreenState extends ConsumerState<TeamViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CrmProfile> _members = [];
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTeamMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamMembers() async {
    try {
      final allProfiles = await SupabaseService.instance.getAllProfiles();
      if (mounted) {
        setState(() {
          _members = allProfiles
              .where((p) => p.team == widget.teamName || p.team == 'Both')
              .toList();
          _isLoadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRecords = ref.watch(crmProvider).records;

    final teamLeads = allRecords
        .where((r) =>
            r.entityType == 'lead' &&
            (r.team == widget.teamName || r.team == 'Both'))
        .toList();

    final teamTasks = allRecords
        .where((r) =>
            r.entityType == 'task' &&
            (r.team == widget.teamName || r.team == 'Both'))
        .toList();

    final teamCollections = allRecords
        .where((r) =>
            r.entityType == 'collection' &&
            (r.team == widget.teamName || r.team == 'Both'))
        .toList();

    final totalInvoiced = teamCollections.fold<double>(
        0.0, (sum, c) => sum + (c.amountDue));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.teamName} Regional Operations'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConstants.darkBlue,
          unselectedLabelColor: AppConstants.textMuted,
          indicatorColor: AppConstants.skyBlue,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Staff (${_isLoadingMembers ? "..." : _members.length})'),
            Tab(text: 'Leads (${teamLeads.length})'),
            Tab(text: 'Tasks (${teamTasks.length})'),
          ],
        ),
      ),
      body: GradientBackdrop(
        child: Column(
          children: [
            // Top Regional Banner & Stats
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.pureWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppConstants.skyBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const AppSvgIcon(
                          svg: AppSvgIcons.pipeline,
                          size: 22,
                          color: AppConstants.darkBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.teamName} Territory Hub',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppConstants.textBlack,
                              ),
                            ),
                            const Text(
                              'Enterprise management and regional client pipeline',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppConstants.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildMetricTile(
                        'Staff',
                        _isLoadingMembers ? '-' : '${_members.length}',
                        AppConstants.darkBlue,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        'Pipeline',
                        '${teamLeads.length}',
                        AppConstants.skyBlue,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        'Pending Tasks',
                        '${teamTasks.length}',
                        AppConstants.statusWarning,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        'Invoiced',
                        '₹${NumberFormat.compact().format(totalInvoiced)}',
                        AppConstants.statusSuccess,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Staff Directory
                  _buildStaffTab(),

                  // Tab 2: Regional Leads
                  _buildLeadsTab(teamLeads),

                  // Tab 3: Regional Tasks
                  _buildTasksTab(teamTasks),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppConstants.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffTab() {
    if (_isLoadingMembers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_members.isEmpty) {
      return Center(
        child: Text(
          'No members assigned to ${widget.teamName} team yet',
          style: const TextStyle(color: AppConstants.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final roleLabel = member.role.replaceAll('_', ' ').toUpperCase();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppConstants.darkBlue.withOpacity(0.1),
                  child: const AppSvgIcon(
                    svg: AppSvgIcons.user,
                    size: 18,
                    color: AppConstants.darkBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              member.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppConstants.textBlack,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: member.isDisabled
                                  ? AppConstants.statusDanger.withOpacity(0.1)
                                  : AppConstants.statusSuccess.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              member.isDisabled ? 'Disabled' : 'Active',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: member.isDisabled
                                  ? AppConstants.statusDanger
                                  : AppConstants.statusSuccess,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppConstants.skyBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              roleLabel,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppConstants.darkBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            member.mobileNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppConstants.textMuted,
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
        );
      },
    );
  }

  Widget _buildLeadsTab(List<CrmRecord> leads) {
    if (leads.isEmpty) {
      return Center(
        child: Text(
          'No leads assigned to ${widget.teamName} team',
          style: const TextStyle(color: AppConstants.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: leads.length,
      itemBuilder: (context, index) {
        final lead = leads[index];
        final stage = lead.leadStage;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
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
                        lead.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.textBlack,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppConstants.darkBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stage,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.darkBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                if (lead.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    lead.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppConstants.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Value: ₹${NumberFormat('#,##,###').format((lead.extraData['deal_value'] as num?)?.toDouble() ?? lead.amountDue)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.statusSuccess,
                      ),
                    ),
                    Text(
                      lead.createdAt != null
                          ? DateFormat('dd MMM yyyy').format(lead.createdAt!.toLocal())
                          : '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppConstants.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTasksTab(List<CrmRecord> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          'No pending tasks for ${widget.teamName} team',
          style: const TextStyle(color: AppConstants.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final priority = task.priority.toUpperCase();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.textBlack,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppConstants.statusWarning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        priority,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.statusWarning,
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppConstants.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const AppSvgIcon(
                      svg: AppSvgIcons.clock,
                      size: 13,
                      color: AppConstants.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.dueDate != null
                          ? 'Due: ${DateFormat('dd MMM yyyy, hh:mm a').format(task.dueDate!.toLocal())}'
                          : 'No due date',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppConstants.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


