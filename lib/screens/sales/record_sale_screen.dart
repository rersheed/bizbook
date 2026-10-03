import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../credit/customers_screen.dart';
import '../products/products_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/business_profile_screen.dart';
import '../staff/staff_screen.dart';

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
  final paidNow = TextEditingController();
  PaymentStatus payment = PaymentStatus.paid;
  String? customerId;
  DateTime? dueDate;
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
    paidNow.dispose();
    super.dispose();
  }

  int _totalKobo(List<_CartLine> lines) =>
      lines.fold(0, (sum, line) => sum + lineKobo(line.qty, line.unitPrice));

  Future<void> _editPrice(_CartLine line) async {
    final controller = TextEditingController(
      text: line.unitPrice.toStringAsFixed(2),
    );
    final next = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(line.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Price'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value =
                  double.tryParse(controller.text.replaceAll(',', '').trim());
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null || next < 0) return;
    setState(() {
      final i = cart.indexOf(line);
      if (i >= 0) cart[i] = line.copyWith(unitPrice: next);
    });
  }

  Future<void> _addManualLine() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final qty = TextEditingController(text: '1');
    final line = await showDialog<_CartLine>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: qty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            TextField(
              controller: price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final q = double.tryParse(qty.text.replaceAll(',', '').trim());
              final p = double.tryParse(price.text.replaceAll(',', '').trim());
              if (q == null || p == null || q <= 0 || p < 0) return;
              Navigator.pop(
                context,
                _CartLine(
                  name: name.text.trim().isEmpty ? 'Manual item' : name.text.trim(),
                  unitPrice: p,
                  qty: q,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    name.dispose();
    price.dispose();
    qty.dispose();
    if (line == null) return;
    setState(() => cart.add(line));
  }

  Future<void> _newCustomer() async {
    final created = await showCustomerEditor(context);
    if (created == null) return;
    setState(() => customerId = created.id);
  }

  Future<void> _save(List<_CartLine> lines) async {
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')),
      );
      return;
    }
    final total = _totalKobo(lines);
    int? paidKobo;
    if (payment == PaymentStatus.partial) {
      final paid =
          double.tryParse(paidNow.text.replaceAll(',', '').trim()) ?? 0;
      paidKobo = moneyToKobo(paid);
    }
    setState(() => saving = true);
    final store = context.read<AppStore>();
    final sale = await store.recordSale(
      items: lines
          .map((c) => SaleItem(
                id: const Uuid().v4(),
                productId: c.productId,
                productName: c.name,
                quantity: c.qty,
                unitPrice: c.unitPrice,
                lineTotal: koboToMoney(lineKobo(c.qty, c.unitPrice)),
              ))
          .toList(),
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      customerId: customerId,
      paymentStatus: payment,
      paidKobo: paidKobo,
      dueDate: payment == PaymentStatus.paid ? null : dueDate,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (sale.syncStatus == SyncStatus.failed || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.lastError ?? 'Could not save sale')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sale.syncStatus == SyncStatus.pending
            ? 'Saved offline'
            : 'Sale saved'),
      ),
    );
    Navigator.pop(context);
  }

  void _saveCart() => _save(List<_CartLine>.from(cart));

  void _saveManual() {
    final amount =
        double.tryParse(manualAmount.text.replaceAll(',', '').trim());
    final name =
        manualName.text.trim().isEmpty ? 'Quick sale' : manualName.text.trim();
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    _save([
      _CartLine(name: name, unitPrice: amount, qty: 1),
    ]);
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
    final cartTotal = _totalKobo(cart);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record sale'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              final Widget page;
              switch (value) {
                case 'products':
                  page = const ProductsScreen();
                case 'staff':
                  page = const StaffScreen();
                case 'reports':
                  page = const ReportsScreen();
                default:
                  page = const BusinessProfileScreen();
              }
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => page),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'products', child: Text('Products')),
              if (store.isOwner)
                const PopupMenuItem(value: 'staff', child: Text('Staff')),
              if (store.isOwner)
                const PopupMenuItem(value: 'reports', child: Text('Reports')),
              const PopupMenuItem(
                value: 'business',
                child: Text('Business profile'),
              ),
            ],
          ),
        ],
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
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search products…',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Manual item',
                      onPressed: _addManualLine,
                      icon: const Icon(Icons.edit_note),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No products',
                        subtitle: 'Add a manual item or open Products',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: products.length,
                        itemBuilder: (context, i) {
                          final p = products[i];
                          final inCart =
                              cart.where((c) => c.productId == p.id);
                          final qty = inCart.isEmpty ? 0.0 : inCart.first.qty;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SoftCard(
                              padding: const EdgeInsets.all(12),
                              onTap: () => _addProduct(p),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        Text(
                                          '${formatMoney(p.unitPrice, symbol: sym)} / ${p.unit}',
                                          style: const TextStyle(
                                              color: BizColors.muted,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (qty > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text('×${_qtyLabel(qty)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: BizColors.primary)),
                                    ),
                                  FilledButton(
                                    onPressed: () => _addProduct(p),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(72, 40),
                                    ),
                                    child: const Text('Add'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (cart.isNotEmpty)
                _checkout(
                  store,
                  sym,
                  cartTotal,
                  lines: cart,
                  onSave: saving ? null : _saveCart,
                ),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Quick manual sale',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'For a walk-in sale without picking products. You can still take partial or credit payment.',
                style: TextStyle(color: BizColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: manualName,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. Mixed items',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: manualAmount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount ($sym)',
                  prefixText: '$sym ',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              _paymentFields(
                store,
                sym,
                moneyToKobo(double.tryParse(
                        manualAmount.text.replaceAll(',', '').trim()) ??
                    0),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: saving ? null : _saveManual,
                child: Text(saving ? 'Saving…' : 'Save sale'),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  Widget _checkout(
    AppStore store,
    String sym,
    int totalKobo, {
    required List<_CartLine> lines,
    required VoidCallback? onSave,
  }) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.48,
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: BizColors.white,
        border: Border(top: BorderSide(color: BizColors.border)),
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          ...lines.map((c) => Row(
                children: [
                  Expanded(
                    child: Text(c.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  TextButton(
                    onPressed: () => _editPrice(c),
                    child: Text(formatMoney(c.unitPrice, symbol: sym)),
                  ),
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
                  Text(_qtyLabel(c.qty)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() {
                      final i = cart.indexOf(c);
                      cart[i] = c.copyWith(qty: c.qty + 1);
                    }),
                  ),
                ],
              )),
          _paymentFields(store, sym, totalKobo),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onSave,
            child: Text(
                'Save sale · ${formatMoney(koboToMoney(totalKobo), symbol: sym)}'),
          ),
        ],
      ),
    );
  }

  Widget _paymentFields(AppStore store, String sym, int totalKobo) {
    final paid = payment == PaymentStatus.partial
        ? moneyToKobo(
            double.tryParse(paidNow.text.replaceAll(',', '').trim()) ?? 0)
        : (payment == PaymentStatus.credit ? 0 : totalKobo);
    final onCredit = totalKobo - paid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SegmentedButton<PaymentStatus>(
          segments: const [
            ButtonSegment(value: PaymentStatus.paid, label: Text('Paid')),
            ButtonSegment(value: PaymentStatus.partial, label: Text('Partial')),
            ButtonSegment(value: PaymentStatus.credit, label: Text('Credit')),
          ],
          selected: {payment},
          onSelectionChanged: (value) => setState(() => payment = value.first),
        ),
        if (payment == PaymentStatus.partial) ...[
          const SizedBox(height: 10),
          Text('Total ${formatMoney(koboToMoney(totalKobo), symbol: sym)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: paidNow,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Paid now ($sym)',
              prefixText: '$sym ',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'On credit ${formatMoney(koboToMoney(onCredit < 0 ? 0 : onCredit), symbol: sym)}',
            style: const TextStyle(color: BizColors.highlight),
          ),
        ],
        if (payment != PaymentStatus.paid) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: store.customers.any((c) => c.id == customerId)
                ? customerId
                : null,
            decoration: const InputDecoration(labelText: 'Customer'),
            items: store.customers
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() => customerId = v),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _newCustomer,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('New customer'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Due date (optional)'),
            subtitle: Text(dueDate == null ? 'None' : friendlyDate(dueDate!)),
            trailing: const Icon(Icons.event),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dueDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (picked != null) setState(() => dueDate = picked);
            },
          ),
        ],
        TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
      ],
    );
  }

  String _qtyLabel(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
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
  _CartLine copyWith({double? qty, double? unitPrice}) => _CartLine(
        productId: productId,
        name: name,
        unitPrice: unitPrice ?? this.unitPrice,
        qty: qty ?? this.qty,
      );
}
