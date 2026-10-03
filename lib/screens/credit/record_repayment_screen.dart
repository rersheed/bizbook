import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/currency.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class RecordRepaymentScreen extends StatefulWidget {
  final String? creditId;
  const RecordRepaymentScreen({super.key, this.creditId});

  @override
  State<RecordRepaymentScreen> createState() => _RecordRepaymentScreenState();
}

class _RecordRepaymentScreenState extends State<RecordRepaymentScreen> {
  late String? creditId;
  final amount = TextEditingController();
  final note = TextEditingController();
  DateTime repaymentDate = DateTime.now();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    creditId = widget.creditId;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<AppStore>();
    final credit = store.creditById(creditId);
    final value = double.tryParse(amount.text.replaceAll(',', '').trim());
    if (credit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a credit')),
      );
      return;
    }
    final error = store.repaymentError(credit, value ?? 0);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => saving = true);
    final saved = await store.recordRepayment(
      creditId: credit.id,
      amount: value ?? 0,
      repaymentDate: repaymentDate,
      note: note.text,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (saved == null || saved.syncStatus == SyncStatus.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.lastError ?? 'Could not save repayment')),
      );
      return;
    }
    final remaining = store.creditById(credit.id);
    final left = formatMoney(remaining?.outstandingAmount ?? 0, symbol: store.symbol);
    final offline = saved.syncStatus == SyncStatus.pending;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(offline ? 'Saved offline' : 'Repayment saved'),
        content: Text('Remaining balance: $left'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sym = store.symbol;
    final open = store.openCredits();
    final credit = store.creditById(creditId);
    final selected = open.any((c) => c.id == creditId) ? creditId : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Record repayment')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (open.isEmpty)
                const EmptyState(
                  icon: Icons.task_alt,
                  title: 'Nothing left to collect',
                  subtitle: 'Open credits will show up here',
                )
              else ...[
                DropdownButtonFormField<String>(
                  value: selected,
                  decoration: const InputDecoration(labelText: 'Credit'),
                  items: open
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              '${store.customerName(c.customerId)} · ${c.description}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: widget.creditId == null
                      ? (v) => setState(() => creditId = v)
                      : null,
                ),
                if (credit != null) ...[
                  const SizedBox(height: 16),
                  SoftCard(
                    color: BizColors.primary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.customerName(credit.customerId),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(credit.description,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9))),
                        const SizedBox(height: 10),
                        Text('Outstanding',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12)),
                        Text(
                          formatMoney(credit.outstandingAmount, symbol: sym),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount ($sym)',
                      prefixText: '$sym ',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Repayment date'),
                    subtitle: Text(friendlyDate(repaymentDate)),
                    trailing: const Icon(Icons.event),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: repaymentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setState(() => repaymentDate = picked);
                    },
                  ),
                  TextField(
                    controller: note,
                    decoration:
                        const InputDecoration(labelText: 'Note (optional)'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: saving ? null : _save,
                    child: Text(saving ? 'Saving…' : 'Save repayment'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
