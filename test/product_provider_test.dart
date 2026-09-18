// test/product_provider_test.dart
//
// BDD (Given/When/Then) de ProductProvider contra su comportamiento real,
// con FakeProductRepository (test/support/fake_repositories.dart) en vez de
// Firestore.
//
// Nota (Fase 6, Módulo 3): el escenario original pedía "ordenar
// prioritariamente por vencimiento al consultar la lista", pero
// ProductProvider.products no ordena nada — devuelve el orden natural del
// stream (ver setActiveHousehold). El ordenamiento por vencimiento vive
// como opción de UI en productos_screen.dart (_SortOption.expirationAsc,
// no es el default). Por decisión del usuario, este archivo cubre el
// comportamiento real del provider en su lugar: sincronización con el
// stream, lowStockProducts y productsByCategory.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/presentation/providers/product_provider.dart';

import 'support/fake_repositories.dart';

Product _product(
  String id,
  String name, {
  FoodCategory category = FoodCategory.otros,
  int quantity = 1,
  int? minStock,
}) {
  return Product(
    id: id,
    name: name,
    quantity: quantity,
    unit: 'unidad',
    entryDate: DateTime(2026, 1, 1),
    category: category,
    minStock: minStock,
  );
}

void main() {
  group('Historia de Usuario: Como miembro de un hogar, quiero ver mi '
      'inventario sincronizado en tiempo real', () {
    late FakeProductRepository repo;
    late ProductProvider provider;

    setUp(() {
      repo = FakeProductRepository();
      provider = ProductProvider(repo);
    });

    tearDown(() {
      provider.dispose();
      repo.dispose();
    });

    test(
      'Escenario: Firestore emite un snapshot nuevo de productos',
      () async {
        // Dado un hogar activo sin productos todavía
        provider.setActiveHousehold('hogar-1');
        expect(provider.isLoading, isTrue);
        expect(provider.products, isEmpty);

        // Cuando el stream de Firestore emite la lista real de productos
        final arroz = _product('p1', 'Arroz');
        final leche = _product('p2', 'Leche');
        repo.emit('hogar-1', [arroz, leche]);
        await pumpEventQueue();

        // Entonces products refleja exactamente ese snapshot
        expect(provider.isLoading, isFalse);
        expect(provider.products, [arroz, leche]);
      },
    );

    test(
      'Escenario: cambiar de hogar activo reinicia el inventario y se '
      'resuscribe al nuevo hogar',
      () async {
        // Dado un hogar activo con productos ya cargados
        provider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [_product('p1', 'Arroz')]);
        await pumpEventQueue();
        expect(provider.products, isNotEmpty);

        // Cuando cambio al hogar activo de otro hogar
        provider.setActiveHousehold('hogar-2');
        await pumpEventQueue();

        // Entonces el inventario del hogar anterior ya no aplica...
        expect(provider.activeHouseholdId, 'hogar-2');
        expect(provider.isLoading, isTrue);

        // ...y al llegar el snapshot del hogar nuevo, refleja SOLO esos productos
        final pollo = _product('p3', 'Pollo');
        repo.emit('hogar-2', [pollo]);
        await pumpEventQueue();
        expect(provider.products, [pollo]);
      },
    );

    test(
      'Escenario: un error del stream se expone sin romper el provider',
      () async {
        // Dado un hogar activo
        provider.setActiveHousehold('hogar-1');

        // Cuando el stream falla (p. ej. permisos, red)
        repo.emitError('hogar-1', Exception('sin conexión'));
        await pumpEventQueue();

        // Entonces el error queda expuesto y isLoading se apaga
        expect(provider.error, contains('sin conexión'));
        expect(provider.isLoading, isFalse);
      },
    );
  });

  group('Historia de Usuario: Como usuario, quiero identificar productos '
      'con stock bajo', () {
    test(
      'Escenario: solo los productos con minStock definido y alcanzado '
      'aparecen en lowStockProducts',
      () async {
        final repo = FakeProductRepository();
        final provider = ProductProvider(repo);
        addTearDown(() {
          provider.dispose();
          repo.dispose();
        });

        // Dado un inventario con productos con y sin umbral de stock mínimo
        final sinUmbral = _product('p1', 'Sal', quantity: 1);
        final porEncimaDelUmbral = _product('p2', 'Arroz', quantity: 5, minStock: 2);
        final enElUmbral = _product('p3', 'Leche', quantity: 2, minStock: 2);
        final bajoElUmbral = _product('p4', 'Huevos', quantity: 0, minStock: 6);

        provider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [sinUmbral, porEncimaDelUmbral, enElUmbral, bajoElUmbral]);
        await pumpEventQueue();

        // Cuando se consulta lowStockProducts
        final resultado = provider.lowStockProducts;

        // Entonces solo aparecen los que están en o bajo su propio umbral
        expect(resultado, containsAll([enElUmbral, bajoElUmbral]));
        expect(resultado, isNot(contains(sinUmbral)));
        expect(resultado, isNot(contains(porEncimaDelUmbral)));
        expect(provider.lowStockCount, 2);
      },
    );
  });

  group('Historia de Usuario: Como usuario, quiero ver mi inventario '
      'agrupado por categoría', () {
    test(
      'Escenario: productsByCategory agrupa correctamente y omite '
      'categorías sin productos',
      () async {
        final repo = FakeProductRepository();
        final provider = ProductProvider(repo);
        addTearDown(() {
          provider.dispose();
          repo.dispose();
        });

        // Dado un inventario con productos de varias categorías
        final leche = _product('p1', 'Leche', category: FoodCategory.lacteos);
        final queso = _product('p2', 'Queso', category: FoodCategory.lacteos);
        final pollo = _product('p3', 'Pollo', category: FoodCategory.carnesYEmbutidos);

        provider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [leche, queso, pollo]);
        await pumpEventQueue();

        // Cuando se consulta productsByCategory
        final agrupado = provider.productsByCategory;

        // Entonces cada producto queda bajo su propia categoría...
        expect(agrupado[FoodCategory.lacteos], [leche, queso]);
        expect(agrupado[FoodCategory.carnesYEmbutidos], [pollo]);
        // ...y una categoría sin ningún producto no aparece en el mapa
        expect(agrupado.containsKey(FoodCategory.bebidas), isFalse);
      },
    );
  });
}
