// test/domain/entities/activity_log_entry_test.dart
//
// BDD de ActivityActionLabel: cada ActivityAction tiene una etiqueta en
// español lista para mostrar en el Historial de Actividad (ver
// HouseholdScreen._buildActivityTile).

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/activity_log_entry.dart';

void main() {
  group('Historia de Usuario: Como miembro de un hogar, quiero ver el '
      'historial de actividad en español', () {
    test('Escenario: cada acción tiene su etiqueta correspondiente', () {
      expect(ActivityAction.creado.label, 'Creado');
      expect(ActivityAction.editado.label, 'Editado');
      expect(ActivityAction.consumido.label, 'Consumido');
      expect(ActivityAction.eliminado.label, 'Eliminado');
      expect(ActivityAction.desperdiciado.label, 'Desperdiciado');
    });

    test('Escenario: una entrada guarda sus datos tal cual se construyó', () {
      final timestamp = DateTime(2026, 10, 15, 12);
      final entry = ActivityLogEntry(
        productName: 'Leche',
        action: ActivityAction.consumido,
        userEmail: 'ana@frescorden.app',
        timestamp: timestamp,
      );

      expect(entry.productName, 'Leche');
      expect(entry.action, ActivityAction.consumido);
      expect(entry.userEmail, 'ana@frescorden.app');
      expect(entry.timestamp, timestamp);
    });

    test('Escenario: el email del miembro es opcional', () {
      final entry = ActivityLogEntry(
        productName: 'Arroz',
        action: ActivityAction.creado,
        timestamp: DateTime(2026, 10, 15),
      );

      expect(entry.userEmail, isNull);
    });
  });
}
