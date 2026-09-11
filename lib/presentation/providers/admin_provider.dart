// lib/presentation/providers/admin_provider.dart
//
// Proveedor de estado para el Panel Administrativo Global. La pantalla
// (AdminDashboardScreen) ya verificó el UID antes de montar este provider
// — igual, si Firestore llegara a denegar la consulta (UID no autorizado
// en firestore.rules), el error queda expuesto en `error` en vez de
// propagarse sin control.

import 'package:flutter/foundation.dart';
import '../../domain/entities/admin_stats.dart';
import '../../domain/usecases/get_admin_stats_usecase.dart';

class AdminProvider extends ChangeNotifier {
  final GetAdminStatsUseCase _getAdminStats;

  AdminProvider(this._getAdminStats);

  AdminStats _stats = AdminStats.empty();
  bool _isLoading = false;
  String? _error;

  AdminStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stats = await _getAdminStats();
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('AdminProvider.loadStats error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
