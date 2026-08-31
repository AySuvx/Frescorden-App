// lib/presentation/utils/currency_format.dart
//
// Formateo de montos en pesos colombianos, centralizado para que toda la
// app muestre el mismo formato (separador de miles con punto, sin
// decimales — ej. $ 65.000) en vez de interpolar el número crudo como
// hacían ShoppingListScreen y AnalyticsScreen antes.

import 'package:intl/intl.dart';

final NumberFormat _copFormat = NumberFormat.currency(
  locale: 'es_CO',
  symbol: '\$',
  decimalDigits: 0,
);

extension CopFormatting on num {
  /// Formatea como pesos colombianos con separador de miles, ej.
  /// `65000.asCop` -> `"\$ 65.000 COP"`.
  String get asCop => '${_copFormat.format(this)} COP';
}
