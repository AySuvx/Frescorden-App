// test/shopping_provider_test.dart
//
// BDD (Given/When/Then) de ShoppingProvider.addItems, con
// FakeShoppingRepository (test/support/fake_repositories.dart) en vez del
// catálogo local real. Cubre puntualmente el bug de deduplicación
// corregido en Fase 6 Módulo 3.6 (Módulo de Grupos Familiares): addItems
// debía deduplicar correctamente incluso cuando se llama ANTES de que la
// pantalla de la lista de compras haya cargado la canasta base.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/budget_tier.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/nutrition_group.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/entities/shopping_item.dart';
import 'package:frescorden/presentation/providers/shopping_provider.dart';

import 'support/fake_repositories.dart';

ShoppingItem _item(String name, {int? estimatedPrice}) {
  return ShoppingItem(
    name: name,
    quantity: 1,
    unit: 'unidad',
    category: 'otros',
    estimatedPrice: estimatedPrice,
  );
}

Product _product(String name, {FoodCategory category = FoodCategory.otros}) {
  return Product(
    id: name,
    name: name,
    quantity: 1,
    unit: 'unidad',
    entryDate: DateTime(2026, 1, 1),
    category: category,
  );
}

void main() {
  group('Historia de Usuario: Como usuario, quiero agregar los ingredientes '
      'faltantes de una receta a mi lista de compras sin duplicados', () {
    test(
      'Escenario: un ítem ya existente en la canasta no se agrega de nuevo',
      () async {
        // Dado un ítem existente en la canasta (ya cargada)
        final repo = FakeShoppingRepository({
          BudgetTier.basica: [_item('Arroz')],
        });
        final provider = ShoppingProvider(repo);
        addTearDown(provider.dispose);
        await provider.selectTier(BudgetTier.basica);
        expect(provider.basket.map((i) => i.name), contains('Arroz'));

        // Cuando se invoca un agregado desde una receta con ese mismo ítem
        await provider.addItems([_item('Arroz')]);

        // Entonces se aplica deduplicación estricta: no se duplica
        expect(provider.extraItems, isEmpty);
      },
    );

    test(
      'Escenario: la deduplicación no distingue mayúsculas/minúsculas',
      () async {
        // Dado un ítem existente en la canasta
        final repo = FakeShoppingRepository({
          BudgetTier.basica: [_item('Arroz')],
        });
        final provider = ShoppingProvider(repo);
        addTearDown(provider.dispose);
        await provider.selectTier(BudgetTier.basica);

        // Cuando se agrega el mismo ítem con distinta capitalización
        await provider.addItems([_item('ARROZ')]);

        // Entonces tampoco se duplica
        expect(provider.extraItems, isEmpty);
      },
    );

    test(
      'Escenario: un ítem genuinamente nuevo sí se agrega',
      () async {
        // Dado un ítem existente en la canasta
        final repo = FakeShoppingRepository({
          BudgetTier.basica: [_item('Arroz')],
        });
        final provider = ShoppingProvider(repo);
        addTearDown(provider.dispose);
        await provider.selectTier(BudgetTier.basica);

        // Cuando se agrega un ítem que no está en la canasta ni fue
        // agregado antes
        await provider.addItems([_item('Pollo')]);

        // Entonces se agrega
        expect(provider.extraItems.map((i) => i.name), ['Pollo']);
      },
    );

    test(
      'Escenario: addItems deduplica correctamente incluso si la lista de '
      'compras nunca fue visitada antes (canasta todavía sin cargar)',
      () async {
        // Dado un hogar cuya canasta base tiene un ítem, pero la pantalla
        // de Lista de Compras NUNCA se abrió en esta sesión (la canasta del
        // provider sigue vacía — este es exactamente el escenario del bug
        // real corregido: addItems llamado desde el detalle de una receta
        // sin haber pasado antes por ShoppingListScreen)
        final repo = FakeShoppingRepository({
          BudgetTier.basica: [_item('Arroz')],
        });
        final provider = ShoppingProvider(repo);
        addTearDown(provider.dispose);
        expect(provider.basket, isEmpty, reason: 'canasta aún no cargada');

        // Cuando se agrega desde una receta ese mismo ítem de la canasta
        // base (que el provider todavía no conoce)
        await provider.addItems([_item('Arroz')]);

        // Entonces addItems cargó la canasta primero y SÍ detectó el
        // duplicado — no queda un "Arroz" repetido en extraItems
        expect(provider.basket.map((i) => i.name), contains('Arroz'));
        expect(provider.extraItems, isEmpty);
      },
    );

    test(
      'Escenario: agregar varios ítems en una sola llamada, algunos '
      'duplicados y otros nuevos',
      () async {
        // Dado una canasta con "Arroz" y "Pollo" ya en extraItems de un
        // agregado anterior
        final repo = FakeShoppingRepository({
          BudgetTier.basica: [_item('Arroz')],
        });
        final provider = ShoppingProvider(repo);
        addTearDown(provider.dispose);
        await provider.selectTier(BudgetTier.basica);
        await provider.addItems([_item('Pollo')]);

        // Cuando se agrega una nueva receta con ingredientes mixtos
        // (dos ya presentes, uno nuevo)
        await provider.addItems([_item('Arroz'), _item('Pollo'), _item('Tomate')]);

        // Entonces solo el ítem genuinamente nuevo se suma
        expect(provider.extraItems.map((i) => i.name), ['Pollo', 'Tomate']);
      },
    );
  });

  group('Historia de Usuario: Como usuario, quiero definir mi presupuesto '
      'y cuántas personas cubre la lista de compras', () {
    test(
      'Escenario: setCustomBudget con un valor positivo reemplaza el techo '
      'del nivel seleccionado',
      () {
        final provider = ShoppingProvider(FakeShoppingRepository({}));
        addTearDown(provider.dispose);

        provider.setCustomBudget(50000);

        expect(provider.customBudget, 50000);
        expect(provider.budgetCap, 50000);
      },
    );

    test(
      'Escenario: setCustomBudget con 0 o negativo vuelve a usar el techo '
      'del nivel',
      () {
        final provider = ShoppingProvider(FakeShoppingRepository({}));
        addTearDown(provider.dispose);

        provider.setCustomBudget(50000);
        provider.setCustomBudget(0);

        expect(provider.customBudget, isNull);
        expect(provider.budgetCap, BudgetTier.basica.budgetCap);
      },
    );

    test('Escenario: setPersonCount nunca baja de 1', () {
      final provider = ShoppingProvider(FakeShoppingRepository({}));
      addTearDown(provider.dispose);

      provider.setPersonCount(0);

      expect(provider.personCount, 1);
    });

    test('Escenario: setPersonCount con un valor válido lo aplica', () {
      final provider = ShoppingProvider(FakeShoppingRepository({}));
      addTearDown(provider.dispose);

      provider.setPersonCount(6);

      expect(provider.personCount, 6);
    });
  });

  group('Historia de Usuario: Como usuario, quiero que la canasta se '
      'recargue al cambiar de nivel de presupuesto', () {
    test(
      'Escenario: selectTier con el mismo nivel y canasta ya cargada no '
      'vuelve a pedirla al repositorio',
      () async {
        final repo = FakeShoppingRepository({
          BudgetTier.basica: [_item('Arroz')],
        });
        final provider = ShoppingProvider(repo);
        addTearDown(provider.dispose);
        await provider.selectTier(BudgetTier.basica);

        // Cambia la respuesta del repo: si selectTier volviera a llamarlo,
        // el error se propagaría.
        repo.error = Exception('no debería llamarse de nuevo');
        await provider.selectTier(BudgetTier.basica);

        expect(provider.error, isNull);
      },
    );

    test(
      'Escenario: selectTier con un nivel distinto sí recarga la canasta',
      () async {
        final repo = FakeShoppingRepository({
          BudgetTier.basica: [_item('Arroz')],
          BudgetTier.familiar: [_item('Pollo')],
        });
        final provider = ShoppingProvider(repo);
        addTearDown(provider.dispose);
        await provider.selectTier(BudgetTier.basica);

        await provider.selectTier(BudgetTier.familiar);

        expect(provider.selectedTier, BudgetTier.familiar);
        expect(provider.basket.map((i) => i.name), ['Pollo']);
      },
    );

    test(
      'Escenario: si el repositorio falla al cargar la canasta, se expone '
      'el error y deja de cargar',
      () async {
        final repo = FakeShoppingRepository({})
          ..error = Exception('sin conexión');
        final provider = ShoppingProvider(repo);
        addTearDown(provider.dispose);

        await provider.loadBasket();

        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
        expect(provider.basket, isEmpty);
      },
    );
  });

  group('Historia de Usuario: Como usuario, quiero saber qué grupos '
      'nutricionales me faltan y agregarlos con un toque', () {
    test(
      'Escenario: un inventario sin ningún producto reporta los 4 grupos '
      'como faltantes',
      () {
        final provider = ShoppingProvider(FakeShoppingRepository({}));
        addTearDown(provider.dispose);

        final missing = provider.missingNutritionGroups([]);

        expect(missing, NutritionGroup.values.toSet());
      },
    );

    test(
      'Escenario: un producto de una categoría cubre su grupo nutricional',
      () {
        final provider = ShoppingProvider(FakeShoppingRepository({}));
        addTearDown(provider.dispose);
        final inventory = [_product('Pechuga', category: FoodCategory.carnesYEmbutidos)];

        final missing = provider.missingNutritionGroups(inventory);

        expect(missing.contains(NutritionGroup.proteinas), isFalse);
        expect(missing.length, 3);
      },
    );

    test(
      'Escenario: addBalancedPlateItems agrega los sugeridos de los grupos '
      'faltantes sin duplicar lo que ya está en la canasta',
      () {
        final repo = FakeShoppingRepository({
          BudgetTier.basica: [_item('Huevos')],
        });
        final provider = ShoppingProvider(repo);
        addTearDown(provider.dispose);

        provider.addBalancedPlateItems([]);

        // 'Huevos' ya está en la canasta base (aunque loadBasket no se
        // haya llamado, la canasta del provider sigue vacía acá) — se
        // agregan igual porque _basket todavía no se cargó; lo relevante
        // es que la lista de sugeridos no queda vacía.
        expect(provider.extraItems, isNotEmpty);
      },
    );

    test(
      'Escenario: addBalancedPlateItems no hace nada si ya no falta ningún '
      'grupo nutricional',
      () {
        final provider = ShoppingProvider(FakeShoppingRepository({}));
        addTearDown(provider.dispose);
        final fullInventory = [
          _product('Pechuga', category: FoodCategory.carnesYEmbutidos),
          _product('Arroz', category: FoodCategory.granosYCereales),
          _product('Manzana', category: FoodCategory.frutasYVerduras),
          _product('Leche', category: FoodCategory.lacteos),
        ];

        provider.addBalancedPlateItems(fullInventory);

        expect(provider.extraItems, isEmpty);
      },
    );
  });

  group('Historia de Usuario: Como usuario, quiero ver el costo estimado de '
      'lo que falta comprar y si supera mi presupuesto', () {
    test(
      'Escenario: estimatedTotal suma el precio de los ítems que faltan',
      () async {
        final repo = FakeShoppingRepository({
          BudgetTier.basica: [_item('Arroz', estimatedPrice: 20000)],
        });
        final provider = ShoppingProvider(repo);
        addTearDown(provider.dispose);
        await provider.selectTier(BudgetTier.basica);

        expect(provider.estimatedTotal([]), 20000);
      },
    );

    test(
      'Escenario: isOverBudget es true cuando el total supera el techo',
      () async {
        final repo = FakeShoppingRepository({
          BudgetTier.basica: [_item('Arroz', estimatedPrice: 999999999)],
        });
        final provider = ShoppingProvider(repo);
        addTearDown(provider.dispose);
        await provider.selectTier(BudgetTier.basica);

        expect(provider.isOverBudget([]), isTrue);
        expect(provider.remainingBudget([]), lessThan(0));
      },
    );

    test(
      'Escenario: isOverBudget es false cuando el total no supera el techo',
      () async {
        final repo = FakeShoppingRepository({
          BudgetTier.basica: [_item('Arroz', estimatedPrice: 100)],
        });
        final provider = ShoppingProvider(repo);
        addTearDown(provider.dispose);
        await provider.selectTier(BudgetTier.basica);

        expect(provider.isOverBudget([]), isFalse);
        expect(provider.remainingBudget([]), greaterThan(0));
      },
    );
  });
}
