import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
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
  String creditFilter = 'all';
  String? creditCustomerId;

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
    final activity = store.staffActivity(limit: 80).where((e) {
      final at = e['at'] as DateTime;
      if (at.isBefore(from) || !at.isBefore(to)) return false;
      if (staffId == null) return true;
      return e['userId'] == staffId;
    }).toList();
    final credits = store.credits.where((c) {
      if (c.creditDate.isBefore(from) || !c.creditDate.isBefore(to)) return false;
      if (creditCustomerId != null && c.customerId != creditCustomerId) {
        return false;
      }
      switch (creditFilter) {
        case 'unpaid':
          return c.status == CreditStatus.unpaid;
        case 'partial':
          return c.status == CreditStatus.partial;
        case 'paid':
          return c.status == CreditStatus.paid;
        case 'overdue':
          return c.isOverdue;
        default:
          return true;
      }
    }).toList();
    final repayments = store.repayments.where((rep) {
      if (rep.repaymentDate.isBefore(from) || !rep.repaymentDate.isBefore(to)) {
        return false;
      }
      if (creditCustomerId != null && rep.customerId != creditCustomerId) {
        return false;
      }
      return true;
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
                    _row('Net (sales − expenses)', formatMoney(net, symbol: sym),
                        net >= 0 ? BizColors.primary : BizColors.danger),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Credit'),
              const SizedBox(height: 8),
              FilterChipRow(
                labels: const ['All', 'Unpaid', 'Partial', 'Paid', 'Overdue'],
                selected: const ['all', 'unpaid', 'partial', 'paid', 'overdue']
                    .indexOf(creditFilter),
                onSelected: (i) => setState(() {
                  creditFilter = const [
                    'all',
                    'unpaid',
                    'partial',
                    'paid',
                    'overdue'
                  ][i];
                }),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: creditCustomerId,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All customers')),
                  ...store.customers.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )),
                ],
                onChanged: (v) => setState(() => creditCustomerId = v),
              ),
              const SizedBox(height: 8),
              if (credits.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No credits in this range',
                      style: TextStyle(color: BizColors.muted)),
                )
              else
                ...credits.map((c) {
                  final repaid = moneyToKobo(c.originalAmount) -
                      moneyToKobo(c.outstandingAmount);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.customerName(c.customerId),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(c.description,
                              style: const TextStyle(color: BizColors.muted)),
                          const SizedBox(height: 6),
                          Text(
                            'Original ${formatMoney(c.originalAmount, symbol: sym)} · repaid ${formatMoney(koboToMoney(repaid < 0 ? 0 : repaid), symbol: sym)} · outstanding ${formatMoney(c.outstandingAmount, symbol: sym)}',
                          ),
                          Text(
                            '${c.status.name}${c.dueDate == null ? '' : ' · due ${DateFormat('d MMM yyyy').format(c.dueDate!)}'}${c.isOverdue ? ' · overdue' : ''} · ${c.recordedByName}',
                            style: const TextStyle(
                                color: BizColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Repayments'),
              const SizedBox(height: 8),
              if (repayments.isEmpty)
                const Text('No repayments in this range',
                    style: TextStyle(color: BizColors.muted))
              else
                ...repayments.map((rep) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ActivityTile(
                        icon: Icons.south_west,
                        iconBg: BizColors.accent,
                        iconColor: BizColors.primary,
                        title:
                            '${store.customerName(rep.customerId)} · ${store.creditById(rep.creditId)?.description ?? 'Repayment'}',
                        subtitle:
                            '${rep.recordedByName} · ${friendlyDate(rep.repaymentDate)}',
                        trailing: formatMoney(rep.amount, symbol: sym),
                        trailingColor: BizColors.secondary,
                      ),
                    )),
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
