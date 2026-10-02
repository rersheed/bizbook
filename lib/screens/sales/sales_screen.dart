import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/currency.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../widgets/widgets.dart';
import 'record_sale_screen.dart';
import 'sale_detail_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  int filter = 0; // 0 all, 1 today, 2 week, 3 month

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sym = store.symbol;
    final now = DateTime.now();
    DateTime? from;
    if (filter == 1) from = DateTime(now.year, now.month, now.day);
    if (filter == 2) from = now.subtract(const Duration(days: 7));
    if (filter == 3) from = DateTime(now.year, now.month, 1);

    var list = store.sales.toList()
      ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
    if (!store.isOwner) {
      list = list.where((s) => s.recordedBy == store.currentUser!.id).toList();
    }
    if (from != null) {
      list = list.where((s) => !s.soldAt.isBefore(from!)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: BizColors.primary),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecordSaleScreen()),
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
                        icon: Icons.point_of_sale_outlined,
                        title: 'No sales yet',
                        subtitle: 'Tap + to record your first sale',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final s = list[i];
                          final names = s.items
                              .map((e) => '${e.productName} ×${e.quantity % 1 == 0 ? e.quantity.toInt() : e.quantity}')
                              .join(', ');
                          return SoftCard(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SaleDetailScreen(saleId: s.id),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        formatMoney(s.total, symbol: sym),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                          color: BizColors.secondary,
                                        ),
                                      ),
                                    ),
                                    Text(friendlyDate(s.soldAt),
                                        style: const TextStyle(
                                            color: BizColors.muted,
                                            fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(names,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline,
                                        size: 14, color: BizColors.muted),
                                    const SizedBox(width: 4),
                                    Text('Recorded by ${s.recordedByName}',
                                        style: const TextStyle(
                                            color: BizColors.muted,
                                            fontSize: 12)),
                                    const Spacer(),
                                    _syncDot(s.syncStatus.name),
                                  ],
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

  Widget _syncDot(String status) {
    final c = status == 'synced'
        ? BizColors.secondary
        : status == 'failed'
            ? BizColors.danger
            : BizColors.highlight;
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(status, style: TextStyle(color: c, fontSize: 11)),
      ],
    );
  }
}
