import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../widgets/widgets.dart';
import 'add_credit_screen.dart';
import 'customer_detail_screen.dart';
import 'customers_screen.dart';
import 'record_repayment_screen.dart';

class CreditBookScreen extends StatelessWidget {
  const CreditBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sym = store.symbol;
    final owing = store.customersOwing;
    final outstanding = koboToMoney(store.outstandingKobo());
    final people = [...store.customers]
      ..sort((a, b) => store
          .outstandingKobo(customerId: b.id)
          .compareTo(store.outstandingKobo(customerId: a.id)));
    final recentCredits = store.credits.take(6).toList();
    final recentRepayments = store.repayments.take(6).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit'),
        actions: [
          IconButton(
            tooltip: 'Customers',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomersScreen()),
            ),
            icon: const Icon(Icons.people_outline),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: SoftCard(
                      color: BizColors.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customers owing',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('$owing',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Outstanding',
                              style: TextStyle(
                                  color: BizColors.muted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(formatMoney(outstanding, symbol: sym),
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
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
                            builder: (_) => const AddCreditScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.payments_outlined,
                      label: 'Record repayment',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RecordRepaymentScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'Customers'),
              const SizedBox(height: 8),
              if (people.isEmpty)
                const EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No customers yet',
                  subtitle: 'Add a customer when you give credit',
                )
              else
                ...people.map((c) {
                  final kobo = store.outstandingKobo(customerId: c.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftCard(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerDetailScreen(customerId: c.id),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                Text(
                                  (c.phone ?? '').isEmpty
                                      ? 'No phone'
                                      : c.phone!,
                                  style: const TextStyle(
                                      color: BizColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            kobo > 0
                                ? formatMoney(koboToMoney(kobo), symbol: sym)
                                : 'Clear',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: kobo > 0
                                  ? BizColors.highlight
                                  : BizColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              const SectionHeader(title: 'Recent credits'),
              const SizedBox(height: 8),
              if (recentCredits.isEmpty)
                const Text('No credits yet',
                    style: TextStyle(color: BizColors.muted))
              else
                ...recentCredits.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ActivityTile(
                        icon: Icons.credit_score,
                        iconBg: BizColors.highlight.withValues(alpha: 0.15),
                        iconColor: BizColors.highlight,
                        title: '${store.customerName(c.customerId)} · ${c.description}',
                        subtitle:
                            '${c.recordedByName} · ${friendlyDate(c.creditDate)} · ${c.status.name}',
                        trailing: formatMoney(c.outstandingAmount, symbol: sym),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CustomerDetailScreen(customerId: c.customerId),
                          ),
                        ),
                      ),
                    )),
              const SizedBox(height: 12),
              const SectionHeader(title: 'Recent repayments'),
              const SizedBox(height: 8),
              if (recentRepayments.isEmpty)
                const Text('No repayments yet',
                    style: TextStyle(color: BizColors.muted))
              else
                ...recentRepayments.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ActivityTile(
                        icon: Icons.south_west,
                        iconBg: BizColors.accent,
                        iconColor: BizColors.primary,
                        title:
                            '${store.customerName(r.customerId)} · ${store.creditById(r.creditId)?.description ?? 'Repayment'}',
                        subtitle:
                            '${r.recordedByName} · ${friendlyDate(r.repaymentDate)}',
                        trailing: formatMoney(r.amount, symbol: sym),
                        trailingColor: BizColors.secondary,
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
