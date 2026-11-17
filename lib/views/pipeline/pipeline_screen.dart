import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/svg_icons.dart';
import '../../core/theme.dart';
import '../../models/crm_record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crm_provider.dart';
import '../common/record_dialogs.dart';

class PipelineScreen extends ConsumerStatefulWidget {
  const PipelineScreen({super.key});

  @override
  ConsumerState<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends ConsumerState<PipelineScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _lastSectionsLength = 0;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dynamicConfig = ref.watch(dynamicAppConfigProvider);
    final rawSections = dynamicConfig['pipeline_sections'] as List<dynamic>?;
    final List<String> sections = rawSections != null && rawSections.isNotEmpty
        ? rawSections.map((e) => e.toString()).toList()
        : ['Channel Partners', 'Follow-ups', 'Collections'];

    if (_tabController == null || _lastSectionsLength != sections.length) {
      _tabController?.dispose();
      _tabController = TabController(length: sections.length, vsync: this);
      _lastSectionsLength = sections.length;
    }

    return GradientBackdrop(
      child: Column(
        children: [
          // Segmented Scrollable Tab Bar with Add Section Action
          Container(
            color: AppConstants.pureWhite,
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppConstants.darkBlue,
                    unselectedLabelColor: AppConstants.textMuted,
                    indicatorColor: AppConstants.darkBlue,
                    indicatorWeight: 2.5,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    tabs: sections.map((s) => Tab(text: s)).toList(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20, color: AppConstants.skyBlue),
                  tooltip: 'Add Section',
                  onPressed: () => _showAddSectionDialog(context, sections),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController!,
              children: sections.map((sec) {
                if (sec == 'Channel Partners') return _buildPartnersTab();
                if (sec == 'Follow-ups') return _buildFollowupsTab();
                if (sec == 'Collections') return _buildCollectionsTab();
                return _buildCustomSectionTab(sec);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // TAB 1: CHANNEL PARTNERS & VISITS
  // ------------------------------------------------------------------
  Widget _buildPartnersTab() {
    final partners = ref.watch(channelPartnersProvider);
    final user = ref.watch(authProvider).profile;
    final canAdd = user?.canCreate('partners') ?? true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              heroTag: 'add_partner_fab',
              backgroundColor: AppConstants.darkBlue,
              foregroundColor: AppConstants.pureWhite,
              onPressed: () => _showAddPartnerDialog(context),
              icon: const AppSvgIcon(svg: AppSvgIcons.plus, size: 16, color: Colors.white),
              label: const Text('Add Partner'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(crmProvider.notifier).refresh(),
        child: partners.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  _buildEmptyView('No channel partners added yet'),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: partners.length,
                itemBuilder: (context, index) {
                  final partner = partners[index];
                  return _buildPartnerCard(partner);
                },
              ),
      ),
    );
  }

  Widget _buildPartnerCard(CrmRecord partner) {
    final visits = partner.visitSteps;
    final nextVisit = partner.nextVisitDate ?? 'No visit scheduled';

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
                    partner.title,
                    style: const TextStyle(
                      color: AppConstants.textBlack,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: AppConstants.textMuted),
                  onSelected: (val) {
                    if (val == 'delete') {
                      ref.read(crmProvider.notifier).deleteRecord(partner.id);
                    } else if (val == 'log_visit') {
                      _showLogVisitDialog(context, partner);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'log_visit', child: Text('Log Visit / Step')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Partner')),
                  ],
                ),
              ],
            ),
            if (partner.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                partner.description!,
                style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
              ),
            ],
            const Divider(height: 18, color: AppConstants.borderSubtle),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Visits Logged: ${visits.length}',
                  style: const TextStyle(
                    color: AppConstants.textBlack,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Next Visit: $nextVisit',
                  style: const TextStyle(
                    color: AppConstants.skyBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (visits.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: visits
                    .take(3)
                    .map((step) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppConstants.backgroundLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppConstants.borderSubtle),
                          ),
                          child: Text(
                            step,
                            style: const TextStyle(
                              color: AppConstants.textBlack,
                              fontSize: 11,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // TAB 2: CLIENT FOLLOW-UPS
  // ------------------------------------------------------------------
  Widget _buildFollowupsTab() {
    final followups = ref.watch(clientFollowupsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_followup_fab',
        backgroundColor: AppConstants.darkBlue,
        foregroundColor: AppConstants.pureWhite,
        onPressed: () => _showAddFollowupDialog(context),
        icon: const AppSvgIcon(svg: AppSvgIcons.plus, size: 16, color: Colors.white),
        label: const Text('Add Follow-up'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(crmProvider.notifier).refresh(),
        child: followups.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  _buildEmptyView('No client follow-ups pending'),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: followups.length,
                itemBuilder: (context, index) {
                  final item = followups[index];
                  final assigned = item.assignedPerson ?? 'Team';
                  final changedBy = item.statusChangedBy;
                  final dateStr = item.dueDate != null
                      ? DateFormat('dd MMM yyyy, hh:mm a').format(item.dueDate!.toLocal())
                      : 'Not set';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => showRecordDetail(context, item),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.clientName ?? item.title,
                                    style: const TextStyle(
                                      color: AppConstants.textBlack,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert, size: 18, color: AppConstants.textMuted),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => showRecordDetail(context, item),
                                ),
                              ],
                            ),
                            if (item.description != null && item.description!.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.description!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                StatusBadge(
                                  status: item.status,
                                  changedBy: changedBy,
                                  onTap: () => showRecordDetail(context, item),
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
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.event_outlined, size: 13, color: AppConstants.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  'Next Follow-up: $dateStr',
                                  style: const TextStyle(fontSize: 11, color: AppConstants.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // TAB 3: COLLECTIONS DUE
  // ------------------------------------------------------------------
  Widget _buildCollectionsTab() {
    final collections = ref.watch(collectionsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_collection_fab',
        backgroundColor: AppConstants.darkBlue,
        foregroundColor: AppConstants.pureWhite,
        onPressed: () => _showAddCollectionDialog(context),
        icon: const AppSvgIcon(svg: AppSvgIcons.plus, size: 16, color: Colors.white),
        label: const Text('Record Invoice'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(crmProvider.notifier).refresh(),
        child: collections.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  _buildEmptyView('No invoice records tracked yet'),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: collections.length,
                itemBuilder: (context, index) {
                  final item = collections[index];
                  final balance = item.amountDue - item.amountReceived;
                  final isPaid = balance <= 0;

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
                                  item.clientName ?? item.title,
                                  style: const TextStyle(
                                    color: AppConstants.textBlack,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? AppConstants.statusSuccess.withOpacity(0.12)
                                      : AppConstants.statusWarning.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPaid ? 'PAID' : 'PENDING',
                                  style: TextStyle(
                                    color: isPaid
                                        ? AppConstants.statusSuccess
                                        : AppConstants.statusWarning,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Due: ₹${NumberFormat('#,##,###').format(item.amountDue)}',
                                style: const TextStyle(
                                  color: AppConstants.textBlack,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Received: ₹${NumberFormat('#,##,###').format(item.amountReceived)}',
                                style: const TextStyle(
                                  color: AppConstants.statusSuccess,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Balance: ₹${NumberFormat('#,##,###').format(balance)}',
                                style: const TextStyle(
                                  color: AppConstants.statusDanger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
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

  // ------------------------------------------------------------------
  // DYNAMIC CUSTOM SECTION TAB
  // ------------------------------------------------------------------
  Widget _buildCustomSectionTab(String sectionName) {
    final allRecords = ref.watch(teamFilteredRecordsProvider);
    final items = allRecords
        .where((r) =>
            r.extraData['pipeline_section'] == sectionName ||
            r.extraData['section_name'] == sectionName)
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_${sectionName.replaceAll(' ', '_')}_fab',
        backgroundColor: AppConstants.darkBlue,
        foregroundColor: AppConstants.pureWhite,
        onPressed: () => _showAddCustomSectionItemDialog(context, sectionName),
        icon: const AppSvgIcon(svg: AppSvgIcons.plus, size: 16, color: Colors.white),
        label: Text('Add to $sectionName'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(crmProvider.notifier).refresh(),
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  _buildEmptyView('No records in $sectionName yet'),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final assigned = item.assignedPerson ?? 'Team';
                  final changedBy = item.statusChangedBy;
                  final dateStr = item.dueDate != null
                      ? DateFormat('dd MMM yyyy, hh:mm a').format(item.dueDate!.toLocal())
                      : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => showRecordDetail(context, item),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      color: AppConstants.textBlack,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert, size: 18, color: AppConstants.textMuted),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => showRecordDetail(context, item),
                                ),
                              ],
                            ),
                            if (item.clientName != null && item.clientName!.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Client: ${item.clientName}',
                                style: const TextStyle(color: AppConstants.skyBlue, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                            if (item.description != null && item.description!.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.description!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                StatusBadge(
                                  status: item.status,
                                  changedBy: changedBy,
                                  onTap: () => showRecordDetail(context, item),
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
                            if (dateStr != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.event_outlined, size: 13, color: AppConstants.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Date: $dateStr',
                                    style: const TextStyle(fontSize: 11, color: AppConstants.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyView(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppSvgIcon(
              svg: AppSvgIcons.pipeline,
              size: 40,
              color: AppConstants.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              msg,
              style: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // DIALOGS
  // ------------------------------------------------------------------
  void _showAddSectionDialog(BuildContext context, List<String> currentSections) {
    final sectionNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Pipeline Section', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a new pipeline section name. It will be synced across all founder devices instantly in real-time.',
              style: TextStyle(fontSize: 12, color: AppConstants.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sectionNameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Section Name (e.g. School Demos)',
                hintText: 'Enter name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.darkBlue),
            onPressed: () async {
              final name = sectionNameCtrl.text.trim();
              if (name.isEmpty) return;
              if (currentSections.contains(name)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Section already exists')),
                );
                return;
              }
              Navigator.pop(ctx);
              final updated = [...currentSections, name];
              await ref.read(crmProvider.notifier).updateAppConfigExtraData({
                'pipeline_sections': updated,
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Section "$name" created and synced'),
                    backgroundColor: AppConstants.statusSuccess,
                  ),
                );
              }
            },
            child: const Text('Create Section'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomSectionItemDialog(BuildContext context, String sectionName) {
    final titleCtrl = TextEditingController();
    final clientCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final manualAssignedCtrl = TextEditingController();
    String selectedFounder = kFounderNames.first;
    String status = 'pending';
    String team = 'Gulbarga';
    DateTime? dueDate = DateTime.now().add(const Duration(days: 3));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add to $sectionName', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title / Item Name *')),
                const SizedBox(height: 10),
                TextField(controller: clientCtrl, decoration: const InputDecoration(labelText: 'Client / Organization')),
                const SizedBox(height: 10),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Details / Notes')),
                const SizedBox(height: 12),

                // Assigned Person
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
                    decoration: const InputDecoration(labelText: 'Enter Assignee Name *'),
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

                // Territory Team
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.darkBlue),
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                final assignedName = selectedFounder == 'Other (Enter Manually)'
                    ? manualAssignedCtrl.text.trim()
                    : selectedFounder;

                final currentUser = ref.read(authProvider).profile;
                final creatorName = (currentUser != null && currentUser.name.trim().isNotEmpty)
                    ? currentUser.name.trim()
                    : 'Yahya Mundewadi';

                Navigator.pop(ctx);
                final rec = CrmRecord(
                  id: '',
                  entityType: 'lead',
                  title: titleCtrl.text.trim(),
                  clientName: clientCtrl.text.trim(),
                  description: notesCtrl.text.trim(),
                  team: team,
                  status: status,
                  assignedTo: assignedName,
                  dueDate: dueDate,
                  extraData: {
                    'pipeline_section': sectionName,
                    'assigned_to': assignedName,
                    'status_changed_by': creatorName,
                    'status_changed_at': DateTime.now().toIso8601String(),
                  },
                );
                ref.read(crmProvider.notifier).addRecord(rec);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Item added to $sectionName'),
                    backgroundColor: AppConstants.statusSuccess,
                  ),
                );
              },
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPartnerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String team = 'Gulbarga';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Channel Partner', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Partner / Agency Name')),
              const SizedBox(height: 10),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Contact / Location Notes')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: team,
                decoration: const InputDecoration(labelText: 'Territory Team'),
                items: const [
                  DropdownMenuItem(value: 'Gulbarga', child: Text('Gulbarga')),
                  DropdownMenuItem(value: 'Solapur', child: Text('Solapur')),
                  DropdownMenuItem(value: 'Both', child: Text('Both')),
                ],
                onChanged: (v) => setDialogState(() => team = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.darkBlue),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final p = CrmRecord(
                  id: '',
                  entityType: 'partner',
                  title: nameCtrl.text.trim(),
                  description: notesCtrl.text.trim(),
                  team: team,
                  extraData: {'steps': [], 'next_visit_date': null},
                );
                ref.read(crmProvider.notifier).addRecord(p);
              },
              child: const Text('Save Partner'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogVisitDialog(BuildContext context, CrmRecord partner) {
    final stepCtrl = TextEditingController();
    final dateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log Visit: ${partner.title}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: stepCtrl, decoration: const InputDecoration(labelText: 'Step / Action Taken (e.g. Product Demo)')),
            const SizedBox(height: 10),
            TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Next Visit Date (YYYY-MM-DD)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.darkBlue),
            onPressed: () {
              if (stepCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final existingSteps = List<String>.from(partner.visitSteps);
              existingSteps.add(stepCtrl.text.trim());
              final extra = Map<String, dynamic>.from(partner.extraData);
              extra['steps'] = existingSteps;
              if (dateCtrl.text.trim().isNotEmpty) {
                extra['next_visit_date'] = dateCtrl.text.trim();
              }
              final updated = partner.copyWith(extraData: extra);
              ref.read(crmProvider.notifier).updateRecord(updated);
            },
            child: const Text('Log Step'),
          ),
        ],
      ),
    );
  }

  void _showAddFollowupDialog(BuildContext context) {
    final clientCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final manualAssignedCtrl = TextEditingController();
    String selectedFounder = kFounderNames.first;
    String status = 'pending';
    DateTime? dueDate = DateTime.now().add(const Duration(days: 2));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Client Follow-up', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: clientCtrl, decoration: const InputDecoration(labelText: 'Client / School Name *')),
                const SizedBox(height: 10),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Follow-up Notes')),
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
                    decoration: const InputDecoration(labelText: 'Enter Assignee Name *'),
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

                // Due Date Picker Button
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final pickedDate = await showDatePicker(
                      context: ctx,
                      initialDate: dueDate ?? now.add(const Duration(days: 1)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (pickedDate != null && ctx.mounted) {
                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(dueDate ?? now.add(const Duration(hours: 4))),
                      );
                      if (pickedTime != null) {
                        setDialogState(() {
                          dueDate = DateTime(
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
                            dueDate != null
                                ? 'Next Date: ${DateFormat("dd MMM yyyy, hh:mm a").format(dueDate!)}'
                                : 'Choose Date & Time',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.darkBlue),
              onPressed: () {
                if (clientCtrl.text.trim().isEmpty) return;
                final assignedName = selectedFounder == 'Other (Enter Manually)'
                    ? manualAssignedCtrl.text.trim()
                    : selectedFounder;

                final currentUser = ref.read(authProvider).profile;
                final creatorName = (currentUser != null && currentUser.name.trim().isNotEmpty)
                    ? currentUser.name.trim()
                    : 'Yahya Mundewadi';

                Navigator.pop(ctx);
                final rec = CrmRecord(
                  id: '',
                  entityType: 'followup',
                  title: 'Follow-up: ${clientCtrl.text.trim()}',
                  clientName: clientCtrl.text.trim(),
                  description: notesCtrl.text.trim(),
                  dueDate: dueDate,
                  status: status,
                  assignedTo: assignedName,
                  extraData: {
                    'assigned_to': assignedName,
                    'status_changed_by': creatorName,
                    'status_changed_at': DateTime.now().toIso8601String(),
                  },
                );
                ref.read(crmProvider.notifier).addRecord(rec);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Follow-up scheduled and assigned to $assignedName'),
                    backgroundColor: AppConstants.statusSuccess,
                  ),
                );
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCollectionDialog(BuildContext context) {
    final clientCtrl = TextEditingController();
    final amountDueCtrl = TextEditingController();
    final amountRecCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Invoice / Collection', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: clientCtrl, decoration: const InputDecoration(labelText: 'Client Name')),
            const SizedBox(height: 10),
            TextField(controller: amountDueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount Due (₹)')),
            const SizedBox(height: 10),
            TextField(controller: amountRecCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount Received (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.darkBlue),
            onPressed: () {
              if (clientCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final rec = CrmRecord(
                id: '',
                entityType: 'collection',
                title: 'Invoice: ${clientCtrl.text.trim()}',
                clientName: clientCtrl.text.trim(),
                amountDue: double.tryParse(amountDueCtrl.text.trim()) ?? 0.0,
                amountReceived: double.tryParse(amountRecCtrl.text.trim()) ?? 0.0,
                dueDate: DateTime.now().add(const Duration(days: 7)),
              );
              ref.read(crmProvider.notifier).addRecord(rec);
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }
}
