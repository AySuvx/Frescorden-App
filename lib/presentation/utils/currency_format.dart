// lib/presentation/utils/currency_format.dart
//
// Formateo de montos en pesos colombianos, centralizado para que toda la
// app muestre el mismo formato (separador de miles con punto, sin
// decimales — ej. $ 65.000 COP) en vez de interpolar el número crudo como
// hacían ShoppingListScreen y AnalyticsScreen antes.
//
// FIX (hallado en prueba visual en dispositivo): NumberFormat.currency con
// locale 'es_CO' ubica el símbolo AL FINAL del monto ("65.000 $ COP"),
// siguiendo el patrón ICU de esa configuración regional — el parámetro
// `symbol` solo define qué símbolo usar, no dónde va. Para forzar
// "$ 65.000 COP" (símbolo al inicio, como se pidió explícitamente) se usa
// un NumberFormat de patrón fijo en vez de currency: mantiene el separador
// de miles con punto de es_CO, pero el orden queda bajo control nuestro.
import 'package:intl/intl.dart';

final NumberFormat _copFormat = NumberFormat('#,##0', 'es_CO');

extension CopFormatting on num {
  /// Formatea como pesos colombianos con separador de miles, ej.
  /// `65000.asCop` -> `"\$ 65.000 COP"`.
  String get asCop => '\$ ${_copFormat.format(this)} COP';
}
