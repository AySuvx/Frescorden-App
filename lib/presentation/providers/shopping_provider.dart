// lib/presentation/providers/shopping_provider.dart
//
// Proveedor de estado para la lista de compras. Implementa ChangeNotifier
// (mismo patrón que ProductProvider/RecipeProvider). Reemplaza las 3
// canastas fijas que antes vivían hardcodeadas en ShoppingListScreen.
//
// Responsabilidades:
//  1. Mantener el BudgetTier seleccionado por el usuario.
//  2. Cargar la canasta base del nivel actual (ShoppingLocalDataSource).
//  3. Calcular `missingItems`: la canasta MENOS lo que el usuario ya tiene
//     en su inventario real (ProductProvider.products) — esto es lo que
//     hace la lista "dinámica" en vez de estática.
//  4. Sumar el costo estimado de lo que falta comprar y compararlo contra
//     el techo de presupuesto del nivel (BudgetTier.budgetCap).
//
// Nota sobre el cruce con inventario: se compara por nombre (igual criterio
// que RecipeProvider/el mock original de recetas) porque las unidades de la
// canasta ("5 kg" de arroz) y las del inventario (unidades sueltas
// registradas por el usuario) no son directamente convertibles sin un
// catálogo de equivalencias que hoy no existe. Comparar cantidades exactas
// daría una falsa sensación de precisión; comparar presencia es honesto con
// los datos disponibles.

import 'package:flutter/foundation.dart';
import '../../domain/entities/budget_tier.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/repositories/i_shopping_repository.dart';

class ShoppingProvider extends ChangeNotifier {
  final IShoppingRepository _repository;

  ShoppingProvider(this._repository);

  BudgetTier _selectedTier = BudgetTier.basica;
  List<ShoppingItem> _basket = [];
  bool _isLoading = false;
  String? _error;

  /// Presupuesto escrito a mano por el usuario, si lo hay. Cuando está
  /// definido, gana sobre `BudgetTier.budgetCap` (ver `budgetCap`) — los
  /// chips de nivel siguen eligiendo QUÉ hay en la canasta, este campo solo
  /// cambia el techo contra el que se compara.
  int? _customBudget;

  /// Personas para las que se calcula la canasta. El catálogo local
  /// (canastas.json) está calibrado para una familia de 4 — este valor
  /// escala linealmente cantidades y precios estimados (ver `_scaled`).
  int _personCount = _defaultPersonCount;

  static const _defaultPersonCount = 4;

  BudgetTier get selectedTier => _selectedTier;
  List<ShoppingItem> get basket => List.unmodifiable(_basket);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get customBudget => _customBudget;
  int get personCount => _personCount;

  /// Define un presupuesto personalizado. `null` (o un valor <= 0) vuelve a
  /// usar el techo del nivel seleccionado.
  void setCustomBudget(int? amount) {
    _customBudget = (amount != null && amount > 0) ? amount : null;
    notifyListeners();
  }

  /// Ajusta la cantidad de personas/comensales; nunca baja de 1.
  void setPersonCount(int count) {
    _personCount = count < 1 ? 1 : count;
    notifyListeners();
  }

  /// Cambia de nivel de presupuesto y recarga su canasta.
  Future<void> selectTier(BudgetTier tier) async {
    if (_selectedTier == tier && _basket.isNotEmpty) return;
    _selectedTier = tier;
    await loadBasket();
  }

  Future<void> loadBasket() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _basket = await _repository.getBasket(_selectedTier);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('ShoppingProvider.loadBasket error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ítems de la canasta que el usuario todavía no tiene registrados en su
  /// inventario, con cantidad y precio escalados según `personCount`. Esto
  /// es lo que realmente falta comprar.
  List<ShoppingItem> missingItems(List<Product> inventory) {
    final inventoryNames = inventory.map((p) => p.name.toLowerCase()).toSet();
    return _basket
        .where((item) => !inventoryNames.contains(item.name.toLowerCase()))
        .map(_scaled)
        .toList();
  }

  /// Escala cantidad y precio estimado de [item] según `personCount`,
  /// relativo a la línea base del catálogo (`_defaultPersonCount`). Sin
  /// cambios cuando personCount es la línea base, para no introducir ruido
  /// de redondeo en el caso más común.
  ShoppingItem _scaled(ShoppingItem item) {
    if (_personCount == _defaultPersonCount) return item;
    final ratio = _personCount / _defaultPersonCount;
    return ShoppingItem(
      name: item.name,
      quantity: item.quantity * ratio,
      unit: item.unit,
      category: item.category,
      estimatedPrice:
          item.estimatedPrice == null ? null : (item.estimatedPrice! * ratio).round(),
    );
  }

  /// Suma de `estimatedPrice` de los ítems que faltan por comprar (ya
  /// escalados por personCount). Los ítems sin precio cargado no aportan al
  /// total (no rompen el cálculo).
  int estimatedTotal(List<Product> inventory) {
    return missingItems(inventory)
        .fold(0, (sum, item) => sum + (item.estimatedPrice ?? 0));
  }

  /// Techo de presupuesto activo: el personalizado si el usuario definió
  /// uno, si no el del nivel seleccionado.
  int get budgetCap => _customBudget ?? _selectedTier.budgetCap;

  /// `true` cuando el costo estimado de lo que falta comprar supera el
  /// techo del presupuesto seleccionado.
  bool isOverBudget(List<Product> inventory) =>
      estimatedTotal(inventory) > budgetCap;

  /// Cuánto queda disponible del presupuesto (puede ser negativo si ya se
  /// superó el techo).
  int remainingBudget(List<Product> inventory) =>
      budgetCap - estimatedTotal(inventory);
}
