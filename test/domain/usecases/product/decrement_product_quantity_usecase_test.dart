// test/domain/usecases/product/decrement_product_quantity_usecase_test.dart
//
// BDD (Given/When/Then) de DecrementProductQuantityUseCase, con dobles de
// prueba en vez de Firestore.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/usecases/product/decrement_product_quantity_usecase.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fake_services.dart';

Product _product({int quantity = 3, int? minStock}) {
  return Product(
    id: 'p1',
    name: 'Arroz',
    quantity: quantity,
    unit: 'unidad',
    entryDate: DateTime(2026, 1, 1),
    category: FoodCategory.otros,
    minStock: minStock,
  );
}

void main() {
  group('Historia de Usuario: Como usuario, quiero descontar una unidad '
      'de un producto sin retirarlo del todo', () {
    late FakeProductRepository repo;
    late FakeNotificationService notifications;
    late DecrementProductQuantityUseCase useCase;

    setUp(() {
      repo = FakeProductRepository();
      notifications = FakeNotificationService();
      useCase = DecrementProductQuantityUseCase(repo, notifications);
    });

    test(
      'Escenario: caso válido — se descuenta una unidad y se persiste',
      () async {
        final result = await useCase('hogar-1', _product(quantity: 3));

        expect(result?.quantity, 2);
        expect(repo.updated, hasLength(1));
      },
    );

    test(
      'Escenario: la cantidad ya está en cero — no hace nada',
      () async {
        final result = await useCase('hogar-1', _product(quantity: 0));

        expect(result, isNull);
        expect(repo.updated, isEmpty);
      },
    );

    test(
      'Escenario: el descuento cruza el umbral de stock bajo — se '
      'dispara la alerta',
      () async {
        final result = await useCase(
          'hogar-1',
          _product(quantity: 2, minStock: 1),
        );

        expect(result?.isLowStock, isTrue);
        expect(notifications.lowStockAlerts, hasLength(1));
      },
    );

    test(
      'Escenario: el producto ya estaba en stock bajo — no se repite la '
      'alerta',
      () async {
        await useCase('hogar-1', _product(quantity: 1, minStock: 1));

        expect(notifications.lowStockAlerts, isEmpty);
      },
    );

    test(
      'Escenario: el repositorio genera un error al actualizar',
      () async {
        repo.updateProductError = Exception('sin conexión');

        await expectLater(
          () => useCase('hogar-1', _product(quantity: 3)),
          throwsA(isException),
        );
      },
    );
  });
}
