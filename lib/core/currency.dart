import 'package:intl/intl.dart';

String formatMoney(num amount, {String symbol = '₦'}) {
  final fmt = NumberFormat('#,##0.00');
  return '$symbol${fmt.format(amount)}';
}

String formatMoneyCompact(num amount, {String symbol = '₦'}) {
  if (amount.abs() >= 1000000) {
    return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount.abs() >= 1000) {
    return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
  }
  return formatMoney(amount, symbol: symbol);
}
