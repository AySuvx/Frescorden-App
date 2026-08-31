// lib/presentation/providers/product_provider.dart
//
// Proveedor de estado central para productos. Implementa ChangeNotifier
// (compatible con el Provider ya instalado en el proyecto).
//
// Responsabilidades:
//  1. Mantener la lista de Product en memoria como fuente única de verdad.
//  2. Exponer `productosMap` (List<Map<String,dynamic>>) para retrocompatibilidad
//     con las pantallas que ya funcionan con Maps.
//  3. Centralizar toda la lógica de negocio de productos que antes estaba
//     dispersa en inicio_screen y add_product_screen:
//       - Carga inicial
//       - Upsert (agregar o acumular cantidad si ya existe por barcode/nombre)
//       - Actualización completa de un producto existente
//       - Eliminación
//
// Las pantallas ya NO llaman a FirebaseFirestore.instance directamente.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_history_entry.dart';
import '../../domain/repositories/i_product_repository.dart';
import '../../domain/repositories/i_product_history_repository.dart';

class ProductProvider extends ChangeNotifier {
  final IProductRepository _repository;

  // Historial de Productos: registra cada eliminación como
  // "consumido a tiempo" o "vencido" (ver deleteProduct). Opcional para no
  // romper ningún test/uso existente que construya ProductProvider sin él.
  final IProductHistoryRepository? _historyRepository;

  ProductProvider(this._repository, [this._historyRepository]);

  // ─── Estado ───────────────────────────────────────────────────────────────

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  // ─── Getters públicos ──────────────────────────────────────────────────────

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get count => _products.length;

  // ─── Alertas de Stock mínimo (#2) ──────────────────────────────────

  /// Productos cuya cantidad actual llegó o bajó del umbral que el usuario
  /// definió (`minStock`). Los productos sin `minStock` nunca aparecen aquí.
  List<Product> get lowStockProducts =>
      List.unmodifiable(_products.where((p) => p.isLowStock));

  int get lowStockCount => lowStockProducts.length;

  // ─── Categorización de Alimentos (#1) ──────────────────────────────

  /// Agrupa los productos actuales por categoría, en el orden declarado en
  /// [FoodCategory]. Las categorías sin productos no aparecen en el mapa.
  Map<FoodCategory, List<Product>> get productsByCategory {
    final Map<FoodCategory, List<Product>> grouped = {};
    for (final product in _products) {
      grouped.putIfAbsent(product.category, () => []).add(product);
    }
    return grouped;
  }

  /// Retorna los productos como `List<Map<String,dynamic>>` para retrocompatibilidad
  /// con todas las pantallas existentes (ProductosScreen, RecetasScreen, etc.).
  List<Map<String, dynamic>> get productosMap =>
      _products.map((p) => p.toMap()).toList();

  // ─── Carga ────────────────────────────────────────────────────────────────

