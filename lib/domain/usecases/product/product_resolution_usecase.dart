// Lógica compartida por ConsumeProductUseCase y DiscardProductUseCase:
// ambos eliminan el producto del inventario y difieren únicamente en el
// ProductOutcome que registran (consumido a tiempo vs. desperdiciado).
// Historial y log de actividad son best-effort — un fallo ahí no debe
// afectar la eliminación, que ya se confirmó en el repositorio.

import 'dart:async';
import 'dart:developer' as developer;

import '../../entities/activity_log_entry.dart';
import '../../entities/product.dart';
import '../../entities/product_history_entry.dart';
import '../../repositories/i_activity_log_repository.dart';
import '../../repositories/i_product_history_repository.dart';
import '../../repositories/i_product_repository.dart';
import '../../services/i_analytics_service.dart';
import '../../services/i_notification_service.dart';

abstract class ProductResolutionUseCase {
  final IProductRepository repository;
  final INotificationService notificationService;
  final IAnalyticsService analyticsService;
  final IProductHistoryRepository? historyRepository;
  final IActivityLogRepository? activityLogRepository;

  const ProductResolutionUseCase(
    this.repository,
    this.notificationService,
    this.analyticsService, [
    this.historyRepository,
    this.activityLogRepository,
  ]);

  ProductOutcome get outcome;

  ActivityAction get _activityAction => outcome == ProductOutcome.expired
      ? ActivityAction.desperdiciado
      : ActivityAction.consumido;

  /// [resolved] es la copia local del producto ANTES de eliminarlo (`null`
  /// si ya no estaba en la caché local) — se usa solo para historial y
  /// analítica.
  Future<void> call(
    String householdId,
    String productId, {
    Product? resolved,
  }) async {
    await repository.deleteProduct(householdId, productId);
    unawaited(notificationService.cancelForProduct(productId));

    if (resolved == null) return;
    final now = DateTime.now();
    unawaited(_logHistory(householdId, resolved, now));
    unawaited(_logActivity(householdId, resolved.name));
    unawaited(analyticsService.logProductResolved(outcome: outcome.name));
  }

  Future<void> _logHistory(
    String householdId,
    Product product,
    DateTime now,
  ) async {
    if (historyRepository == null) return;
    try {
      await historyRepository!.logResolution(
        householdId,
        ProductHistoryEntry(
          productId: product.id,
          name: product.name,
          category: product.category,
          entryDate: product.entryDate,
          expirationDate: product.expirationDate,
          resolvedAt: now,
          outcome: outcome,
        ),
      );
    } catch (e) {
      developer.log(
        'error al registrar historial: $e',
        name: 'ProductResolutionUseCase',
      );
    }
  }

  Future<void> _logActivity(String householdId, String productName) async {
    if (activityLogRepository == null) return;
    try {
      await activityLogRepository!.logActivity(
        householdId: householdId,
        productName: productName,
        action: _activityAction,
      );
    } catch (e) {
      developer.log(
        'error al registrar actividad: $e',
        name: 'ProductResolutionUseCase',
      );
    }
  }
}
