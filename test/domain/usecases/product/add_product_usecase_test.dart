// test/domain/usecases/product/add_product_usecase_test.dart
//
// BDD (Given/When/Then) de AddProductUseCase, siguiendo el formato de la
// Sección 26 de la guía (caso válido / cantidad inválida / repositorio
// genera error), con dobles de prueba en vez de Firestore.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/core/errors/domain_exception.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/requests/save_product_request.dart';
import 'package:frescorden/domain/usecases/product/add_product_usecase.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fake_services.dart';

SaveProductRequest _request({
  int quantity = 1,
  String name = 'Arroz',
  int? minStock,
  DateTime? entryDate,
}) {
  return SaveProductRequest(
    name: name,
    quantity: quantity,
    unit: 'unidad',
    entryDate: entryDate ?? DateTime(2026, 1, 1),
    minStock: minStock,
  );
}

void main() {
  group('Historia de Usuario: Como usuario, quiero registrar un producto '
      'nuevo en mi inventario', () {
    late FakeProductRepository repo;
    late FakeNotificationService notifications;
    late AddProductUseCase useCase;

    setUp(() {
      repo = FakeProductRepository();
      notifications = FakeNotificationService();
      useCase = AddProductUseCase(repo, notifications);
    });

    test(
      'Escenario: caso válido — se agrega el producto y se programan sus '
      'alertas',
      () async {
        // Dado que el producto no existe todavía en el hogar
        repo.findByNameResult = null;

        // Cuando se registra un producto con cantidad válida
        final result = await useCase('hogar-1', _request(quantity: 3));

        // Entonces se agrega (no se acumula) y se programan sus alertas
        expect(result.wasAccumulated, isFalse);
        expect(result.product.name, 'Arroz');
        expect(repo.added, hasLength(1));
        expect(notifications.expirationAlerts, hasLength(1));
        expect(notifications.bulkStorageAlerts, hasLength(1));
      },
    );

    test(
      'Escenario: producto duplicado por nombre — se acumula la cantidad '
      'en vez de crear un registro nuevo',
      () async {
        // Dado que ya existe un producto con ese nombre en el hogar
        final existing = Product(
          id: 'p1',
          name: 'Arroz',
          quantity: 2,
          unit: 'unidad',
          entryDate: DateTime(2025, 12, 1),
          category: FoodCategory.otros,
        );
        repo.findByNameResult = existing;

        // Cuando se registra el mismo producto con cantidad adicional
        final result = await useCase('hogar-1', _request(quantity: 3));

        // Entonces se actualiza el existente sumando la cantidad, sin
        // crear un producto nuevo...
        expect(result.wasAccumulated, isTrue);
        expect(result.product.id, 'p1');
        expect(result.product.quantity, 5);
        expect(repo.added, isEmpty);
        expect(repo.updated, hasLength(1));
      },
    );

    test(
      'Escenario: cantidad inválida — se rechaza antes de tocar el '
      'repositorio',
      () async {
        // Cuando se intenta registrar con cantidad <= 0
        // Entonces se lanza ValidationException y no se llama al repositorio
        await expectLater(
          () => useCase('hogar-1', _request(quantity: 0)),
          throwsA(isA<ValidationException>()),
        );
        expect(repo.added, isEmpty);
        expect(notifications.expirationAlerts, isEmpty);
      },
    );

    test(
      'Escenario: el repositorio genera un error al agregar',
      () async {
        // Dado que el repositorio falla (p. ej. sin conexión)
        repo.findByNameResult = null;
        repo.addProductError = Exception('sin conexión');

        // Cuando se intenta registrar el producto
        // Entonces el error se propaga tal cual, sin programar alertas
        await expectLater(
          () => useCase('hogar-1', _request()),
          throwsA(isException),
        );
        expect(notifications.expirationAlerts, isEmpty);
      },
    );

    test(
      'Escenario: el producto nuevo cruza el umbral de stock bajo — se '
      'dispara la alerta inmediata',
      () async {
        // Dado que el producto se registra ya en o bajo su propio umbral
        repo.findByNameResult = null;

        // Cuando se registra con cantidad <= minStock
        final result = await useCase(
          'hogar-1',
          _request(quantity: 1, minStock: 2),
        );

        // Entonces se dispara la alerta de stock bajo
        expect(result.product.isLowStock, isTrue);
        expect(notifications.lowStockAlerts, hasLength(1));
      },
    );
  });
}
