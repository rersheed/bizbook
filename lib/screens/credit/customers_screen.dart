import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import 'customer_detail_screen.dart';

Future<Customer?> showCustomerEditor(
  BuildContext context, {
  Customer? existing,
}) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => CustomerForm(existing: existing),
  );
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final q = search.text.trim().toLowerCase();
    final list = store.customers.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          (c.phone?.toLowerCase().contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCustomerEditor(context),
        backgroundColor: BizColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('New customer'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search name, phone, or email',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'No customers yet',
                        subtitle: 'Add someone before you record credit',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = list[i];
                          final owing = store.outstandingKobo(customerId: c.id);
                          return SoftCard(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CustomerDetailScreen(customerId: c.id),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800)),
                                      if ((c.phone ?? '').isNotEmpty)
                                        Text(c.phone!,
                                            style: const TextStyle(
                                                color: BizColors.muted,
                                                fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text(
                                  owing > 0
                                      ? formatMoney(koboToMoney(owing),
                                          symbol: store.symbol)
                                      : 'Clear',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: owing > 0
                                        ? BizColors.highlight
                                        : BizColors.secondary,
                                  ),
                                ),
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

class CustomerForm extends StatefulWidget {
  final Customer? existing;
  const CustomerForm({super.key, this.existing});

  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController email;
  late final TextEditingController address;
  late final TextEditingController note;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    name = TextEditingController(text: c?.name ?? '');
    phone = TextEditingController(text: c?.phone ?? '');
    email = TextEditingController(text: c?.email ?? '');
    address = TextEditingController(text: c?.address ?? '');
    note = TextEditingController(text: c?.note ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final store = context.read<AppStore>();
    final saved = await store.saveCustomer(
      id: widget.existing?.id,
      name: name.text,
      phone: phone.text,
      email: email.text,
      address: address.text,
      note: note.text,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.lastError ?? 'Could not save customer')),
      );
      return;
    }
    final offline = saved.syncStatus == SyncStatus.pending;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(offline ? 'Saved offline' : 'Customer saved')),
    );
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            widget.existing == null ? 'New customer' : 'Edit customer',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (optional)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: address,
            decoration: const InputDecoration(labelText: 'Address (optional)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: saving ? null : _save,
            child: Text(saving ? 'Saving…' : 'Save customer'),
          ),
        ],
      ),
    );
  }
}
