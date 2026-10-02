import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/currency.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../widgets/widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int range = 0; // today week month custom
  String? staffId;
  DateTime? customFrom;
  DateTime? customTo;

  (DateTime, DateTime) _bounds() {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 1));
    switch (range) {
      case 0:
        return (DateTime(now.year, now.month, now.day), end);
      case 1:
        return (now.subtract(const Duration(days: 7)), end);
      case 2:
        return (DateTime(now.year, now.month, 1), end);
      default:
        return (
          customFrom ?? DateTime(now.year, now.month, 1),
          customTo?.add(const Duration(days: 1)) ?? end,
        );
    }
  }

  Future<void> _pickCustom() async {
    final from = await showDatePicker(
      context: context,
      initialDate: customFrom ?? DateTime.now().subtract(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (from == null || !mounted) return;
    final to = await showDatePicker(
      context: context,
      initialDate: customTo ?? DateTime.now(),
      firstDate: from,
      lastDate: DateTime.now(),
    );
    if (to == null) return;
    setState(() {
      range = 3;
      customFrom = from;
      customTo = to;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sym = store.symbol;
    final (from, to) = _bounds();
    final sales = store.salesTotal(from: from, to: to, userId: staffId);
    final expenses = store.expensesTotal(from: from, to: to, userId: staffId);
    final net = sales - expenses;
    final activity = store.staffActivity(limit: 50).where((e) {
      final at = e['at'] as DateTime;
      if (at.isBefore(from) || at.isAfter(to)) return false;
      if (staffId == null) return true;
      final member = store.members.where((m) => m.userId == staffId);
      if (member.isEmpty) return true;
      return e['by'] == member.first.displayName;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilterChipRow(
                labels: const ['Today', 'Week', 'Month', 'Custom'],
                selected: range,
                onSelected: (i) {
                  if (i == 3) {
                    _pickCustom();
                  } else {
                    setState(() => range = i);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: staffId,
                decoration: const InputDecoration(labelText: 'Staff filter'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All staff')),
                  ...store.members
                      .where((m) => m.isActive)
                      .map((m) => DropdownMenuItem(
                            value: m.userId,
                            child: Text(m.displayName),
                          )),
                ],
                onChanged: (v) => setState(() => staffId = v),
              ),
              if (range == 3 && customFrom != null && customTo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${DateFormat('d MMM yyyy').format(customFrom!)} → ${DateFormat('d MMM yyyy').format(customTo!)}',
                    style: const TextStyle(color: BizColors.muted),
                  ),
                ),
              const SizedBox(height: 16),
              SoftCard(
                child: Column(
                  children: [
                    _row('Sales', formatMoney(sales, symbol: sym),
                        BizColors.secondary),
                    const Divider(),
                    _row('Expenses', formatMoney(expenses, symbol: sym),
                        BizColors.highlight),
                    const Divider(),
                    _row('Estimated net', formatMoney(net, symbol: sym),
                        net >= 0 ? BizColors.primary : BizColors.danger),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Staff activity'),
              const SizedBox(height: 8),
              if (activity.isEmpty)
                const EmptyState(
                  icon: Icons.insights_outlined,
                  title: 'No activity in this range',
                )
              else
                ...activity.map((e) {
                  final isSale = e['type'] == 'sale';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ActivityTile(
                      icon: isSale
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      iconBg: isSale
                          ? BizColors.accent
                          : BizColors.highlight.withValues(alpha: 0.2),
                      iconColor:
                          isSale ? BizColors.primary : BizColors.highlight,
                      title: e['title'] as String,
                      subtitle:
                          '${e['by']} · ${friendlyDate(e['at'] as DateTime)}',
                      trailing:
                          '${isSale ? '+' : '-'}${formatMoney(e['amount'] as num, symbol: sym)}',
                      trailingColor:
                          isSale ? BizColors.secondary : BizColors.text,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18, color: color)),
        ],
      ),
    );
  }
}
