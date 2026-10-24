// test/domain/usecases/product/expiration_soon_alert_test.dart
//
// BDD del aviso inmediato de vencimiento en AddProductUseCase y
// UpdateProductUseCase: un producto que ya está dentro de los 3 días previos
// al vencimiento se avisa al registrarlo o al cambiarle la fecha, pero no en
// cada edición ni al acumular cantidad.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/requests/save_product_request.dart';
import 'package:frescorden/domain/usecases/product/add_product_usecase.dart';
import 'package:frescorden/domain/usecases/product/update_product_usecase.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fake_services.dart';

DateTime _inDays(int days) => DateTime.now().add(Duration(days: days));

SaveProductRequest _request({String? id, DateTime? expirationDate}) {
  return SaveProductRequest(
    id: id,
    name: 'Leche',
    quantity: 1,
    unit: 'unidad',
    entryDate: DateTime(2026, 1, 1),
    expirationDate: expirationDate,
  );
}

Product _product({DateTime? expirationDate}) {
  return Product(
    id: 'p1',
    name: 'Leche',
    quantity: 1,
    unit: 'unidad',
    entryDate: DateTime(2026, 1, 1),
    category: FoodCategory.otros,
    expirationDate: expirationDate,
  );
}

void main() {
  late FakeProductRepository repo;
  late FakeNotificationService notifications;

  setUp(() {
    repo = FakeProductRepository();
    notifications = FakeNotificationService();
  });

  group('Historia de Usuario: Como usuario, quiero que la app me avise si '
      'registro un producto que vence en pocos días', () {
    late AddProductUseCase useCase;

    setUp(() => useCase = AddProductUseCase(repo, notifications));

    test(
      'Escenario: un producto nuevo que vence en 2 días dispara el aviso '
      'inmediato',
      () async {
        repo.findByNameResult = null;

        await useCase('hogar-1', _request(expirationDate: _inDays(2)));

        expect(notifications.expirationSoonAlerts, hasLength(1));
        expect(notifications.expirationSoonAlerts.single.daysLeft, 2);
      },
    );

    test(
      'Escenario: un producto que vence en más de 3 días solo usa la '
      'alerta programada',
      () async {
        repo.findByNameResult = null;

        await useCase('hogar-1', _request(expirationDate: _inDays(10)));

        expect(notifications.expirationSoonAlerts, isEmpty);
        expect(notifications.expirationAlerts, hasLength(1));
      },
    );

    test(
      'Escenario: sumar cantidad a un producto existente no repite el '
      'aviso',
      () async {
        repo.findByNameResult = _product(expirationDate: _inDays(2));

        await useCase('hogar-1', _request(expirationDate: _inDays(2)));

        expect(notifications.expirationSoonAlerts, isEmpty);
      },
    );
  });

  group('Historia de Usuario: Como usuario, quiero que editar un producto '
      'no me llene de avisos repetidos', () {
    late UpdateProductUseCase useCase;

    setUp(() => useCase = UpdateProductUseCase(repo, notifications));

    test(
      'Escenario: cambiar la fecha a una dentro de 3 días dispara el aviso',
      () async {
        final previous = _product(expirationDate: _inDays(20));

        await useCase(
          'hogar-1',
          _request(id: 'p1', expirationDate: _inDays(1)),
          previous: previous,
        );

        expect(notifications.expirationSoonAlerts, hasLength(1));
        expect(notifications.expirationSoonAlerts.single.daysLeft, 1);
      },
    );

    test(
      'Escenario: editar otro dato sin cambiar la fecha no repite el aviso',
      () async {
        final expiry = _inDays(2);
        final previous = _product(expirationDate: expiry);

        await useCase(
          'hogar-1',
          _request(id: 'p1', expirationDate: expiry),
          previous: previous,
        );

        expect(notifications.expirationSoonAlerts, isEmpty);
      },
    );

    test(
      'Escenario: sin producto previo conocido no se dispara el aviso',
      () async {
        await useCase(
          'hogar-1',
          _request(id: 'p1', expirationDate: _inDays(2)),
        );

        expect(notifications.expirationSoonAlerts, isEmpty);
      },
    );
  });
}
