import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/currency.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../widgets/widgets.dart';
import '../expenses/record_expense_screen.dart';
import '../sales/record_sale_screen.dart';
import '../sales/sale_detail_screen.dart';
import '../staff/staff_screen.dart';
import '../reports/reports_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sym = store.symbol;
    final isOwner = store.isOwner;
    final uid = isOwner ? null : store.currentUser?.id;

    final salesToday = store.salesToday(userId: uid);
    final salesMonth = store.salesMonth(userId: uid);
    final expToday = store.expensesToday(userId: uid);
    final expMonth = store.expensesMonth(userId: uid);
    final netMonth = salesMonth - expMonth;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset('assets/images/logo_64.png',
                              width: 40, height: 40),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${store.currentUser?.fullName.split(' ').first ?? ''}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${store.business?.name ?? 'BizBook'} · ${isOwner ? 'Owner' : 'Staff'}',
                                style: const TextStyle(
                                    color: BizColors.muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (isOwner)
                          IconButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const ReportsScreen()),
                            ),
                            icon: const Icon(Icons.bar_chart_rounded,
                                color: BizColors.primary),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: SoftCard(
                      color: BizColors.primary,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOwner ? 'This month net' : 'My sales today',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatMoney(isOwner ? netMonth : salesToday,
                                symbol: sym),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _metric('Sales today',
                                  formatMoney(salesToday, symbol: sym)),
                              _metric('Sales month',
                                  formatMoney(salesMonth, symbol: sym)),
                              _metric('Expenses',
                                  formatMoney(isOwner ? expMonth : expToday,
                                      symbol: sym)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isOwner)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: SoftCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Expenses today',
                                      style: TextStyle(
                                          color: BizColors.muted, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(formatMoney(expToday, symbol: sym),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SoftCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Staff active',
                                      style: TextStyle(
                                          color: BizColors.muted, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${store.members.where((m) => m.isActive).length}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: QuickActionButton(
                            icon: Icons.point_of_sale,
                            label: 'Record sale',
                            primary: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const RecordSaleScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: QuickActionButton(
                            icon: Icons.payments_outlined,
                            label: 'Record expense',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const RecordExpenseScreen()),
                            ),
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: QuickActionButton(
                              icon: Icons.group_outlined,
                              label: 'Staff',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const StaffScreen()),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                    child: SectionHeader(
                      title: isOwner ? 'Recent activity' : 'My recent activity',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        ...store
                            .staffActivity(limit: 10)
                            .where((e) =>
                                isOwner ||
                                e['by'] == store.currentUser?.fullName)
                            .map((e) {
                          final isSale = e['type'] == 'sale';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ActivityTile(
                              icon: isSale
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              iconBg: isSale
                                  ? BizColors.accent
                                  : BizColors.highlight.withValues(alpha: 0.2),
                              iconColor: isSale
                                  ? BizColors.primary
                                  : BizColors.highlight,
                              title: e['title'] as String,
                              subtitle:
                                  '${e['by']} · ${friendlyDate(e['at'] as DateTime)}',
                              trailing:
                                  '${isSale ? '+' : '-'}${formatMoney(e['amount'] as num, symbol: sym)}',
                              trailingColor:
                                  isSale ? BizColors.secondary : BizColors.text,
                              onTap: isSale
                                  ? () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SaleDetailScreen(
                                              saleId: e['id'] as String),
                                        ),
                                      )
                                  : null,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
