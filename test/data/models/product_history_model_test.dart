// test/data/models/product_history_model_test.dart
//
// BDD de ProductHistoryModel.toFirestore: traduce ProductHistoryEntry al
// mapa que se escribe en Firestore. fromFirestore no se prueba acá: su
// único parámetro es un DocumentSnapshot, una clase @sealed de
// cloud_firestore que el proyecto no tiene cómo simular sin el paquete
// fake_cloud_firestore (no es una dependencia actual).

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/data/models/product_history_model.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product_history_entry.dart';

void main() {
  group('Historia de Usuario: Como app, quiero guardar el historial de un '
      'producto resuelto en Firestore', () {
    test(
      'Escenario: una entrada consumida a tiempo, con precio, se traduce '
      'completa',
      () {
        final entry = ProductHistoryEntry(
          productId: 'prod-1',
          name: 'Leche',
          category: FoodCategory.lacteos,
          entryDate: DateTime(2026, 10, 1),
          expirationDate: DateTime(2026, 10, 10),
          resolvedAt: DateTime(2026, 10, 9),
          outcome: ProductOutcome.consumedOnTime,
          estimatedPrice: 5000,
        );

        final json = ProductHistoryModel.toFirestore(entry);

        expect(json['productId'], 'prod-1');
        expect(json['name'], 'Leche');
        expect(json['category'], FoodCategory.lacteos.name);
        expect(json['entryDate'], DateTime(2026, 10, 1).toIso8601String());
        expect(
          json['expirationDate'],
          DateTime(2026, 10, 10).toIso8601String(),
        );
        expect(json['resolvedAt'], DateTime(2026, 10, 9).toIso8601String());
        expect(json['outcome'], 'consumedOnTime');
        expect(json['estimatedPrice'], 5000);
      },
    );

    test(
      'Escenario: sin fecha de vencimiento ni precio estimado, esas claves '
      'se omiten en vez de guardarse como null',
      () {
        final entry = ProductHistoryEntry(
          productId: 'prod-2',
          name: 'Papa',
          category: FoodCategory.frutas,
          entryDate: DateTime(2026, 10, 1),
          expirationDate: null,
          resolvedAt: DateTime(2026, 10, 5),
          outcome: ProductOutcome.expired,
          estimatedPrice: null,
        );

        final json = ProductHistoryModel.toFirestore(entry);

        expect(json.containsKey('expirationDate'), isFalse);
        expect(json.containsKey('estimatedPrice'), isFalse);
        expect(json['outcome'], 'expired');
      },
    );
  });
}
