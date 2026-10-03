import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../widgets/widgets.dart';
import '../sales/sale_detail_screen.dart';
import 'add_credit_screen.dart';
import 'customers_screen.dart';
import 'record_repayment_screen.dart';

class CustomerDetailScreen extends StatelessWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final customer = store.customerById(customerId);
    final sym = store.symbol;
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer')),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Customer not found',
        ),
      );
    }
    final credits = store.credits
        .where((c) => c.customerId == customer.id)
        .toList()
      ..sort((a, b) => b.creditDate.compareTo(a.creditDate));
    final repayments = store.repayments
        .where((r) => r.customerId == customer.id)
        .toList()
      ..sort((a, b) => b.repaymentDate.compareTo(a.repaymentDate));
    final sales = store.sales
        .where((s) => s.customerId == customer.id)
        .toList()
      ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
    final owing = koboToMoney(store.outstandingKobo(customerId: customer.id));
    final date = DateFormat('d MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          if (store.isOwner)
            IconButton(
              tooltip: 'Edit customer',
              onPressed: () =>
                  showCustomerEditor(context, existing: customer),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SoftCard(
                color: BizColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Outstanding',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(height: 4),
                    Text(formatMoney(owing, symbol: sym),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    if ((customer.phone ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(customer.phone!,
                          style: const TextStyle(color: Colors.white)),
                    ],
                    if ((customer.note ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(customer.note!,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.playlist_add,
                      label: 'Add credit',
                      primary: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AddCreditScreen(customerId: customer.id),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.payments_outlined,
                      label: 'Record repayment',
                      onTap: () {
                        final open = store.openCredits(customerId: customer.id);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecordRepaymentScreen(
                              creditId: open.isEmpty ? null : open.first.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'Credits'),
              const SizedBox(height: 8),
              if (credits.isEmpty)
                const Text('No credits', style: TextStyle(color: BizColors.muted))
              else
                ...credits.map((c) {
                  final repaid = moneyToKobo(c.originalAmount) -
                      moneyToKobo(c.outstandingAmount);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(c.description,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                              ),
                              Text(c.status.name,
                                  style: const TextStyle(
                                      color: BizColors.primary,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${c.recordedByName} · ${friendlyDate(c.creditDate)}'
                            '${c.dueDate == null ? '' : ' · due ${date.format(c.dueDate!)}'}'
                            '${c.isOverdue ? ' · overdue' : ''}',
                            style: const TextStyle(
                                color: BizColors.muted, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Original ${formatMoney(c.originalAmount, symbol: sym)} · repaid ${formatMoney(koboToMoney(repaid < 0 ? 0 : repaid), symbol: sym)} · left ${formatMoney(c.outstandingAmount, symbol: sym)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (moneyToKobo(c.outstandingAmount) > 0)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RecordRepaymentScreen(
                                        creditId: c.id),
                                  ),
                                ),
                                child: const Text('Record repayment'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              const SectionHeader(title: 'Repayments'),
              const SizedBox(height: 8),
              if (repayments.isEmpty)
                const Text('No repayments',
                    style: TextStyle(color: BizColors.muted))
              else
                ...repayments.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ActivityTile(
                        icon: Icons.south_west,
                        iconBg: BizColors.accent,
                        iconColor: BizColors.primary,
                        title: store.creditById(r.creditId)?.description ??
                            'Repayment',
                        subtitle:
                            '${r.recordedByName} · ${friendlyDate(r.repaymentDate)}',
                        trailing: formatMoney(r.amount, symbol: sym),
                        trailingColor: BizColors.secondary,
                      ),
                    )),
              const SizedBox(height: 12),
              const SectionHeader(title: 'Sales'),
              const SizedBox(height: 8),
              if (sales.isEmpty)
                const Text('No linked sales',
                    style: TextStyle(color: BizColors.muted))
              else
                ...sales.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ActivityTile(
                        icon: Icons.point_of_sale_outlined,
                        iconBg: BizColors.accent,
                        iconColor: BizColors.primary,
                        title: s.items
                            .map((i) => i.productName)
                            .take(2)
                            .join(', '),
                        subtitle:
                            '${s.recordedByName} · ${friendlyDate(s.soldAt)} · ${s.paymentStatus.name}',
                        trailing: formatMoney(s.total, symbol: sym),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SaleDetailScreen(saleId: s.id),
                          ),
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
