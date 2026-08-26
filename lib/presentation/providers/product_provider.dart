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

import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/i_product_repository.dart';

class ProductProvider extends ChangeNotifier {
  final IProductRepository _repository;

  ProductProvider(this._repository);

  // ─── Estado ───────────────────────────────────────────────────────────────

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  // ─── Getters públicos ──────────────────────────────────────────────────────

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get count => _products.length;

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
      _products = await _repository.getProducts();
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
      final isEdit = map['id'] != null &&
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
          // Acumular cantidad sobre el producto existente
          final newQty = existing.quantity + incomingQty;
          final updated = existing.copyWith(quantity: newQty);
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
  Future<void> deleteProduct(String id) async {
    try {
      await _repository.deleteProduct(id);
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('ProductProvider.deleteProduct error: $e');
      rethrow;
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

    final imagePath =
        map['imagePath'] as String? ?? map['image'] as String?;

    return Product(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      barcode: map['barcode'] as String?,
      quantity: parseQty(map['quantity']),
      unit: map['unit'] as String? ?? 'unidad',
      imagePath: (imagePath != null && imagePath.isNotEmpty) ? imagePath : null,
      expirationDate: parseDate(map['expirationDate']),
      storedAt: parseDate(map['storedAt']),            // FASE 3
    );
  }
}
