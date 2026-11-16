import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/svg_icons.dart';
import '../../core/theme.dart';
import '../../models/crm_record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crm_provider.dart';

class PipelineScreen extends ConsumerStatefulWidget {
  const PipelineScreen({super.key});

  @override
  ConsumerState<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends ConsumerState<PipelineScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackdrop(
      child: Column(
        children: [
          // Segmented Tab Bar
          Container(
            color: AppConstants.pureWhite,
            child: TabBar(
              controller: _tabController,
              labelColor: AppConstants.darkBlue,
              unselectedLabelColor: AppConstants.textMuted,
              indicatorColor: AppConstants.darkBlue,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Channel Partners'),
                Tab(text: 'Follow-ups'),
                Tab(text: 'Collections'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPartnersTab(),
                _buildFollowupsTab(),
                _buildCollectionsTab(),
              ],
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
    final nextVisit = partner.nextVisitDate ?? 'Not scheduled';

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.skyBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    partner.team,
                    style: const TextStyle(
                      color: AppConstants.skyBlue,
                      fontSize: 11,
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
                final dateStr = item.dueDate != null
                    ? DateFormat('dd MMM yyyy').format(item.dueDate!)
                    : 'Not set';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      item.clientName ?? item.title,
                      style: const TextStyle(
                        color: AppConstants.textBlack,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${item.description ?? "Product Inquiry"} • Next Date: $dateStr',
                      style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: AppConstants.statusSuccess),
                      onPressed: () {
                        final updated = item.copyWith(status: 'completed');
                        ref.read(crmProvider.notifier).updateRecord(updated);
                      },
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
                  _buildEmptyView('No collections currently recorded'),
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
                            Text(
                              item.clientName ?? item.title,
                              style: const TextStyle(
                                color: AppConstants.textBlack,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
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

  // Dialogs
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Client Follow-up', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: clientCtrl, decoration: const InputDecoration(labelText: 'Client / School Name')),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Follow-up Notes')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (clientCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final rec = CrmRecord(
                id: '',
                entityType: 'followup',
                title: 'Follow-up: ${clientCtrl.text.trim()}',
                clientName: clientCtrl.text.trim(),
                description: notesCtrl.text.trim(),
                dueDate: DateTime.now().add(const Duration(days: 2)),
              );
              ref.read(crmProvider.notifier).addRecord(rec);
            },
            child: const Text('Schedule'),
          ),
        ],
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

