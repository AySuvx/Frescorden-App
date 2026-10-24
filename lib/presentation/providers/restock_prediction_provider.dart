// Mantiene el historial del hogar activo en memoria para calcular
// predicciones de reposición bajo demanda (ver `predict`). Household-aware,
// mismo patrón reactivo que AnalyticsProvider — registrado en main.dart vía
// ChangeNotifierProxyProvider<HouseholdProvider, _>.
//
// A diferencia de AnalyticsProvider (expone un resumen YA calculado), acá
// se expone un método (`predict`) en vez de un campo: la predicción
// necesita el inventario ACTUAL (ProductProvider.products), que cambia más
// seguido que el historial y no tiene sentido duplicar en este provider.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/datasources/firestore_product_history_datasource.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_history_entry.dart';
import '../../domain/entities/restock_prediction.dart';
import '../../domain/usecases/predict_restock_usecase.dart';

class RestockPredictionProvider extends ChangeNotifier {
  final FirestoreProductHistoryDataSource _dataSource;
  final PredictRestockUseCase _predictRestock;

  RestockPredictionProvider(
    this._dataSource, [
    this._predictRestock = const PredictRestockUseCase(),
  ]);

  String? _householdId;
  List<ProductHistoryEntry> _history = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  /// Llamado por main.dart cada vez que cambia el hogar activo.
  void setActiveHousehold(String? householdId) {
    if (householdId == _householdId) return;
    _householdId = householdId;
    _history = [];

    if (householdId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    unawaited(_loadHistory(householdId));
  }

  Future<void> _loadHistory(String householdId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _history = await _dataSource.getAll(householdId);
    } catch (e) {
      debugPrint('RestockPredictionProvider._loadHistory error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<RestockPrediction> predict(List<Product> inventory) {
    if (_history.isEmpty) return const [];
    return _predictRestock(history: _history, inventory: inventory);
  }
}
