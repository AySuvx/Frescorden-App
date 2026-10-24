// test/domain/entities/restock_prediction_test.dart
//
// BDD de RestockPrediction.urgency: aritmética simple sobre el historial
// (sin IA) que alimenta la tarjeta "Se te puede estar acabando" de
// InicioScreen — ver PredictRestockUseCase.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/restock_prediction.dart';

RestockPrediction _prediction({
  required int averageCycleDays,
  required int daysSinceEntry,
}) {
  return RestockPrediction(
    productName: 'Leche',
    category: FoodCategory.lacteos,
    unit: 'L',
    averageCycleDays: averageCycleDays,
    daysSinceEntry: daysSinceEntry,
  );
}

void main() {
  group('Historia de Usuario: Como usuario, quiero que la app me avise '
      'cuando se me puede estar acabando un producto', () {
    test(
      'Escenario: a mitad de su ciclo habitual, la urgencia es menor a 1',
      () {
        final prediction = _prediction(averageCycleDays: 10, daysSinceEntry: 5);

        expect(prediction.urgency, 0.5);
      },
    );

    test(
      'Escenario: justo al cumplirse el ciclo habitual, la urgencia es '
      'exactamente 1',
      () {
        final prediction = _prediction(averageCycleDays: 10, daysSinceEntry: 10);

        expect(prediction.urgency, 1.0);
      },
    );

    test(
      'Escenario: pasado el ciclo habitual, la urgencia supera 1',
      () {
        final prediction = _prediction(averageCycleDays: 10, daysSinceEntry: 20);

        expect(prediction.urgency, 2.0);
      },
    );

    test(
      'Escenario: un ciclo promedio de 0 días no causa división por cero',
      () {
        final prediction = _prediction(averageCycleDays: 0, daysSinceEntry: 5);

        expect(prediction.urgency, 1.0);
      },
    );
  });
}
