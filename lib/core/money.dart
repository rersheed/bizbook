/// Naira amounts stay numeric in Postgres. The UI still uses the app's
/// existing double fields, but splits and compares money in kobo so
/// paid + on credit cannot drift away from the sale total.
int moneyToKobo(num value) => (value * 100).round();

double koboToMoney(int kobo) => kobo / 100.0;

/// Canonical numeric literal for PostgREST so Postgres numeric checks
/// see exact kobo, not a binary float.
String koboToNumeric(int kobo) {
  final sign = kobo < 0 ? '-' : '';
  final absKobo = kobo.abs();
  final whole = absKobo ~/ 100;
  final frac = (absKobo % 100).toString().padLeft(2, '0');
  return '$sign$whole.$frac';
}

int lineKobo(num quantity, num unitPrice) =>
    (quantity * unitPrice * 100).round();
