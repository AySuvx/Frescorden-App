// Proveedor de estado para la lista de compras.
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

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/shopping_item_model.dart';
import '../../domain/entities/budget_tier.dart';
import '../../domain/entities/nutrition_group.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/repositories/i_shopping_repository.dart';
import '../../domain/usecases/shopping/generate_shopping_list_usecase.dart';

class ShoppingProvider extends ChangeNotifier {
  final IShoppingRepository _repository;

  static const _generateShoppingList = GenerateShoppingListUseCase();

  static const _kTierKey = 'shopping_tier';
  static const _kBudgetKey = 'shopping_custom_budget';
  static const _kPersonCountKey = 'shopping_person_count';
  static const _kExtraItemsKey = 'shopping_extra_items';
  static const _kDismissedKey = 'shopping_dismissed_names';

  /// Resuelve cuando el estado guardado (tier, presupuesto, personas,
  /// extraItems, ítems quitados) ya se restauró desde SharedPreferences.
  /// `loadBasket` espera esto primero para no pisar el estado persistido
  /// con los valores default si la pantalla llama a `loadBasket` antes de
  /// que termine de cargar.
  late final Future<void> _ready;

  ShoppingProvider(this._repository) {
    _ready = _loadPersistedState();
  }

  BudgetTier _selectedTier = BudgetTier.basica;
  List<ShoppingItem> _basket = [];
  bool _isLoading = false;
  String? _error;

  /// 'Plato Equilibrado': ítems agregados con un solo
  /// toque para cubrir grupos nutricionales que faltan en el inventario —
  /// se suman por encima de la canasta del nivel elegido (ver
  /// addBalancedPlateItems / missingItems).
  final List<ShoppingItem> _extraItems = [];

  /// Nombres (en minúsculas) de ítems que el usuario quitó manualmente de
  /// "Por comprar" ("Ya lo tengo") sin registrarlos en el inventario real.
  /// Se limpia al cambiar de nivel de presupuesto (ver `selectTier`), igual
  /// criterio que la poda de `_extraItems` en `loadBasket`.
  final Set<String> _dismissedNames = {};

  /// Presupuesto escrito a mano por el usuario, si lo hay. Cuando está
  /// definido, gana sobre `BudgetTier.budgetCap` (ver `budgetCap`) — los
  /// chips de nivel siguen eligiendo QUÉ hay en la canasta, este campo solo
  /// cambia el techo contra el que se compara.
  int? _customBudget;

  /// Personas para las que se calcula la canasta. El catálogo local
  /// (canastas.json) está calibrado para una familia de 4 — este valor
  /// escala linealmente cantidades y precios estimados (ver
  /// [GenerateShoppingListUseCase]).
  int _personCount = _defaultPersonCount;

  static const _defaultPersonCount = 4;

  BudgetTier get selectedTier => _selectedTier;
  List<ShoppingItem> get basket => List.unmodifiable(_basket);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get customBudget => _customBudget;
  int get personCount => _personCount;
  List<ShoppingItem> get extraItems => List.unmodifiable(_extraItems);

  /// Define un presupuesto personalizado. `null` (o un valor <= 0) vuelve a
  /// usar el techo del nivel seleccionado.
  void setCustomBudget(int? amount) {
    _customBudget = (amount != null && amount > 0) ? amount : null;
    notifyListeners();
    _persist();
  }

  /// Ajusta la cantidad de personas/comensales; nunca baja de 1.
  void setPersonCount(int count) {
    _personCount = count < 1 ? 1 : count;
    notifyListeners();
    _persist();
  }

  /// Cambia de nivel de presupuesto y recarga su canasta. Una canasta nueva
  /// vuelve a empezar: los ítems que el usuario había quitado de la
  /// anterior ("Ya lo tengo") no aplican a esta.
  Future<void> selectTier(BudgetTier tier) async {
    if (_selectedTier == tier && _basket.isNotEmpty) return;
    _selectedTier = tier;
    _dismissedNames.clear();
    await loadBasket();
  }

