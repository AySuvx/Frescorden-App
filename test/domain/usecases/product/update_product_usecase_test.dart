// test/domain/usecases/product/update_product_usecase_test.dart
//
// BDD (Given/When/Then) de UpdateProductUseCase, siguiendo el formato de la
// Sección 26 de la guía (caso válido / cantidad inválida / repositorio
// genera error), con dobles de prueba en vez de Firestore.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/requests/save_product_request.dart';
import 'package:frescorden/domain/usecases/product/update_product_usecase.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fake_services.dart';

Product _product(String id, {int quantity = 1, int? minStock}) {
  return Product(
    id: id,
    name: 'Arroz',
    quantity: quantity,
    unit: 'unidad',
    entryDate: DateTime(2026, 1, 1),
    category: FoodCategory.otros,
    minStock: minStock,
  );
}

SaveProductRequest _request({
  String? id = 'p1',
  int quantity = 1,
  int? minStock,
}) {
  return SaveProductRequest(
    id: id,
    name: 'Arroz',
    quantity: quantity,
    unit: 'unidad',
    entryDate: DateTime(2026, 1, 1),
    minStock: minStock,
  );
}

void main() {
  group('Historia de Usuario: Como usuario, quiero editar un producto ya '
      'registrado en mi inventario', () {
    late FakeProductRepository repo;
    late FakeNotificationService notifications;
    late UpdateProductUseCase useCase;

    setUp(() {
      repo = FakeProductRepository();
      notifications = FakeNotificationService();
      useCase = UpdateProductUseCase(repo, notifications);
    });

    test(
      'Escenario: caso válido — se actualiza el producto y se reprograman '
      'sus alertas',
      () async {
        // Cuando se edita el producto con datos válidos
        final result = await useCase('hogar-1', _request(quantity: 4));

        // Entonces se persiste la actualización y se reprograman sus alertas
        expect(result.quantity, 4);
        expect(repo.updated, hasLength(1));
        expect(notifications.expirationAlerts, hasLength(1));
        expect(notifications.bulkStorageAlerts, hasLength(1));
      },
    );

    test(
      'Escenario: cantidad inválida — se rechaza antes de tocar el '
      'repositorio',
      () async {
        await expectLater(
          () => useCase('hogar-1', _request(quantity: 0)),
          throwsA(isA<Exception>()),
        );
        expect(repo.updated, isEmpty);
      },
    );

    test(
      'Escenario: falta el id de la petición — error de programación, no '
      'de negocio',
      () async {
        await expectLater(
          () => useCase('hogar-1', _request(id: null)),
          throwsA(isA<ArgumentError>()),
        );
        expect(repo.updated, isEmpty);
      },
    );

    test(
      'Escenario: el repositorio genera un error al actualizar',
      () async {
        repo.updateProductError = Exception('sin conexión');

        await expectLater(
          () => useCase('hogar-1', _request()),
          throwsA(isException),
        );
        expect(notifications.expirationAlerts, isEmpty);
      },
    );

    test(
      'Escenario: la edición cruza el umbral de stock bajo — se dispara '
      'la alerta inmediata',
      () async {
        // Dado el estado anterior del producto, todavía por encima del umbral
        final previous = _product('p1', quantity: 5, minStock: 2);

        // Cuando la edición baja la cantidad hasta el umbral
        final result = await useCase(
          'hogar-1',
          _request(quantity: 2, minStock: 2),
          previous: previous,
        );

        // Entonces se dispara la alerta de stock bajo
        expect(result.isLowStock, isTrue);
        expect(notifications.lowStockAlerts, hasLength(1));
      },
    );

    test(
      'Escenario: el producto ya estaba en stock bajo antes de editar — '
      'no se repite la alerta',
      () async {
        // Dado que el producto ya estaba en stock bajo
        final previous = _product('p1', quantity: 2, minStock: 2);

        // Cuando se edita sin salir del umbral
        await useCase(
          'hogar-1',
          _request(quantity: 1, minStock: 2),
          previous: previous,
        );

        // Entonces no se dispara una alerta nueva (ya se había disparado)
        expect(notifications.lowStockAlerts, isEmpty);
      },
    );
  });
}
