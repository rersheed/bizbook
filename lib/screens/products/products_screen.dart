import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/currency.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final search = TextEditingController();
  bool showInactive = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _edit(Product? existing) async {
    final store = context.read<AppStore>();
    if (!store.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only owners can manage products')),
      );
      return;
    }
    final name = TextEditingController(text: existing?.name ?? '');
    final sku = TextEditingController(text: existing?.sku ?? '');
    final price = TextEditingController(
        text: existing != null ? existing.unitPrice.toStringAsFixed(0) : '');
    final unit = TextEditingController(text: existing?.unit ?? 'pcs');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Add product' : 'Edit product',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name *')),
            const SizedBox(height: 10),
            TextField(
                controller: sku,
                decoration: const InputDecoration(labelText: 'SKU')),
            const SizedBox(height: 10),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'Unit price *', prefixText: '${store.symbol} '),
            ),
            const SizedBox(height: 10),
            TextField(
                controller: unit,
                decoration: const InputDecoration(labelText: 'Unit')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty ||
                    double.tryParse(price.text) == null) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final p = Product(
      id: existing?.id ?? const Uuid().v4(),
      businessId: store.business!.id,
      name: name.text.trim(),
      sku: sku.text.trim().isEmpty ? null : sku.text.trim(),
      unitPrice: double.parse(price.text),
      unit: unit.text.trim().isEmpty ? 'pcs' : unit.text.trim(),
      isActive: existing?.isActive ?? true,
      costPrice: existing?.costPrice,
    );
    await store.upsertProduct(p);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sym = store.symbol;
    final q = search.text.trim().toLowerCase();
    final list = store.products
        .where((p) => showInactive || p.isActive)
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            (p.sku?.toLowerCase().contains(q) ?? false))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          if (store.isOwner)
            IconButton(
              icon: const Icon(Icons.add_circle, color: BizColors.primary),
              onPressed: () => _edit(null),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search products…',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (store.isOwner)
                      IconButton(
                        tooltip: showInactive ? 'Hide disabled' : 'Show disabled',
                        onPressed: () =>
                            setState(() => showInactive = !showInactive),
                        icon: Icon(
                          showInactive
                              ? Icons.visibility
                              : Icons.visibility_outlined,
                          color: BizColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No products',
                        subtitle: 'Owners can add products for fast sales',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final p = list[i];
                          return SoftCard(
                            onTap: store.isOwner ? () => _edit(p) : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: BizColors.accent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.inventory_2,
                                      color: BizColors.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: p.isActive
                                                ? BizColors.text
                                                : BizColors.muted,
                                            decoration: p.isActive
                                                ? null
                                                : TextDecoration.lineThrough,
                                          )),
                                      Text(
                                        [
                                          if (p.sku != null) p.sku!,
                                          p.unit,
                                          p.isActive ? 'Active' : 'Disabled',
                                        ].join(' · '),
                                        style: const TextStyle(
                                            color: BizColors.muted,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(formatMoney(p.unitPrice, symbol: sym),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: BizColors.primary)),
                                if (store.isOwner) ...[
                                  const SizedBox(width: 4),
                                  PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'toggle') {
                                        await store.setProductActive(
                                            p.id, !p.isActive);
                                      } else if (v == 'edit') {
                                        await _edit(p);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                          value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Text(p.isActive
                                            ? 'Disable'
                                            : 'Enable'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
