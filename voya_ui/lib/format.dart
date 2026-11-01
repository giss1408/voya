import 'package:intl/intl.dart';

final _money = NumberFormat.decimalPattern('fr_FR');

/// `3 500 FCFA` (West African CFA franc, no decimals).
String formatFare(num amount) => '${_money.format(amount.round())} FCFA';
