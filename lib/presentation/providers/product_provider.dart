// Proveedor de estado central para productos.
//
// Responsabilidades:
//  1. Mantener la lista de Product en memoria como fuente única de verdad,
//     sincronizada en tiempo real con Firestore (ver setActiveHousehold):
//     altas, bajas y modificaciones de CUALQUIER miembro del hogar, desde
//     cualquier dispositivo, llegan solas por el stream — no hace falta
//     refrescar manualmente.
//  2. Exponer `productosMap` (List<Map<String,dynamic>>) para las pantallas
//     que trabajan con Maps.
//  3. Delegar la lógica de negocio (upsert, edición, eliminación) a los
//     Use Cases del dominio — este provider solo orquesta el estado de UI
//     y decide QUÉ Use Case llamar según la acción del usuario.
//
// Las pantallas no llaman a FirebaseFirestore.instance directamente.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/activity_log_entry.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_history_entry.dart';
import '../../domain/repositories/i_activity_log_repository.dart';
import '../../domain/repositories/i_product_repository.dart';
import '../../domain/repositories/i_product_history_repository.dart';
import '../../domain/requests/save_product_request.dart';
import '../../domain/services/i_analytics_service.dart';
import '../../domain/services/i_notification_service.dart';
import '../../domain/usecases/product/add_product_usecase.dart';
import '../../domain/usecases/product/consume_product_usecase.dart';
import '../../domain/usecases/product/decrement_product_quantity_usecase.dart';
import '../../domain/usecases/product/discard_product_usecase.dart';
import '../../domain/usecases/product/update_product_usecase.dart';
import '../utils/analytics_service.dart';
import '../utils/notification_service.dart';

class ProductProvider extends ChangeNotifier {
  final IProductRepository _repository;

  // Historial de Productos: registra cada eliminación como
  // "consumido a tiempo" o "vencido" (ver deleteProduct). Opcional para no
  // romper ningún test/uso existente que construya ProductProvider sin él.
  final IProductHistoryRepository? _historyRepository;

  // Registro de Actividad del hogar: CREADO/EDITADO/
  // CONSUMIDO/ELIMINADO por producto. Opcional por el mismo motivo que
  // _historyRepository.
  final IActivityLogRepository? _activityLogRepository;

  // Inyectados opcionalmente (tests); si no se pasan, se resuelve el
  // singleton por defecto — pero solo al primer uso real (ver los `late
  // final` de abajo), nunca en el constructor: construir un ProductProvider
  // no debe requerir Firebase.initializeApp() a menos que de verdad se
  // guarde/elimine un producto.
  final INotificationService? _injectedNotificationService;
  final IAnalyticsService? _injectedAnalyticsService;

  late final INotificationService _notifications =
      _injectedNotificationService ?? NotificationService.instance;
  late final IAnalyticsService _analytics =
      _injectedAnalyticsService ?? AnalyticsService.instance;

  late final AddProductUseCase _addProductUseCase = AddProductUseCase(
    _repository,
    _notifications,
  );
  late final UpdateProductUseCase _updateProductUseCase = UpdateProductUseCase(
    _repository,
    _notifications,
  );
  late final ConsumeProductUseCase _consumeProductUseCase = ConsumeProductUseCase(
    _repository,
    _notifications,
    _analytics,
    _historyRepository,
    _activityLogRepository,
  );
  late final DiscardProductUseCase _discardProductUseCase = DiscardProductUseCase(
    _repository,
    _notifications,
    _analytics,
    _historyRepository,
    _activityLogRepository,
  );
  late final DecrementProductQuantityUseCase _decrementProductQuantityUseCase =
      DecrementProductQuantityUseCase(_repository, _notifications);

  ProductProvider(
    this._repository, [
    this._historyRepository,
    this._activityLogRepository,
    this._injectedNotificationService,
    this._injectedAnalyticsService,
  ]);

  // ─── Estado ───────────────────────────────────────────────────────────────

  String? _householdId;
  StreamSubscription<List<Product>>? _productsSub;

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  // ─── Getters públicos ──────────────────────────────────────────────────────

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get count => _products.length;

  /// Hogar cuyo inventario se está mirando actualmente, o `null` si
  /// todavía no hay uno activo (ver setActiveHousehold).
  String? get activeHouseholdId => _householdId;

  // ─── Alertas de Stock mínimo ──────────────────────────────────

  List<Product> get lowStockProducts =>
      _products.where((p) => p.isLowStock).toList();

  int get lowStockCount => lowStockProducts.length;

  Map<FoodCategory, List<Product>> get productsByCategory {
    final map = <FoodCategory, List<Product>>{};
    for (final p in _products) {
      map.putIfAbsent(p.category, () => []).add(p);
    }
    return map;
  }

  /// Getter de compatibilidad retroactiva para pantallas que aún trabajan
  /// con Maps en vez de la entidad Product.
  List<Map<String, dynamic>> get productosMap =>
      _products.map((p) => p.toMap()).toList();

