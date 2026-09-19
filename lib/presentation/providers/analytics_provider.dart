// Proveedor de estado para la pantalla de Analíticas. Delega el
// cálculo a GetAnalyticsUseCase (no llama al repositorio directo).
//
// Household-aware: las analíticas son del hogar activo, no del usuario
// individual — mismo patrón reactivo que
// ProductProvider.setActiveHousehold, registrado en main.dart vía
// ChangeNotifierProxyProvider<HouseholdProvider, AnalyticsProvider>.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/analytics_summary.dart';
import '../../domain/usecases/get_analytics_usecase.dart';

class AnalyticsProvider extends ChangeNotifier {
  final GetAnalyticsUseCase _getAnalytics;

  AnalyticsProvider(this._getAnalytics);

  String? _householdId;
  AnalyticsSummary _summary = AnalyticsSummary.empty();
  bool _isLoading = false;
  String? _error;

  AnalyticsSummary get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Llamado por main.dart (ChangeNotifierProxyProvider<HouseholdProvider,
  /// _>) cada vez que cambia el hogar activo — (re)carga el resumen para
  /// el hogar nuevo.
  void setActiveHousehold(String? householdId) {
    if (householdId == _householdId) return;
    _householdId = householdId;

    if (householdId == null) {
      _summary = AnalyticsSummary.empty();
      _isLoading = false;
      notifyListeners();
      return;
    }

    unawaited(loadSummary());
  }

  Future<void> loadSummary() async {
    final householdId = _householdId;
    if (householdId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _summary = await _getAnalytics(householdId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('AnalyticsProvider.loadSummary error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
