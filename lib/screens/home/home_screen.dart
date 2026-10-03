import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../widgets/widgets.dart';
import '../credit/add_credit_screen.dart';
import '../credit/customer_detail_screen.dart';
import '../credit/record_repayment_screen.dart';
import '../expenses/record_expense_screen.dart';
import '../reports/reports_screen.dart';
import '../sales/record_sale_screen.dart';
import '../sales/sale_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return store.isOwner ? const _OwnerHome() : const _StaffHome();
  }
}

class _OwnerHome extends StatelessWidget {
  const _OwnerHome();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sym = store.symbol;
    final salesToday = store.salesToday();
    final salesMonth = store.salesMonth();
    final expToday = store.expensesToday();
    final expMonth = store.expensesMonth();
    final netToday = salesToday - expToday;
    final netMonth = salesMonth - expMonth;
    final outstanding = koboToMoney(store.outstandingKobo());

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _hello(context, store, owner: true),
                const SizedBox(height: 16),
                SoftCard(
                  color: BizColors.primary,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This month net',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(formatMoney(netMonth, symbol: sym),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('Today net ${formatMoney(netToday, symbol: sym)}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85))),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _metric('Sales today',
                              formatMoney(salesToday, symbol: sym)),
                          _metric('Sales month',
                              formatMoney(salesMonth, symbol: sym)),
                          _metric('Expenses',
                              formatMoney(expMonth, symbol: sym)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _stat('Expenses today', formatMoney(expToday, symbol: sym))),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Outstanding credit', formatMoney(outstanding, symbol: sym))),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Customers owing', '${store.customersOwing}')),
                  ],
                ),
                const SizedBox(height: 16),
                _actions(context),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Recent sales'),
                const SizedBox(height: 8),
                ..._saleTiles(context, store, sym, store.recentSales(limit: 5)),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Recent expenses'),
                const SizedBox(height: 8),
                ..._expenseTiles(store, sym, store.recentExpenses(limit: 5)),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Credit activity'),
                const SizedBox(height: 8),
                ..._creditTiles(context, store, sym),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Staff activity'),
                const SizedBox(height: 8),
                ..._activityTiles(context, store, sym, store.staffActivity(limit: 8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffHome extends StatelessWidget {
  const _StaffHome();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sym = store.symbol;
    final uid = store.currentUser?.id;
    final salesToday = store.salesToday(userId: uid);
    final expToday = store.expensesToday(userId: uid);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _hello(context, store, owner: false),
                const SizedBox(height: 16),
                SoftCard(
                  color: BizColors.primary,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My sales today',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85))),
                      const SizedBox(height: 6),
                      Text(formatMoney(salesToday, symbol: sym),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                        'My expenses today ${formatMoney(expToday, symbol: sym)}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _actions(context),
                const SizedBox(height: 20),
                const SectionHeader(title: 'My recent activity'),
                const SizedBox(height: 8),
                ..._activityTiles(
                  context,
                  store,
                  sym,
                  store.staffActivity(limit: 12, userId: uid),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _hello(BuildContext context, AppStore store, {required bool owner}) {
  return Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/images/logo_64.png', width: 40, height: 40),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${store.currentUser?.fullName.split(' ').first ?? ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              '${store.business?.name ?? 'BizBook'} · ${owner ? 'Owner' : 'Staff'}',
              style: const TextStyle(color: BizColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
      if (owner)
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ReportsScreen()),
          ),
          icon: const Icon(Icons.bar_chart_rounded, color: BizColors.primary),
        ),
    ],
  );
}

Widget _actions(BuildContext context) {
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: QuickActionButton(
              icon: Icons.point_of_sale,
              label: 'Record sale',
              primary: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecordSaleScreen()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: QuickActionButton(
              icon: Icons.payments_outlined,
              label: 'Record expense',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecordExpenseScreen()),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: QuickActionButton(
              icon: Icons.playlist_add,
              label: 'Add credit',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddCreditScreen()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: QuickActionButton(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Repayment',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const RecordRepaymentScreen()),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _stat(String label, String value) {
  return SoftCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: BizColors.muted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      ],
    ),
  );
}

Widget _metric(String label, String value) {
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    ),
  );
}

