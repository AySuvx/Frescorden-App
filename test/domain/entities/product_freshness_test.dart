// test/domain/entities/product_freshness_test.dart
//
// BDD de ProductFreshness.fromDaysRemaining: mismo umbral que usaba
// status_badge.dart antes de trasladarse a dominio (<=3 días = "por
// vencer", <0 = vencido).

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/product_freshness.dart';

void main() {
  group('Historia de Usuario: Como usuario, quiero saber de un vistazo si '
      'un producto está fresco, por vencer o vencido', () {
    test('Escenario: un producto ya vencido es "expired"', () {
      expect(ProductFreshness.fromDaysRemaining(-1), ProductFreshness.expired);
      expect(ProductFreshness.fromDaysRemaining(-30), ProductFreshness.expired);
    });

    test('Escenario: vence hoy, mañana o dentro de 3 días es "expiringSoon"', () {
      expect(ProductFreshness.fromDaysRemaining(0), ProductFreshness.expiringSoon);
      expect(ProductFreshness.fromDaysRemaining(1), ProductFreshness.expiringSoon);
      expect(ProductFreshness.fromDaysRemaining(3), ProductFreshness.expiringSoon);
    });

    test('Escenario: a más de 3 días el producto sigue "fresh"', () {
      expect(ProductFreshness.fromDaysRemaining(4), ProductFreshness.fresh);
      expect(ProductFreshness.fromDaysRemaining(30), ProductFreshness.fresh);
    });
  });
}
