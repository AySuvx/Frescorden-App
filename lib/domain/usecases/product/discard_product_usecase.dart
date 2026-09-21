import '../../entities/product_history_entry.dart';
import 'product_resolution_usecase.dart';

/// El usuario retiró el producto porque se venció/dañó sin aprovecharlo.
class DiscardProductUseCase extends ProductResolutionUseCase {
  const DiscardProductUseCase(
    super.repository,
    super.notificationService,
    super.analyticsService, [
    super.historyRepository,
    super.activityLogRepository,
  ]);

  @override
  ProductOutcome get outcome => ProductOutcome.expired;
}