  // ─── Suscripción por hogar ──────────────────────────────────────────────

  void setActiveHousehold(String? householdId) {
    if (_householdId == householdId) return;
    _householdId = householdId;
    unawaited(_productsSub?.cancel());
    _productsSub = null;

    if (householdId == null) {
      _products = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _productsSub = _repository.watchProducts(householdId).listen(
      (products) {
        // BUG CRÍTICO CORREGIDO: el stream emite List<ProductModel>
        // reificado en tiempo de ejecución — hay que re-envolverlo como
        // List<Product> o copyWith() posteriores lanzan
        // "type 'Product' is not a subtype of type 'ProductModel'".
        _products = List<Product>.of(products);
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// No-op: se mantiene solo por compatibilidad con pantallas que aún la
  /// llaman después de una acción — la lista ya se sincroniza sola vía
  /// stream (ver setActiveHousehold).
  Future<void> loadProducts() async {}

  // ─── Guardar (alta o edición) ───────────────────────────────────────────

  /// Registra un producto nuevo o edita uno existente, según
  /// `request.isEdit`. Delega la regla de negocio (acumular cantidad si ya
  /// existe, o reemplazar campos en una edición) a AddProductUseCase /
  /// UpdateProductUseCase.
  Future<void> saveProduct(SaveProductRequest request) async {
    final householdId = _householdId;
    if (householdId == null) {
      throw StateError(
        'ProductProvider.saveProduct: no hay un hogar activo todavía.',
      );
    }

    try {
      if (request.isEdit) {
        final previous = _findLocal(request.id!);
        final updated = await _updateProductUseCase(
          householdId,
          request,
          previous: previous,
        );
        unawaited(
          _logActivity(householdId, updated.name, ActivityAction.editado),
        );
      } else {
        final result = await _addProductUseCase(householdId, request);
        unawaited(
          _logActivity(
            householdId,
            result.product.name,
            result.wasAccumulated
                ? ActivityAction.editado
                : ActivityAction.creado,
          ),
        );
      }
    } catch (e) {
      debugPrint('ProductProvider.saveProduct error: $e');
      rethrow; // La pantalla decide si muestra un SnackBar
    }
  }

  /// Busca en la lista local (ya sincronizada por el stream) el producto
  /// con este [id]. `null` si no está (p. ej. alta nueva).
  Product? _findLocal(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Registra un evento en el log de actividad del hogar. Best-effort
  /// (unawaited en cada call site): un fallo acá no debe afectar la
  /// acción real sobre el producto, que ya se confirmó.
  Future<void> _logActivity(
    String householdId,
    String productName,
    ActivityAction action,
  ) async {
    if (_activityLogRepository == null) return;
    try {
      await _activityLogRepository.logActivity(
        householdId: householdId,
        productName: productName,
        action: action,
      );
    } catch (e) {
      debugPrint('ProductProvider._logActivity error: $e');
    }
  }

  // ─── Eliminar ─────────────────────────────────────────────────────────────

  /// Elimina el producto con el [id] indicado.
  ///
  /// Trazabilidad de Desperdicio vs. Consumo: quien
  /// retira un producto del inventario declara explícitamente si lo
  /// aprovechó ([ProductOutcome.consumedOnTime]) o si lo desperdició
  /// ([ProductOutcome.expired]) — ya NO se infiere comparando la fecha de
  /// eliminación contra `expirationDate`. La pantalla es responsable de
  /// mostrar el diálogo de confirmación y pasar el [outcome] elegido.
  Future<void> deleteProduct(
    String id, {
    required ProductOutcome outcome,
  }) async {
    final householdId = _householdId;
    if (householdId == null) {
      throw StateError(
        'ProductProvider.deleteProduct: no hay un hogar activo todavía.',
      );
    }

    final resolved = _findLocal(id);
    try {
      final useCase = outcome == ProductOutcome.expired
          ? _discardProductUseCase
          : _consumeProductUseCase;
      await useCase(householdId, id, resolved: resolved);
      // `_products` se actualiza solo cuando llega el próximo snapshot del
      // stream (ver setActiveHousehold) — no se muta a mano aquí.
    } catch (e) {
      debugPrint('ProductProvider.deleteProduct error: $e');
      rethrow;
    }
  }

  /// Descuenta 1 unidad de la cantidad del producto [id] — acción rápida
  /// para consumo parcial, sin pasar por el diálogo de "retirar producto"
  /// (ver deleteProduct, pensado para cuando ya no queda nada). No hace
  /// nada si la cantidad ya está en 0 o el producto no existe localmente.
  Future<void> decrementQuantity(String id) async {
    final householdId = _householdId;
    if (householdId == null) return;

    final existing = _findLocal(id);
    if (existing == null) return;

    try {
      await _decrementProductQuantityUseCase(householdId, existing);
    } catch (e) {
      debugPrint('ProductProvider.decrementQuantity error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    unawaited(_productsSub?.cancel());
    super.dispose();
  }
}
