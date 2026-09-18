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
}
