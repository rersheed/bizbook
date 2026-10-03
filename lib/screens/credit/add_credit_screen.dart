import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import 'customers_screen.dart';

class AddCreditScreen extends StatefulWidget {
  final String? customerId;
  const AddCreditScreen({super.key, this.customerId});

  @override
  State<AddCreditScreen> createState() => _AddCreditScreenState();
}

class _AddCreditScreenState extends State<AddCreditScreen> {
  late String? customerId;
  final description = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();
  DateTime creditDate = DateTime.now();
  DateTime? dueDate;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    customerId = widget.customerId;
  }

  @override
  void dispose() {
    description.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool due}) async {
    final initial = due ? (dueDate ?? creditDate) : creditDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    setState(() {
      if (due) {
        dueDate = picked;
      } else {
        creditDate = picked;
      }
    });
  }

  Future<void> _createCustomer() async {
    final created = await showCustomerEditor(context);
    if (created == null) return;
    setState(() => customerId = created.id);
  }

  Future<void> _save() async {
    final store = context.read<AppStore>();
    final value = double.tryParse(amount.text.replaceAll(',', '').trim());
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a customer')),
      );
      return;
    }
    setState(() => saving = true);
    final credit = await store.addCredit(
      customerId: customerId!,
      description: description.text,
      amount: value ?? 0,
      creditDate: creditDate,
      dueDate: dueDate,
      note: note.text,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (credit == null || credit.syncStatus == SyncStatus.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.lastError ?? 'Could not save credit')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(credit.syncStatus == SyncStatus.pending
            ? 'Saved offline'
            : 'Credit saved'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sym = store.symbol;
    return Scaffold(
      appBar: AppBar(title: const Text('Add credit')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
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
                  onPressed: _createCustomer,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('New customer'),
                ),
              ),
              TextField(
                controller: description,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What was taken on credit?',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount ($sym)',
                  prefixText: '$sym ',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Credit date'),
                subtitle: Text(friendlyDate(creditDate)),
                trailing: const Icon(Icons.event),
                onTap: () => _pickDate(due: false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due date (optional)'),
                subtitle: Text(dueDate == null
                    ? 'No due date'
                    : friendlyDate(dueDate!)),
                trailing: dueDate == null
                    ? const Icon(Icons.event_outlined)
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => dueDate = null),
                      ),
                onTap: () => _pickDate(due: true),
              ),
              TextField(
                controller: note,
                decoration:
                    const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving ? null : _save,
                child: Text(saving ? 'Saving…' : 'Save credit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
