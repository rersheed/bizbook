import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';

class RecordExpenseScreen extends StatefulWidget {
  const RecordExpenseScreen({super.key});

  @override
  State<RecordExpenseScreen> createState() => _RecordExpenseScreenState();
}

class _RecordExpenseScreenState extends State<RecordExpenseScreen> {
  final description = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();
  String? categoryId;
  DateTime spentAt = DateTime.now();
  bool saving = false;

  @override
  void dispose() {
    description.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: spentAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => spentAt = d);
  }

  Future<void> _save() async {
    final amt = double.tryParse(amount.text.replaceAll(',', ''));
    if (description.text.trim().isEmpty || amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description and amount required')),
      );
      return;
    }
    setState(() => saving = true);
    final store = context.read<AppStore>();
    final cat = store.categories.cast<dynamic>().firstWhere(
          (c) => c.id == categoryId,
          orElse: () => null,
        );
    final exp = await store.recordExpense(
      description: description.text,
      amount: amt,
      categoryId: categoryId,
      categoryName: cat?.name,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      spentAt: spentAt,
    );
    setState(() => saving = false);
    if (!mounted) return;
    if (exp.syncStatus == SyncStatus.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.lastError ?? 'Could not save expense')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(exp.syncStatus == SyncStatus.pending
            ? 'Saved offline'
            : 'Expense saved'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Record expense')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: description,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'e.g. NEPA token, shop rent',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  prefixText: '${store.symbol} ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...store.categories.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )),
                ],
                onChanged: (v) => setState(() => categoryId = v),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(DateFormat('EEE, d MMM yyyy').format(spentAt)),
                trailing: const Icon(Icons.calendar_today,
                    color: BizColors.primary),
                onTap: _pickDate,
              ),
              TextField(
                controller: note,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: saving ? null : _save,
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
