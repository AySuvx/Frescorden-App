// test/presentation/utils/currency_format_test.dart
//
// BDD de CopFormatting.asCop: formato de moneda fijo pedido por el
// proyecto ($ 65.000 COP — símbolo al inicio, separador de miles con
// punto), ver CLAUDE.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/presentation/utils/currency_format.dart';

void main() {
  group('Historia de Usuario: Como usuario, quiero ver los montos en pesos '
      'colombianos con un formato consistente', () {
    test('Escenario: un monto redondo se formatea con separador de miles', () {
      expect(65000.asCop, '\$ 65.000 COP');
    });

    test('Escenario: cero se formatea igual que cualquier otro monto', () {
      expect(0.asCop, '\$ 0 COP');
    });

    test('Escenario: un monto decimal se redondea sin mostrar decimales', () {
      expect(1234.56.asCop, '\$ 1.235 COP');
    });

    test('Escenario: montos grandes usan varios separadores de miles', () {
      expect(1500000.asCop, '\$ 1.500.000 COP');
    });
  });
}
