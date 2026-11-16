import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/svg_icons.dart';
import '../../core/theme.dart';
import '../../models/crm_record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crm_provider.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  void _showAddProductDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final featuresCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Software Product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Product Name', hintText: 'e.g. EduCloud Suite'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'License Price (₹)', hintText: '150000'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: featuresCtrl,
                decoration: const InputDecoration(
                  labelText: 'Key Features (comma-separated)',
                  hintText: 'Billing, Mobile App, Analytics',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final features = featuresCtrl.text
                  .split(',')
                  .map((f) => f.trim())
                  .where((f) => f.isNotEmpty)
                  .toList();

              final p = CrmRecord(
                id: '',
                entityType: 'product',
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim(),
                team: 'Both',
                status: 'active',
                extraData: {
                  'price': priceCtrl.text.trim(),
                  'features': features,
                  'category': 'Enterprise',
                },
              );
              ref.read(crmProvider.notifier).addRecord(p);
            },
            child: const Text('Add Product'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final user = ref.watch(authProvider).profile;
    final canAdd = user?.canCreate('products') ?? true;

    return GradientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: canAdd
            ? FloatingActionButton.extended(
                heroTag: 'add_prod_fab',
                backgroundColor: AppConstants.darkBlue,
                foregroundColor: AppConstants.pureWhite,
                onPressed: () => _showAddProductDialog(context, ref),
                icon: const AppSvgIcon(svg: AppSvgIcons.plus, size: 16, color: Colors.white),
                label: const Text('Add Product'),
              )
            : null,
        body: products.isEmpty
            ? const Center(child: Text('No products available', style: TextStyle(color: AppConstants.textMuted)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final priceNum = double.tryParse(product.productPrice) ?? 0;
                  final formattedPrice = NumberFormat('#,##,###').format(priceNum);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: product),
                          ),
                        );
                      },
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
                                    product.title,
                                    style: const TextStyle(
                                      color: AppConstants.textBlack,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹$formattedPrice',
                                  style: const TextStyle(
                                    color: AppConstants.darkBlue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            if (product.description?.isNotEmpty == true) ...[
                              const SizedBox(height: 6),
                              Text(
                                product.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppConstants.textBlack,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: product.productFeatures
                                  .take(4)
                                  .map((feat) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppConstants.skyBlue.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          feat,
                                          style: const TextStyle(
                                            color: AppConstants.skyBlue,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 12),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Manage Modules & Leads',
                                  style: TextStyle(
                                    color: AppConstants.darkBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 10, color: AppConstants.darkBlue),
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
}
