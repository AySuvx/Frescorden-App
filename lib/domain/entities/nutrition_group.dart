// Agrupa las categorías de FoodCategory en los 4 grupos nutricionales
// esenciales de una dieta balanceada. ShoppingProvider cruza esto contra
// el inventario real del hogar activo para detectar qué grupos NO están
// cubiertos por ningún producto — la base del botón "Plato Equilibrado" en
// ShoppingListScreen, que ofrece agregar a la lista de compras los
// insumos sugeridos de cada grupo faltante con un solo toque.

import 'food_category.dart';
import 'shopping_item.dart';

enum NutritionGroup { proteinas, carbohidratos, frutasYVerduras, lacteosYGrasas }

extension NutritionGroupInfo on NutritionGroup {
  String get label {
    switch (this) {
      case NutritionGroup.proteinas:
        return 'Proteínas';
      case NutritionGroup.carbohidratos:
        return 'Carbohidratos';
      case NutritionGroup.frutasYVerduras:
        return 'Frutas y Verduras';
      case NutritionGroup.lacteosYGrasas:
        return 'Lácteos y Grasas';
    }
  }

  /// Categorías de [FoodCategory] que cuentan como parte de este grupo —
  /// basta un solo producto de cualquiera de ellas para considerarlo
  /// cubierto. `condimentosYSalsas` cuenta para Lácteos y Grasas porque ahí
  /// vive el aceite en el catálogo de la app (ver canastas.json).
  Set<FoodCategory> get categories {
    switch (this) {
      case NutritionGroup.proteinas:
        return const {FoodCategory.carnesYEmbutidos};
      case NutritionGroup.carbohidratos:
        return const {FoodCategory.granosYCereales, FoodCategory.panaderia};
      case NutritionGroup.frutasYVerduras:
        return const {
          FoodCategory.frutasYVerduras,
          FoodCategory.frutas,
          FoodCategory.verdurasYHortalizas,
        };
      case NutritionGroup.lacteosYGrasas:
        return const {FoodCategory.lacteos, FoodCategory.condimentosYSalsas};
    }
  }

  /// Insumos sugeridos para cubrir este grupo con un solo toque (ver
  /// ShoppingProvider.addBalancedPlateItems). Mismos nombres que ya usa
  /// assets/data/canastas.json a propósito: así missingItems() los
  /// reconoce como el mismo ítem si el usuario también tenía esa canasta
  /// activa, en vez de tratarlos como duplicados.
  List<ShoppingItem> get suggestedItems {
    switch (this) {
      case NutritionGroup.proteinas:
        return const [
          ShoppingItem(
            name: 'Huevos',
            quantity: 30,
            unit: 'unidades',
            category: 'otros',
            estimatedPrice: 16000,
          ),
          ShoppingItem(
            name: 'Carne',
            quantity: 1,
            unit: 'kg',
            category: 'carnesYEmbutidos',
            estimatedPrice: 19000,
          ),
        ];
      case NutritionGroup.carbohidratos:
        return const [
          ShoppingItem(
            name: 'Arroz',
            quantity: 5,
            unit: 'kg',
            category: 'granosYCereales',
            estimatedPrice: 22000,
          ),
          ShoppingItem(
            name: 'Pan',
            quantity: 1,
            unit: 'paquete',
            category: 'panaderia',
            estimatedPrice: 4500,
          ),
        ];
      case NutritionGroup.frutasYVerduras:
        return const [
          ShoppingItem(
            name: 'Frutas',
            quantity: 1,
            unit: 'kg',
            category: 'frutasYVerduras',
            estimatedPrice: 6000,
          ),
          ShoppingItem(
            name: 'Verduras',
            quantity: 1,
            unit: 'kg',
            category: 'frutasYVerduras',
            estimatedPrice: 6000,
          ),
        ];
      case NutritionGroup.lacteosYGrasas:
        return const [
          ShoppingItem(
            name: 'Leche',
            quantity: 2,
            unit: 'L',
            category: 'lacteos',
            estimatedPrice: 9000,
          ),
          ShoppingItem(
            name: 'Aceite',
            quantity: 1,
            unit: 'L',
            category: 'condimentosYSalsas',
            estimatedPrice: 9000,
          ),
        ];
    }
  }
}
