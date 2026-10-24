// test/notification_permission_gate_test.dart
//
// BDD de NotificationPermissionGate: solicita el permiso de notificaciones
// solo cuando falta y una sola vez por sesión, para no bloquear ni repetir
// el diálogo del sistema al programar alertas.

import 'package:flutter_test/flutter_test.dart';

import 'package:frescorden/presentation/utils/notification_permission_gate.dart';

void main() {
  group('Historia de Usuario: Como usuario, quiero que la app me pida '
      'permiso de notificaciones cuando lo necesita', () {
    late int enabledChecks;
    late int requests;

    NotificationPermissionGate buildGate({required bool enabled}) {
      enabledChecks = 0;
      requests = 0;
      return NotificationPermissionGate(
        isEnabled: () async {
          enabledChecks++;
          return enabled;
        },
        request: () async {
          requests++;
          return true;
        },
      );
    }

    test(
      'Escenario: si las notificaciones ya están permitidas, no vuelve a '
      'pedir el permiso',
      () async {
        final gate = buildGate(enabled: true);

        await gate.ensure();

        expect(enabledChecks, 1);
        expect(requests, 0);
      },
    );

    test(
      'Escenario: si las notificaciones están bloqueadas, pide el permiso',
      () async {
        final gate = buildGate(enabled: false);

        await gate.ensure();

        expect(requests, 1);
      },
    );

    test(
      'Escenario: pedir varias veces en la misma sesión solo abre un '
      'diálogo',
      () async {
        final gate = buildGate(enabled: false);

        await gate.ensure();
        await gate.ensure();
        await gate.ensure();

        expect(enabledChecks, 1);
        expect(requests, 1);
      },
    );
  });
}
