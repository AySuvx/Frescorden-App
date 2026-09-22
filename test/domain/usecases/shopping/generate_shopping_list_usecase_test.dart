// test/domain/usecases/shopping/generate_shopping_list_usecase_test.dart
//
// BDD (Given/When/Then) de GenerateShoppingListUseCase — regla de negocio
// pura, sin repositorio ni servicio de por medio.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/entities/shopping_item.dart';
import 'package:frescorden/domain/usecases/shopping/generate_shopping_list_usecase.dart';

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
  group('Historia de Usuario: Como usuario, quiero ver qué me falta '
      'comprar de mi canasta', () {
    const useCase = GenerateShoppingListUseCase();

    test(
      'Escenario: caso válido — un ítem específico que ya está en el '
      'inventario (por nombre) se excluye de la lista',
      () {
        final result = useCase(
          basket: [
            const ShoppingItem(name: 'Aceite de oliva', quantity: 1, unit: 'und', category: 'condimentosYSalsas'),
            const ShoppingItem(name: 'Arroz', quantity: 1, unit: 'kg', category: 'granosYCereales'),
          ],
          extraItems: const [],
          inventory: [_product('Arroz', category: FoodCategory.granosYCereales)],
          personCount: 4,
        );

        expect(result.map((i) => i.name), ['Aceite de oliva']);
      },
    );

    test(
      'Escenario: un ítem genérico de categoría se excluye si el '
      'inventario tiene CUALQUIER producto de esa categoría',
      () {
        final result = useCase(
          basket: [
            const ShoppingItem(
              name: 'Leche',
              quantity: 1,
              unit: 'l',
              category: 'lacteos',
              matchByCategory: true,
            ),
          ],
          extraItems: const [],
          inventory: [_product('Queso', category: FoodCategory.lacteos)],
          personCount: 4,
        );

        expect(result, isEmpty);
      },
    );

    test(
      'Escenario: un ítem específico NO se excluye solo por compartir '
      'categoría con otro producto del inventario',
      () {
        final result = useCase(
          basket: [
            const ShoppingItem(name: 'Aceite de oliva', quantity: 1, unit: 'und', category: 'condimentosYSalsas'),
          ],
          extraItems: const [],
          inventory: [_product('Sal', category: FoodCategory.condimentosYSalsas)],
          personCount: 4,
        );

        expect(result.map((i) => i.name), ['Aceite de oliva']);
      },
    );

    test(
      'Escenario: ítems agregados manualmente (extraItems) se combinan '
      'con la canasta, sin duplicar por nombre',
      () {
        final result = useCase(
          basket: const [
            ShoppingItem(name: 'Arroz', quantity: 1, unit: 'kg', category: 'granosYCereales'),
          ],
          extraItems: const [
            ShoppingItem(name: 'Arroz', quantity: 2, unit: 'kg', category: 'granosYCereales'),
            ShoppingItem(name: 'Café', quantity: 1, unit: 'und', category: 'bebidas'),
          ],
          inventory: const [],
          personCount: 4,
        );

        expect(result, hasLength(2));
        // El ítem de la canasta base gana sobre el duplicado de extraItems
        // (putIfAbsent conserva el primero insertado).
        final arroz = result.firstWhere((i) => i.name == 'Arroz');
        expect(arroz.quantity, 1);
      },
    );

    test(
      'Escenario: personCount distinto a la línea base (4) escala '
      'cantidad y precio estimado proporcionalmente',
      () {
        final result = useCase(
          basket: const [
            ShoppingItem(
              name: 'Arroz',
              quantity: 4,
              unit: 'kg',
              category: 'granosYCereales',
              estimatedPrice: 20000,
            ),
          ],
          extraItems: const [],
          inventory: const [],
          personCount: 2,
        );

        expect(result.single.quantity, 2);
        expect(result.single.estimatedPrice, 10000);
      },
    );

    test(
      'Escenario: personCount igual a la línea base (4) no altera el ítem',
      () {
        final result = useCase(
          basket: const [
            ShoppingItem(name: 'Arroz', quantity: 4, unit: 'kg', category: 'granosYCereales', estimatedPrice: 20000),
          ],
          extraItems: const [],
          inventory: const [],
          personCount: 4,
        );

        expect(result.single.quantity, 4);
        expect(result.single.estimatedPrice, 20000);
      },
    );

    test(
      'Escenario: inventario y canasta vacíos — no hay nada que comprar',
      () {
        final result = useCase(
          basket: const [],
          extraItems: const [],
          inventory: const [],
          personCount: 4,
        );

        expect(result, isEmpty);
      },
    );
  });
}
