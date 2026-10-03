import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/currency.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class SaleDetailScreen extends StatelessWidget {
  final String saleId;
  const SaleDetailScreen({super.key, required this.saleId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sale = store.saleById(saleId);
    final sym = store.symbol;
    if (sale == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sale')),
        body: const EmptyState(icon: Icons.search_off, title: 'Sale not found'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Sale detail')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SoftCard(
                color: BizColors.primary,
                child: Column(
                  children: [
                    Text('Total',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(height: 4),
                    Text(formatMoney(sale.total, symbol: sym),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(friendlyDate(sale.soldAt),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recorded by',
                        style: TextStyle(color: BizColors.muted, fontSize: 12)),
                    Text(sale.recordedByName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    const Text('Payment',
                        style: TextStyle(color: BizColors.muted, fontSize: 12)),
                    Text(sale.paymentStatus.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (sale.customerId != null) ...[
                      const SizedBox(height: 8),
                      Text(store.customerName(sale.customerId),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                    if (sale.paymentStatus != PaymentStatus.paid) ...[
                      const SizedBox(height: 8),
                      Text(
                          'Paid ${formatMoney(sale.amountPaid, symbol: sym)} · on credit ${formatMoney(sale.amountOnCredit, symbol: sym)}'),
                    ],
                    if (sale.note != null && sale.note!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Note',
                          style:
                              TextStyle(color: BizColors.muted, fontSize: 12)),
                      Text(sale.note!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Items'),
              const SizedBox(height: 8),
              ...sale.items.map((it) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.productName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(
                                  '${it.quantity} × ${formatMoney(it.unitPrice, symbol: sym)}',
                                  style: const TextStyle(
                                      color: BizColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(formatMoney(it.lineTotal, symbol: sym),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
