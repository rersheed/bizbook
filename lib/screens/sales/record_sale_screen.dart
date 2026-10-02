import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/currency.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class RecordSaleScreen extends StatefulWidget {
  const RecordSaleScreen({super.key});

  @override
  State<RecordSaleScreen> createState() => _RecordSaleScreenState();
}

class _RecordSaleScreenState extends State<RecordSaleScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabs;
  final search = TextEditingController();
  final cart = <_CartLine>[];
  final manualName = TextEditingController();
  final manualAmount = TextEditingController();
  final note = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabs.dispose();
    search.dispose();
    manualName.dispose();
    manualAmount.dispose();
    note.dispose();
    super.dispose();
  }

  double get cartTotal =>
      cart.fold(0.0, (a, c) => a + c.qty * c.unitPrice);

  void _addProduct(Product p) {
    final i = cart.indexWhere((c) => c.productId == p.id);
    setState(() {
      if (i >= 0) {
        cart[i] = cart[i].copyWith(qty: cart[i].qty + 1);
      } else {
        cart.add(_CartLine(
          productId: p.id,
          name: p.name,
          unitPrice: p.unitPrice,
          qty: 1,
        ));
      }
    });
  }

  Future<void> _saveCart() async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')),
      );
      return;
    }
    setState(() => saving = true);
    final store = context.read<AppStore>();
    final items = cart
        .map((c) => SaleItem(
              id: const Uuid().v4(),
              productId: c.productId,
              productName: c.name,
              quantity: c.qty,
              unitPrice: c.unitPrice,
              lineTotal: c.qty * c.unitPrice,
            ))
        .toList();
    await store.recordSale(
      items: items,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
    );
    setState(() => saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale saved')),
    );
    Navigator.pop(context);
  }

  Future<void> _saveManual() async {
    final amount = double.tryParse(manualAmount.text.replaceAll(',', ''));
    final name = manualName.text.trim().isEmpty
        ? 'Quick sale'
        : manualName.text.trim();
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    setState(() => saving = true);
    final store = context.read<AppStore>();
    await store.recordSale(
      items: [
        SaleItem(
          id: const Uuid().v4(),
          productName: name,
          quantity: 1,
          unitPrice: amount,
          lineTotal: amount,
        ),
      ],
      note: note.text.trim().isEmpty ? null : note.text.trim(),
    );
    setState(() => saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale saved')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sym = store.symbol;
    final q = search.text.trim().toLowerCase();
    final products = store.products
        .where((p) => p.isActive)
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            (p.sku?.toLowerCase().contains(q) ?? false))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record sale'),
        bottom: TabBar(
          controller: tabs,
          labelColor: BizColors.primary,
          indicatorColor: BizColors.primary,
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'Quick amount'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabs,
        children: [
          // Products / cart
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search products…',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final p = products[i];
                    final inCart = cart.where((c) => c.productId == p.id);
                    final qty = inCart.isEmpty ? 0.0 : inCart.first.qty;
                    return SoftCard(
                      padding: const EdgeInsets.all(12),
                      onTap: () => _addProduct(p),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(
                                  '${formatMoney(p.unitPrice, symbol: sym)} / ${p.unit}',
                                  style: const TextStyle(
                                      color: BizColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (qty > 0)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: BizColors.accent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('×${qty.toInt()}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: BizColors.primary)),
                            ),
                          FilledButton(
                            onPressed: () => _addProduct(p),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(72, 40),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (cart.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: BizColors.white,
                    border: Border(top: BorderSide(color: BizColors.border)),
                  ),
                  child: Column(
                    children: [
                      ...cart.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(c.name)),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => setState(() {
                                    if (c.qty <= 1) {
                                      cart.remove(c);
                                    } else {
                                      final i = cart.indexOf(c);
                                      cart[i] = c.copyWith(qty: c.qty - 1);
                                    }
                                  }),
                                ),
                                Text('${c.qty.toInt()}'),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => setState(() {
                                    final i = cart.indexOf(c);
                                    cart[i] = c.copyWith(qty: c.qty + 1);
                                  }),
                                ),
                              ],
                            ),
                          )),
                      TextField(
                        controller: note,
                        decoration:
                            const InputDecoration(labelText: 'Note (optional)'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: saving ? null : _saveCart,
                        child: Text(
                            'Save sale · ${formatMoney(cartTotal, symbol: sym)}'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // Quick manual
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Quick manual sale',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('For walk-in cash sales without a product line.',
                  style: TextStyle(color: BizColors.muted)),
              const SizedBox(height: 20),
              TextField(
                controller: manualName,
                decoration: const InputDecoration(
                    labelText: 'Description', hintText: 'e.g. Mixed items'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: manualAmount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount ($sym)',
                  prefixText: '$sym ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration:
                    const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: saving ? null : _saveManual,
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save sale'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartLine {
  final String? productId;
  final String name;
  final double unitPrice;
  final double qty;
  _CartLine({
    this.productId,
    required this.name,
    required this.unitPrice,
    required this.qty,
  });
  _CartLine copyWith({double? qty}) => _CartLine(
        productId: productId,
        name: name,
        unitPrice: unitPrice,
        qty: qty ?? this.qty,
      );
}
