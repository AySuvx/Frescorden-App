// test/domain/usecases/predict_restock_usecase_test.dart
//
// BDD (Given/When/Then) de PredictRestockUseCase: aritmética pura sobre
// el historial del hogar (sin IA) que alimenta la tarjeta "Se te puede
// estar acabando" de InicioScreen — ver RestockPredictionProvider.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/entities/product_history_entry.dart';
import 'package:frescorden/domain/usecases/predict_restock_usecase.dart';

final _now = DateTime.now();

ProductHistoryEntry _historyEntry(String name, int daysAgoEntered) {
  return ProductHistoryEntry(
    productId: 'id-$name-$daysAgoEntered',
    name: name,
    category: FoodCategory.lacteos,
    entryDate: _now.subtract(Duration(days: daysAgoEntered)),
    resolvedAt: _now.subtract(Duration(days: daysAgoEntered - 1)),
    outcome: ProductOutcome.consumedOnTime,
  );
}

Product _product({
  required String name,
  required int daysSinceEntry,
  String unit = 'L',
}) {
  return Product(
    id: 'inv-$name',
    name: name,
    quantity: 1,
    unit: unit,
    entryDate: _now.subtract(Duration(days: daysSinceEntry)),
  );
}

void main() {
  const useCase = PredictRestockUseCase();

  group('Historia de Usuario: Como usuario, quiero que la app me avise '
      'cuando se me puede estar acabando un producto, sin usar IA', () {
    test(
      'Escenario: sin historial, no hay predicciones',
      () {
        final result = useCase(
          history: const [],
          inventory: [_product(name: 'Leche', daysSinceEntry: 8)],
        );

        expect(result, isEmpty);
      },
    );

    test(
      'Escenario: un producto del inventario sin historial propio no '
      'genera predicción',
      () {
        final result = useCase(
          history: [_historyEntry('Leche', 20), _historyEntry('Leche', 10)],
          inventory: [_product(name: 'Queso', daysSinceEntry: 8)],
        );

        expect(result, isEmpty);
      },
    );

    test(
      'Escenario: con una sola entrada histórica no hay ciclo que '
      'promediar, así que no se genera predicción',
      () {
        final result = useCase(
          history: [_historyEntry('Pan', 10)],
          inventory: [_product(name: 'Pan', daysSinceEntry: 8)],
        );

        expect(result, isEmpty);
      },
    );

    test(
      'Escenario: todavía no se cumple el 75% del ciclo habitual, no se '
      'muestra la predicción',
      () {
        // Ciclo promedio: 10 días (entradas en -20 y -10).
        final result = useCase(
          history: [_historyEntry('Leche', 20), _historyEntry('Leche', 10)],
          inventory: [_product(name: 'Leche', daysSinceEntry: 5)], // 50%
        );

        expect(result, isEmpty);
      },
    );

    test(
      'Escenario: pasado el 75% del ciclo habitual, se muestra la '
      'predicción con el ciclo promedio calculado',
      () {
        // Ciclo promedio: 10 días (entradas en -20 y -10).
        final result = useCase(
          history: [_historyEntry('Leche', 20), _historyEntry('Leche', 10)],
          inventory: [_product(name: 'Leche', daysSinceEntry: 8)], // 80%
        );

        expect(result, hasLength(1));
        expect(result.first.productName, 'Leche');
        expect(result.first.averageCycleDays, 10);
        expect(result.first.daysSinceEntry, 8);
      },
    );

    test(
      'Escenario: la coincidencia con el historial ignora mayúsculas y '
      'espacios en el nombre',
      () {
        final result = useCase(
          history: [_historyEntry('  LECHE  ', 20), _historyEntry('leche', 10)],
          inventory: [_product(name: 'Leche', daysSinceEntry: 8)],
        );

        expect(result, hasLength(1));
      },
    );

    test(
      'Escenario: con varios productos atrasados, se ordenan de mayor a '
      'menor urgencia',
      () {
        final result = useCase(
          history: [
            _historyEntry('Leche', 20),
            _historyEntry('Leche', 10), // ciclo 10, producto actual 80%
            _historyEntry('Huevos', 12),
            _historyEntry('Huevos', 6), // ciclo 6, producto actual 100%
          ],
          inventory: [
            _product(name: 'Leche', daysSinceEntry: 8),
            _product(name: 'Huevos', daysSinceEntry: 6, unit: 'docena'),
          ],
        );

        expect(result, hasLength(2));
        expect(result.first.productName, 'Huevos');
        expect(result.last.productName, 'Leche');
      },
    );

    test(
      'Escenario: un ciclo promedio calculado en 0 días se descarta (no '
      'aporta una predicción confiable)',
      () {
        // Dos entradas el mismo día -> intervalo de 0 días.
        final result = useCase(
          history: [_historyEntry('Agua', 5), _historyEntry('Agua', 5)],
          inventory: [_product(name: 'Agua', daysSinceEntry: 5)],
        );

        expect(result, isEmpty);
      },
    );
  });
}
