import '../../entities/product_history_entry.dart';
import 'product_resolution_usecase.dart';

/// El usuario retiró el producto porque lo aprovechó a tiempo.
class ConsumeProductUseCase extends ProductResolutionUseCase {
  const ConsumeProductUseCase(
    super.repository,
    super.notificationService,
    super.analyticsService, [
    super.historyRepository,
    super.activityLogRepository,
  ]);

  @override
  ProductOutcome get outcome => ProductOutcome.consumedOnTime;
}