List<Widget> _saleTiles(
    BuildContext context, AppStore store, String sym, List sales) {
  if (sales.isEmpty) {
    return const [
      Text('No sales yet', style: TextStyle(color: BizColors.muted))
    ];
  }
  return [
    for (final s in sales)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ActivityTile(
          icon: Icons.point_of_sale_outlined,
          iconBg: BizColors.accent,
          iconColor: BizColors.primary,
          title: s.items.isEmpty
              ? 'Sale'
              : s.items.map((i) => i.productName).take(2).join(', '),
          subtitle: '${s.recordedByName} · ${friendlyDate(s.soldAt)}',
          trailing: '+${formatMoney(s.total, symbol: sym)}',
          trailingColor: BizColors.secondary,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SaleDetailScreen(saleId: s.id),
            ),
          ),
        ),
      ),
  ];
}

List<Widget> _expenseTiles(AppStore store, String sym, List expenses) {
  if (expenses.isEmpty) {
    return const [
      Text('No expenses yet', style: TextStyle(color: BizColors.muted))
    ];
  }
  return [
    for (final e in expenses)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ActivityTile(
          icon: Icons.arrow_upward,
          iconBg: BizColors.highlight.withValues(alpha: 0.2),
          iconColor: BizColors.highlight,
          title: e.description,
          subtitle: '${e.recordedByName} · ${friendlyDate(e.spentAt)}',
          trailing: '-${formatMoney(e.amount, symbol: sym)}',
        ),
      ),
  ];
}

List<Widget> _creditTiles(BuildContext context, AppStore store, String sym) {
  final events = <Map<String, dynamic>>[
    for (final c in store.credits.take(5))
      {
        'kind': 'credit',
        'title': '${store.customerName(c.customerId)} · ${c.description}',
        'by': c.recordedByName,
        'at': c.creditDate,
        'amount': c.originalAmount,
        'customerId': c.customerId,
      },
    for (final r in store.repayments.take(5))
      {
        'kind': 'repayment',
        'title':
            '${store.customerName(r.customerId)} · ${store.creditById(r.creditId)?.description ?? 'Repayment'}',
        'by': r.recordedByName,
        'at': r.repaymentDate,
        'amount': r.amount,
        'customerId': r.customerId,
      },
  ]..sort((a, b) => (b['at'] as DateTime).compareTo(a['at'] as DateTime));
  if (events.isEmpty) {
    return const [
      Text('No credit activity yet', style: TextStyle(color: BizColors.muted))
    ];
  }
  return [
    for (final e in events.take(6))
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ActivityTile(
          icon: e['kind'] == 'repayment'
              ? Icons.south_west
              : Icons.credit_score,
          iconBg: e['kind'] == 'repayment'
              ? BizColors.accent
              : BizColors.highlight.withValues(alpha: 0.15),
          iconColor: e['kind'] == 'repayment'
              ? BizColors.primary
              : BizColors.highlight,
          title: e['title'] as String,
          subtitle: '${e['by']} · ${friendlyDate(e['at'] as DateTime)}',
          trailing: formatMoney(e['amount'] as num, symbol: sym),
          trailingColor: e['kind'] == 'repayment'
              ? BizColors.secondary
              : BizColors.text,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerDetailScreen(
                  customerId: e['customerId'] as String),
            ),
          ),
        ),
      ),
  ];
}

List<Widget> _activityTiles(BuildContext context, AppStore store, String sym,
    List<Map<String, dynamic>> events) {
  if (events.isEmpty) {
    return const [
      Text('No activity yet', style: TextStyle(color: BizColors.muted))
    ];
  }
  return [
    for (final e in events)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ActivityTile(
          icon: _iconFor(e['type'] as String),
          iconBg: e['type'] == 'expense'
              ? BizColors.highlight.withValues(alpha: 0.2)
              : BizColors.accent,
          iconColor: e['type'] == 'expense'
              ? BizColors.highlight
              : BizColors.primary,
          title: e['title'] as String,
          subtitle: '${e['by']} · ${friendlyDate(e['at'] as DateTime)}',
          trailing: _trail(e, sym),
          trailingColor:
              e['type'] == 'sale' ? BizColors.secondary : BizColors.text,
          onTap: e['type'] == 'sale'
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SaleDetailScreen(saleId: e['id'] as String),
                    ),
                  )
              : null,
        ),
      ),
  ];
}

IconData _iconFor(String type) {
  switch (type) {
    case 'expense':
      return Icons.arrow_upward;
    case 'credit':
      return Icons.credit_score;
    case 'repayment':
      return Icons.south_west;
    default:
      return Icons.arrow_downward;
  }
}

String _trail(Map<String, dynamic> event, String sym) {
  final money = formatMoney(event['amount'] as num, symbol: sym);
  switch (event['type']) {
    case 'sale':
      return '+$money';
    case 'expense':
      return '-$money';
    case 'repayment':
      return money;
    default:
      return money;
  }
}