  /// Carga todos los productos del usuario desde Firestore.
  /// Notifica a los listeners al iniciar y al terminar.
  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // BUG CRÍTICO CORREGIDO (hallado en prueba manual en dispositivo): el
      // objeto que retorna _repository.getProducts() está reificado en
      // tiempo de ejecución como List<ProductModel> (así lo construye
      // FirestoreProductDataSource.getAll()), aunque la interfaz declare
      // List<Product>. Dart no "amplía" el tipo de un List ya construido —
      // asignarlo tal cual a _products dejaba _products apuntando a esa
      // misma List<ProductModel> reificada. Cualquier escritura posterior
      // (_products.add(...), _products[idx] = ...) con un Product base
      // (copyWith()/_productFromMap() siempre construyen la clase base, no
      // el subtipo) lanzaba en runtime:
      // "type 'Product' is not a subtype of type 'ProductModel' of 'value'".
      // FIX: List<Product>.of(...) crea una lista NUEVA reificada
      // exactamente como List<Product> — acepta cualquier Product desde
      // ese punto en adelante, sin importar qué subtipo devolvió el repo.
      _products = List<Product>.of(await _repository.getProducts());
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('ProductProvider.loadProducts error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Agregar / Actualizar (upsert) ─────────────────────────────────────────

  /// Guarda un producto a partir de un Map (formato que vienen usando las pantallas).
  ///
  /// Lógica de upsert:
  ///  - Si el map trae un 'id' → es una edición completa (update all fields).
  ///  - Si tiene 'barcode' no vacío y ya existe uno igual → acumula cantidad.
  ///  - Si tiene solo 'name' y ya existe uno igual → acumula cantidad.
  ///  - Si no coincide ninguno → agrega nuevo documento.
  ///
  /// Reemplaza los métodos agregarOActualizarProducto() de inicio_screen y
  /// _guardarProducto() de add_product_screen que operaban sobre Firestore
  /// directamente.
  Future<void> saveProduct(Map<String, dynamic> map) async {
    try {
      final isEdit =
          map['id'] != null &&
          map['id'].toString().isNotEmpty &&
          map['id'].toString() != '';

      if (isEdit) {
        // ── Edición completa ────────────────────────────────────────────────
        final updated = _productFromMap(map);
        await _repository.updateProduct(updated);

        // Actualizar en memoria
        final idx = _products.indexWhere((p) => p.id == updated.id);
        if (idx != -1) {
          _products[idx] = updated;
        } else {
          _products.add(updated);
        }
      } else {
        // ── Agregar o acumular ──────────────────────────────────────────────
        final barcode = map['barcode'] as String? ?? '';
        final name = map['name'] as String? ?? '';
        final incomingQty =
            int.tryParse(map['quantity']?.toString() ?? '1') ?? 1;

        Product? existing;
        if (barcode.isNotEmpty) {
          existing = await _repository.findByBarcode(barcode);
        }
        existing ??= await _repository.findByName(name);

        if (existing != null) {
          // Acumular cantidad sobre el producto existente.
          //
          // BUG CRÍTICO CORREGIDO (hallado en prueba visual en dispositivo):
          // `existing.copyWith(quantity: newQty)` solo sobreescribía la
          // cantidad y copiaba el resto de campos (expirationDate,
          // categoría, unidad, isBulk, entryDate, minStock) del registro viejo,
          // ignorando lo que el usuario acababa de escribir en el
          // formulario. Síntoma reportado: una fecha de vencimiento "fantasma"
          // reaparecía en productos guardados sin fecha, porque el nombre
          // coincidía con un registro anterior que sí tenía fecha.
          // FIX: se parte del Product recién construido desde el formulario
          // (refleja fielmente lo que el usuario ingresó ahora) y solo se
          // preservan el id (mismo documento) y la cantidad acumulada.
          final newQty = existing.quantity + incomingQty;
          final updated = _productFromMap(
            map,
          ).copyWith(id: existing.id, quantity: newQty);
          await _repository.updateProduct(updated);

          final idx = _products.indexWhere((p) => p.id == existing!.id);
          if (idx != -1) _products[idx] = updated;
        } else {
          // Nuevo producto
          final newProduct = _productFromMap(map);
          final saved = await _repository.addProduct(newProduct);
          _products.add(saved);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('ProductProvider.saveProduct error: $e');
      rethrow; // La pantalla decide si muestra un SnackBar
    }
  }

  // ─── Eliminar ─────────────────────────────────────────────────────────────

  /// Elimina el producto con el [id] indicado.
  ///
  /// Historial: antes de borrar, se captura una copia del producto
  /// para registrar en el historial si se consumió a tiempo o venció
  /// (comparando el momento de la eliminación contra `expirationDate`). El
  /// registro de historial es best-effort: si falla, NO afecta la
  /// eliminación (que ya ocurrió) ni se propaga como error al caller — solo
  /// se pierde ese dato para analíticas.
  Future<void> deleteProduct(String id) async {
    Product? resolved;
    try {
      final matches = _products.where((p) => p.id == id);
      resolved = matches.isEmpty ? null : matches.first;
      await _repository.deleteProduct(id);
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('ProductProvider.deleteProduct error: $e');
      rethrow;
    }

    if (resolved != null) {
      unawaited(_logHistory(resolved));
    }
  }

  /// Registra en el historial el resultado de haber eliminado [product].
  /// `outcome` se infiere: consumido a tiempo si se elimina en o antes de
  /// `expirationDate` (o si el producto no tiene fecha de vencimiento);
  /// vencido si se elimina después.
  Future<void> _logHistory(Product product) async {
    if (_historyRepository == null) return;
    try {
      final now = DateTime.now();
      final expired = product.expirationDate != null &&
          now.isAfter(product.expirationDate!);

      await _historyRepository.logResolution(
        ProductHistoryEntry(
          productId: product.id,
          name: product.name,
          category: product.category,
          entryDate: product.entryDate,
          expirationDate: product.expirationDate,
          resolvedAt: now,
          outcome:
              expired ? ProductOutcome.expired : ProductOutcome.consumedOnTime,
        ),
      );
    } catch (e) {
      debugPrint('ProductProvider._logHistory error: $e');
    }
  }

  // ─── Helpers privados ─────────────────────────────────────────────────────

  Product _productFromMap(Map<String, dynamic> map) {
    int parseQty(dynamic v) {
      if (v == null) return 1;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 1;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    int? parseMinStock(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      final parsed = int.tryParse(v.toString());
      return parsed;
    }

    final imagePath = map['imagePath'] as String? ?? map['image'] as String?;

    return Product(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      barcode: map['barcode'] as String?,
      quantity: parseQty(map['quantity']),
      unit: map['unit'] as String? ?? 'unidad',
      imagePath: (imagePath != null && imagePath.isNotEmpty) ? imagePath : null,
      expirationDate: parseDate(map['expirationDate']),
      // mismo criterio de fallback que ProductModel._fromMap:
      // entryDate > storedAt (legacy) > DateTime.now().
      entryDate:
          parseDate(map['entryDate']) ?? parseDate(map['storedAt']) ?? DateTime.now(),
      isBulk: map['isBulk'] as bool? ?? false,
      category: FoodCategory.fromName(map['category'] as String?),
      minStock: parseMinStock(map['minStock']),
    );
  }
}
