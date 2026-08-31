// lib/presentation/providers/analytics_provider.dart
//
// Proveedor de estado para la pantalla de Analíticas. Delega el
// cálculo a GetAnalyticsUseCase (no llama al repositorio directo — primer
// provider del proyecto que consume un caso de uso en vez de un repository
// inyectado a mano).

import 'package:flutter/foundation.dart';
import '../../domain/entities/analytics_summary.dart';
import '../../domain/usecases/get_analytics_usecase.dart';

class AnalyticsProvider extends ChangeNotifier {
  final GetAnalyticsUseCase _getAnalytics;

  AnalyticsProvider(this._getAnalytics);

  AnalyticsSummary _summary = AnalyticsSummary.empty();
  bool _isLoading = false;
  String? _error;

  AnalyticsSummary get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _summary = await _getAnalytics();
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
