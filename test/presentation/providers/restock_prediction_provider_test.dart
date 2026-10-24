// test/presentation/providers/restock_prediction_provider_test.dart
//
// BDD de RestockPredictionProvider con FirestoreProductHistoryDataSource
// mockeado vía mocktail (mismo patrón que auth_repository_impl_test.dart:
// mockear la clase concreta en el seno, no Firestore completo).

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frescorden/data/datasources/firestore_product_history_datasource.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/entities/product_history_entry.dart';
import 'package:frescorden/presentation/providers/restock_prediction_provider.dart';

class MockHistoryDataSource extends Mock
    implements FirestoreProductHistoryDataSource {}

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

Product _product({required String name, required int daysSinceEntry}) {
  return Product(
    id: 'inv-$name',
    name: name,
    quantity: 1,
    unit: 'L',
    entryDate: _now.subtract(Duration(days: daysSinceEntry)),
  );
}

void main() {
  late MockHistoryDataSource dataSource;

  setUp(() {
    dataSource = MockHistoryDataSource();
  });

  group('Historia de Usuario: Como usuario, quiero ver predicciones de '
      'reposición basadas en mi historial real de consumo', () {
    test(
      'Escenario: antes de tener un hogar activo, predict() no arroja '
      'predicciones (no hay historial cargado)',
      () {
        final provider = RestockPredictionProvider(dataSource);

        final result = provider.predict([
          _product(name: 'Leche', daysSinceEntry: 8),
        ]);

        expect(result, isEmpty);
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'Escenario: al activar un hogar, carga su historial y predict() ya '
      'refleja esos datos',
      () async {
        when(() => dataSource.getAll('hogar-1')).thenAnswer(
          (_) async => [
            _historyEntry('Leche', 20),
            _historyEntry('Leche', 10),
          ],
        );
        final provider = RestockPredictionProvider(dataSource);

        provider.setActiveHousehold('hogar-1');
        // _loadHistory es async (unawaited) — esperar a que resuelva.
        await Future<void>.delayed(Duration.zero);

        final result = provider.predict([
          _product(name: 'Leche', daysSinceEntry: 8),
        ]);

        expect(result, hasLength(1));
        expect(result.first.productName, 'Leche');
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'Escenario: cambiar a un hogar sin id (null) limpia el historial '
      'cargado',
      () async {
        when(() => dataSource.getAll('hogar-1')).thenAnswer(
          (_) async => [
            _historyEntry('Leche', 20),
            _historyEntry('Leche', 10),
          ],
        );
        final provider = RestockPredictionProvider(dataSource);
        provider.setActiveHousehold('hogar-1');
        await Future<void>.delayed(Duration.zero);

        provider.setActiveHousehold(null);

        final result = provider.predict([
          _product(name: 'Leche', daysSinceEntry: 8),
        ]);
        expect(result, isEmpty);
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'Escenario: activar el mismo hogar dos veces no vuelve a consultar '
      'el historial',
      () async {
        when(() => dataSource.getAll('hogar-1')).thenAnswer(
          (_) async => [
            _historyEntry('Leche', 20),
            _historyEntry('Leche', 10),
          ],
        );
        final provider = RestockPredictionProvider(dataSource);

        provider.setActiveHousehold('hogar-1');
        await Future<void>.delayed(Duration.zero);
        provider.setActiveHousehold('hogar-1');
        await Future<void>.delayed(Duration.zero);

        verify(() => dataSource.getAll('hogar-1')).called(1);
      },
    );

    test(
      'Escenario: si el repositorio falla al cargar el historial, '
      'predict() no lanza excepción y simplemente no hay predicciones',
      () async {
        when(() => dataSource.getAll('hogar-1'))
            .thenThrow(Exception('sin conexión'));
        final provider = RestockPredictionProvider(dataSource);

        provider.setActiveHousehold('hogar-1');
        await Future<void>.delayed(Duration.zero);

        expect(provider.isLoading, isFalse);
        expect(
          provider.predict([_product(name: 'Leche', daysSinceEntry: 8)]),
          isEmpty,
        );
      },
    );
  });
}
