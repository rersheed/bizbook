import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/currency.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../widgets/widgets.dart';
import 'record_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  int filter = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sym = store.symbol;
    final now = DateTime.now();
    DateTime? from;
    if (filter == 1) from = DateTime(now.year, now.month, now.day);
    if (filter == 2) from = now.subtract(const Duration(days: 7));
    if (filter == 3) from = DateTime(now.year, now.month, 1);

    var list = store.expenses.toList()
      ..sort((a, b) => b.spentAt.compareTo(a.spentAt));
    if (!store.isOwner) {
      list = list.where((e) => e.recordedBy == store.currentUser!.id).toList();
    }
    if (from != null) {
      list = list.where((e) => !e.spentAt.isBefore(from!)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: BizColors.primary),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecordExpenseScreen()),
            ),
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
                child: FilterChipRow(
                  labels: const ['All', 'Today', 'Week', 'Month'],
                  selected: filter,
                  onSelected: (i) => setState(() => filter = i),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.payments_outlined,
                        title: 'No expenses yet',
                        subtitle: 'Track rent, utilities, transport, and more',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final e = list[i];
                          return SoftCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: BizColors.highlight
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_upward,
                                      color: BizColors.highlight),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(e.description,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      Text(
                                        '${e.categoryName ?? 'Other'} · ${e.recordedByName}',
                                        style: const TextStyle(
                                            color: BizColors.muted,
                                            fontSize: 12),
                                      ),
                                      Text(friendlyDate(e.spentAt),
                                          style: const TextStyle(
                                              color: BizColors.muted,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Text(
                                  '-${formatMoney(e.amount, symbol: sym)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
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
