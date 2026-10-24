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

  group('Historia de Usuario: Como usuario, quiero elegir con cuántos días '
      'de antelación me avisa la app', () {
    // leadDays es estático y mutable (ver NotificationSettingsProvider):
    // se restaura después de cada prueba para no filtrar estado hacia las
    // pruebas de daysLeftInsideWindow de arriba (que asumen el valor 3).
    tearDown(() {
      ExpirationAlertPolicy.setLeadDays(ExpirationAlertPolicy.defaultLeadDays);
    });

    test('Escenario: un valor dentro del rango se aplica tal cual', () {
      ExpirationAlertPolicy.setLeadDays(5);

      expect(ExpirationAlertPolicy.leadDays, 5);
    });

    test('Escenario: un valor por debajo del mínimo se recorta al mínimo', () {
      ExpirationAlertPolicy.setLeadDays(0);

      expect(ExpirationAlertPolicy.leadDays, ExpirationAlertPolicy.minLeadDays);
    });

    test('Escenario: un valor por encima del máximo se recorta al máximo', () {
      ExpirationAlertPolicy.setLeadDays(30);

      expect(ExpirationAlertPolicy.leadDays, ExpirationAlertPolicy.maxLeadDays);
    });

    test(
      'Escenario: daysLeftInsideWindow usa el leadDays configurado, no un '
      '3 fijo',
      () {
        ExpirationAlertPolicy.setLeadDays(1);
        // Con leadDays=1, un vencimiento a 2 días todavía no entra en la
        // ventana (antes, con el 3 fijo, sí habría entrado).
        final expiryEn2Dias = DateTime(2026, 9, 25);
        expect(
          ExpirationAlertPolicy.daysLeftInsideWindow(expiryEn2Dias, now),
          isNull,
        );

        final expiryManana = DateTime(2026, 9, 24);
        expect(
          ExpirationAlertPolicy.daysLeftInsideWindow(expiryManana, now),
          1,
        );
      },
    );
  });
}
