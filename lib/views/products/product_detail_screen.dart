import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/crm_record.dart';
import '../../providers/crm_provider.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final CrmRecord product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allRecords = ref.watch(crmProvider).records;
    final currentProduct = allRecords.firstWhere(
      (r) => r.id == widget.product.id,
      orElse: () => widget.product,
    );

    // Linked items
    final linkedLeads = allRecords
        .where((r) => r.entityType == 'lead' && r.productId == currentProduct.id)
        .toList();
    final linkedTasks = allRecords
        .where((r) => r.entityType == 'task' && r.productId == currentProduct.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(currentProduct.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppConstants.statusDanger),
            onPressed: () {
              ref.read(crmProvider.notifier).deleteRecord(currentProduct.id);
              Navigator.pop(context);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppConstants.darkBlue,
          unselectedLabelColor: AppConstants.textMuted,
          indicatorColor: AppConstants.darkBlue,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Pitching'),
            Tab(text: 'Leads'),
            Tab(text: 'Stage'),
            Tab(text: 'Clients'),
            Tab(text: 'Tasks'),
            Tab(text: 'Notes'),
          ],
        ),
      ),
      body: GradientBackdrop(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(currentProduct),
            _buildPitchingTab(currentProduct),
            _buildLeadsTab(currentProduct, linkedLeads),
            _buildStageTab(currentProduct, linkedLeads),
            _buildClientsTab(currentProduct),
            _buildTasksTab(currentProduct, linkedTasks),
            _buildNotesTab(currentProduct),
          ],
        ),
      ),
    );
  }

  // 1. Overview
  Widget _buildOverviewTab(CrmRecord product) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Commercial License',
                      style: TextStyle(
                        color: AppConstants.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${NumberFormat('#,##,###').format(double.tryParse(product.productPrice) ?? 0)}',
                      style: const TextStyle(
                        color: AppConstants.darkBlue,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  product.title,
                  style: const TextStyle(
                    color: AppConstants.textBlack,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description ?? 'No description provided.',
                  style: const TextStyle(
                    color: AppConstants.textBlack,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const Divider(height: 24, color: AppConstants.borderSubtle),
                const Text(
                  'Core Enterprise Capabilities',
                  style: TextStyle(
                    color: AppConstants.textBlack,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: product.productFeatures
                      .map((feat) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppConstants.skyBlue.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppConstants.skyBlue.withOpacity(0.3)),
                            ),
                            child: Text(
                              feat,
                              style: const TextStyle(
                                color: AppConstants.skyBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2. Pitching Tab
  Widget _buildPitchingTab(CrmRecord product) {
    final pitches = (product.extraData['pitches'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_pitch_fab',
        backgroundColor: AppConstants.darkBlue,
        foregroundColor: AppConstants.pureWhite,
        onPressed: () => _showAddPitchDialog(product),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Log Pitch'),
      ),
      body: pitches.isEmpty
          ? _buildEmptyTab('No sales pitches recorded yet')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pitches.length,
              itemBuilder: (ctx, i) {
                final p = pitches[i] as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      'Pitched to: ${p['pitched_to'] ?? "Prospect"}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Outcome: ${p['outcome'] ?? "In Progress"}\nNotes: ${p['notes'] ?? ""}',
                      style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                    ),
                    trailing: Text(
                      p['date'] ?? '',
                      style: const TextStyle(color: AppConstants.skyBlue, fontSize: 11),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // 3. Leads Tab
  Widget _buildLeadsTab(CrmRecord product, List<CrmRecord> leads) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_lead_fab',
        backgroundColor: AppConstants.darkBlue,
        foregroundColor: AppConstants.pureWhite,
        onPressed: () => _showAddLeadDialog(product),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Lead'),
      ),
      body: leads.isEmpty
          ? _buildEmptyTab('No active leads assigned to this product')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: leads.length,
              itemBuilder: (ctx, i) {
                final lead = leads[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      lead.clientName ?? lead.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text('Stage: ${lead.leadStage} • Team: ${lead.team}'),
                    trailing: DropdownButton<String>(
                      value: lead.leadStage,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'New', child: Text('New')),
                        DropdownMenuItem(value: 'Pitched', child: Text('Pitched')),
                        DropdownMenuItem(value: 'Demo', child: Text('Demo')),
                        DropdownMenuItem(value: 'Negotiation', child: Text('Negotiation')),
                        DropdownMenuItem(value: 'Won', child: Text('Won')),
                        DropdownMenuItem(value: 'Lost', child: Text('Lost')),
                      ],
                      onChanged: (newStage) {
                        if (newStage != null) {
                          final extra = Map<String, dynamic>.from(lead.extraData);
                          extra['stage'] = newStage;
                          final updated = lead.copyWith(extraData: extra);
                          ref.read(crmProvider.notifier).updateRecord(updated);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  // 4. Stage Tab (Funnel View)
  Widget _buildStageTab(CrmRecord product, List<CrmRecord> leads) {
    final stages = ['New', 'Pitched', 'Demo', 'Negotiation', 'Won', 'Lost'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: stages.map((stg) {
        final count = leads.where((l) => l.leadStage == stg).length;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stg,
                  style: const TextStyle(
                    color: AppConstants.textBlack,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stg == 'Won'
                        ? AppConstants.statusSuccess.withOpacity(0.15)
                        : (stg == 'Lost'
                            ? AppConstants.statusDanger.withOpacity(0.15)
                            : AppConstants.skyBlue.withOpacity(0.15)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count leads',
                    style: TextStyle(
                      color: stg == 'Won'
                          ? AppConstants.statusSuccess
                          : (stg == 'Lost'
                              ? AppConstants.statusDanger
                              : AppConstants.skyBlue),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // 5. Clients Tab
  Widget _buildClientsTab(CrmRecord product) {
    final clients = (product.extraData['clients'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_client_fab',
        backgroundColor: AppConstants.darkBlue,
        foregroundColor: AppConstants.pureWhite,
        onPressed: () => _showAddClientDialog(product),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Client'),
      ),
      body: clients.isEmpty
          ? _buildEmptyTab('No active deployed clients recorded')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: clients.length,
              itemBuilder: (ctx, i) {
                final c = clients[i] as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Contact: ${c['contact'] ?? ""} • Location: ${c['city'] ?? ""}'),
                  ),
                );
              },
            ),
    );
  }

  // 6. Tasks Tab
  Widget _buildTasksTab(CrmRecord product, List<CrmRecord> tasks) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_prod_task_fab',
        backgroundColor: AppConstants.darkBlue,
        foregroundColor: AppConstants.pureWhite,
        onPressed: () => _showAddProductTaskDialog(product),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Task'),
      ),
      body: tasks.isEmpty
          ? _buildEmptyTab('No tasks assigned to this product')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (ctx, i) {
                final t = tasks[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Status: ${t.status} • Priority: ${t.priority}'),
                  ),
                );
              },
            ),
    );
  }

  // 7. Notes Tab
  Widget _buildNotesTab(CrmRecord product) {
    final notes = (product.extraData['notes'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_note_fab',
        backgroundColor: AppConstants.darkBlue,
        foregroundColor: AppConstants.pureWhite,
        onPressed: () => _showAddNoteDialog(product),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Note'),
      ),
      body: notes.isEmpty
          ? _buildEmptyTab('No team product notes yet')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              itemBuilder: (ctx, i) {
                final n = notes[i] as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n['text'] ?? '', style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(
                          '${n['author'] ?? "Founder"} • ${n['date'] ?? ""}',
                          style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyTab(String msg) {
    return Center(
      child: Text(
        msg,
        style: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
      ),
    );
  }

  // Dialog helpers
  void _showAddPitchDialog(CrmRecord product) {
    final toCtrl = TextEditingController();
    final outcomeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Product Pitch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: toCtrl, decoration: const InputDecoration(labelText: 'Pitched to (School/Org)')),
            const SizedBox(height: 10),
            TextField(controller: outcomeCtrl, decoration: const InputDecoration(labelText: 'Outcome (e.g. Demo Booked)')),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (toCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final pitches = List<Map<String, dynamic>>.from(product.extraData['pitches'] ?? []);
              pitches.add({
                'pitched_to': toCtrl.text.trim(),
                'outcome': outcomeCtrl.text.trim(),
                'notes': notesCtrl.text.trim(),
                'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
              });
              final extra = Map<String, dynamic>.from(product.extraData);
              extra['pitches'] = pitches;
              ref.read(crmProvider.notifier).updateRecord(product.copyWith(extraData: extra));
            },
            child: const Text('Save Pitch'),
          ),
        ],
      ),
    );
  }

  void _showAddLeadDialog(CrmRecord product) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String stage = 'New';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Lead for Product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Lead / Prospect Name')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: stage,
                decoration: const InputDecoration(labelText: 'Pipeline Stage'),
                items: const [
                  DropdownMenuItem(value: 'New', child: Text('New')),
                  DropdownMenuItem(value: 'Pitched', child: Text('Pitched')),
                  DropdownMenuItem(value: 'Demo', child: Text('Demo')),
                  DropdownMenuItem(value: 'Negotiation', child: Text('Negotiation')),
                  DropdownMenuItem(value: 'Won', child: Text('Won')),
                  DropdownMenuItem(value: 'Lost', child: Text('Lost')),
                ],
                onChanged: (v) => setDialogState(() => stage = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final lead = CrmRecord(
                  id: '',
                  entityType: 'lead',
                  title: 'Lead: ${nameCtrl.text.trim()}',
                  clientName: nameCtrl.text.trim(),
                  productId: product.id,
                  team: product.team,
                  extraData: {'stage': stage, 'phone': phoneCtrl.text.trim()},
                );
                ref.read(crmProvider.notifier).addRecord(lead);
              },
              child: const Text('Save Lead'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddClientDialog(CrmRecord product) {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final cityCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Active Client', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Client Name')),
            const SizedBox(height: 10),
            TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact Person / Phone')),
            const SizedBox(height: 10),
            TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City / Region')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final clients = List<Map<String, dynamic>>.from(product.extraData['clients'] ?? []);
              clients.add({
                'name': nameCtrl.text.trim(),
                'contact': contactCtrl.text.trim(),
                'city': cityCtrl.text.trim(),
              });
              final extra = Map<String, dynamic>.from(product.extraData);
              extra['clients'] = clients;
              ref.read(crmProvider.notifier).updateRecord(product.copyWith(extraData: extra));
            },
            child: const Text('Save Client'),
          ),
        ],
      ),
    );
  }

  void _showAddProductTaskDialog(CrmRecord product) {
    final titleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Product Task', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Task Title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final task = CrmRecord(
                id: '',
                entityType: 'task',
                title: titleCtrl.text.trim(),
                productId: product.id,
                team: product.team,
                status: 'pending',
              );
              ref.read(crmProvider.notifier).addRecord(task);
            },
            child: const Text('Add Task'),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog(CrmRecord product) {
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Product Note', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Enter team note...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (noteCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final notes = List<Map<String, dynamic>>.from(product.extraData['notes'] ?? []);
              notes.add({
                'text': noteCtrl.text.trim(),
                'author': 'Yahya Mundewadi',
                'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
              });
              final extra = Map<String, dynamic>.from(product.extraData);
              extra['notes'] = notes;
              ref.read(crmProvider.notifier).updateRecord(product.copyWith(extraData: extra));
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }
}