  Future<void> loadBasket() async {
    await _ready;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _basket = await _repository.getBasket(_selectedTier);
      _error = null;
      // BUG CORREGIDO (reportado por el usuario: ítems duplicados en "Por
      // comprar" al cambiar de nivel de presupuesto después de usar Plato
      // Equilibrado): _extraItems nunca se limpiaba, así que un ítem
      // agregado bajo un nivel (ej. "Carne" en Básica, que no la trae)
      // quedaba viviendo en _extraItems para siempre. Si el usuario luego
      // cambiaba a un nivel que SÍ trae "Carne" en su propia canasta
      // (ej. Familiar), missingItems() mostraba el mismo nombre dos veces
      // — una vez por _basket, otra por el _extraItems obsoleto. Se poda
      // acá, apenas se conoce la canasta nueva, en vez de solo filtrar en
      // missingItems() (eso solo ocultaría el síntoma en pantalla sin
      // arreglar el estado real).
      final basketNames = _basket.map((i) => i.name.toLowerCase()).toSet();
      _extraItems.removeWhere(
        (item) => basketNames.contains(item.name.toLowerCase()),
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('ShoppingProvider.loadBasket error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      _persist();
    }
  }

  /// Ítems de la canasta (más los agregados por "Plato Equilibrado", ver
  /// `_extraItems`) que el usuario todavía no tiene registrados en su
  /// inventario, con cantidad y precio escalados según `personCount`. Esto
  /// es lo que realmente falta comprar — regla de negocio delegada en
  /// [GenerateShoppingListUseCase] (deduplicación por nombre, cruce por
  /// categoría/nombre y escalado, ver esa clase).
  List<ShoppingItem> missingItems(List<Product> inventory) {
    return _generateShoppingList(
      basket: _basket,
      extraItems: _extraItems,
      inventory: inventory,
      personCount: _personCount,
    ).where((item) => !_dismissedNames.contains(item.name.toLowerCase()))
        .toList();
  }

  /// Último ítem quitado con `removeFromMissing`, para poder revertirlo
  /// con `undoLastRemoval` (SnackBar "Deshacer" en ShoppingListScreen).
  ShoppingItem? _lastRemoved;

  /// Quita manualmente [item] de "Por comprar" ("Ya lo tengo") sin pasar
  /// por el inventario real. Si venía de "Plato Equilibrado" o de una
  /// receta (`_extraItems`) se elimina del todo; si es parte de la canasta
  /// base, se oculta hasta el próximo cambio de nivel (ver `selectTier`).
  void removeFromMissing(ShoppingItem item) {
    final lower = item.name.toLowerCase();
    _extraItems.removeWhere((i) => i.name.toLowerCase() == lower);
    _dismissedNames.add(lower);
    _lastRemoved = item;
    notifyListeners();
    _persist();
  }

  /// Revierte el último `removeFromMissing`: si el ítem venía de
  /// `_extraItems` lo vuelve a agregar ahí; si era de la canasta base,
  /// basta con sacarlo de `_dismissedNames` para que vuelva a aparecer.
  void undoLastRemoval() {
    final item = _lastRemoved;
    if (item == null) return;
    final lower = item.name.toLowerCase();
    _dismissedNames.remove(lower);
    final inBasket = _basket.any((i) => i.name.toLowerCase() == lower);
    if (!inBasket) {
      _extraItems.add(item);
    }
    _lastRemoved = null;
    notifyListeners();
    _persist();
  }

  // ─── 'Plato Equilibrado' ────────────────────────────────────────────────

  /// Grupos nutricionales esenciales sin cobertura en el inventario actual
  /// del hogar — ninguno de sus productos cae en las categorías de ese
  /// grupo (ver NutritionGroup.categories). Base tanto del indicador visual
  /// como del botón "Agregar insumos faltantes" en ShoppingListScreen.
  Set<NutritionGroup> missingNutritionGroups(List<Product> inventory) {
    final presentCategories = inventory.map((p) => p.category).toSet();
    return {
      for (final group in NutritionGroup.values)
        if (!group.categories.any(presentCategories.contains)) group,
    };
  }

  /// Agrega a la lista de compras, con un solo toque, los insumos
  /// sugeridos de cada grupo nutricional que falta en el inventario actual
  /// — sin duplicar un ítem que ya está en la canasta del nivel elegido o
  /// que ya se había agregado antes.
  void addBalancedPlateItems(List<Product> inventory) {
    final missingGroups = missingNutritionGroups(inventory);
    if (missingGroups.isEmpty) return;

    final existingNames = {
      for (final item in [..._basket, ..._extraItems]) item.name.toLowerCase(),
    };

    for (final group in missingGroups) {
      for (final item in group.suggestedItems) {
        final lower = item.name.toLowerCase();
        _dismissedNames.remove(lower);
        if (existingNames.add(lower)) {
          _extraItems.add(item);
        }
      }
    }
    notifyListeners();
    _persist();
  }

  /// Agrega ítems arbitrarios a la lista (botón
  /// "Agregar faltantes a la Lista de Compras" en el detalle de una
  /// receta). Mismo criterio anti-duplicado que `addBalancedPlateItems`:
  /// no se agrega un ítem cuyo nombre ya está en la canasta o en lo ya
  /// añadido antes.
  ///
  /// Se puede llamar sin haber visitado antes ShoppingListScreen (que es
  /// quien normalmente dispara `loadBasket`), así que primero asegura la
  /// canasta del nivel actual — si no, la deduplicación por nombre no ve
  /// los ítems de la canasta base y puede agregar un duplicado.
  Future<void> addItems(Iterable<ShoppingItem> items) async {
    if (_basket.isEmpty) {
      await loadBasket();
    }
    final existingNames = {
      for (final item in [..._basket, ..._extraItems]) item.name.toLowerCase(),
    };
    var changed = false;
    for (final item in items) {
      final lower = item.name.toLowerCase();
      if (_dismissedNames.remove(lower)) changed = true;
      if (existingNames.add(lower)) {
        _extraItems.add(item);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      _persist();
    }
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

  // ─── Persistencia (SharedPreferences) ──────────────────────────────────

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedTier = BudgetTier.fromName(prefs.getString(_kTierKey));
    final storedBudget = prefs.getInt(_kBudgetKey);
    _customBudget = (storedBudget != null && storedBudget > 0) ? storedBudget : null;
    _personCount = prefs.getInt(_kPersonCountKey) ?? _defaultPersonCount;
    _extraItems.addAll(
      (prefs.getStringList(_kExtraItemsKey) ?? const [])
          .map((raw) => ShoppingItemModel.fromJson(jsonDecode(raw) as Map<String, dynamic>)),
    );
    _dismissedNames.addAll(prefs.getStringList(_kDismissedKey) ?? const []);
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTierKey, _selectedTier.name);
    if (_customBudget == null) {
      await prefs.remove(_kBudgetKey);
    } else {
      await prefs.setInt(_kBudgetKey, _customBudget!);
    }
    await prefs.setInt(_kPersonCountKey, _personCount);
    await prefs.setStringList(
      _kExtraItemsKey,
      _extraItems.map((item) => jsonEncode(ShoppingItemModel.toJson(item))).toList(),
    );
    await prefs.setStringList(_kDismissedKey, _dismissedNames.toList());
  }
}
