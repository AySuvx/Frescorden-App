// test/domain/utils/expiration_alert_policy_test.dart
//
// BDD de ExpirationAlertPolicy: decide cuándo un producto ya está dentro de
// los 3 días previos a su vencimiento (donde la alerta programada ya no
// llega a tiempo) y cómo se describe el plazo que le queda.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/utils/expiration_alert_policy.dart';

void main() {
  final now = DateTime(2026, 9, 23, 15);

  group('Historia de Usuario: Como usuario, quiero que la app me avise si '
      'registro un producto que está por vencer', () {
    test('Escenario: sin fecha de vencimiento no hay aviso', () {
      expect(ExpirationAlertPolicy.daysLeftInsideWindow(null, now), isNull);
    });

    test(
      'Escenario: con vencimiento a más de 3 días se usa la alerta '
      'programada, no el aviso inmediato',
      () {
        final expiry = DateTime(2026, 9, 27);

        expect(ExpirationAlertPolicy.daysLeftInsideWindow(expiry, now), isNull);
      },
    );

    test('Escenario: vence en exactamente 3 días', () {
      final expiry = DateTime(2026, 9, 26);

      expect(ExpirationAlertPolicy.daysLeftInsideWindow(expiry, now), 3);
    });

    test('Escenario: vence en 2 días', () {
      final expiry = DateTime(2026, 9, 25);

      expect(ExpirationAlertPolicy.daysLeftInsideWindow(expiry, now), 2);
    });

    test('Escenario: vence mañana', () {
      final expiry = DateTime(2026, 9, 24);

      expect(ExpirationAlertPolicy.daysLeftInsideWindow(expiry, now), 1);
    });

    test('Escenario: vence hoy, aunque la hora de corte ya haya pasado', () {
      final expiry = DateTime(2026, 9, 23);

      expect(ExpirationAlertPolicy.daysLeftInsideWindow(expiry, now), 0);
    });

    test('Escenario: un producto ya vencido no genera aviso', () {
      final expiry = DateTime(2026, 9, 22);

      expect(ExpirationAlertPolicy.daysLeftInsideWindow(expiry, now), isNull);
    });

    test('Escenario: el plazo se describe en lenguaje natural', () {
      expect(ExpirationAlertPolicy.describe(0), 'hoy');
      expect(ExpirationAlertPolicy.describe(1), 'mañana');
      expect(ExpirationAlertPolicy.describe(3), 'en 3 días');
    });
  });
}
