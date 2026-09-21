// Descuenta 1 unidad de la cantidad de un producto — acción rápida de
// consumo parcial, sin pasar por ConsumeProductUseCase/DiscardProductUseCase
// (pensados para cuando ya no queda nada del producto).

import '../../entities/product.dart';
import '../../repositories/i_product_repository.dart';
import '../../services/i_notification_service.dart';

class DecrementProductQuantityUseCase {
  final IProductRepository _repository;
  final INotificationService _notificationService;

  const DecrementProductQuantityUseCase(
    this._repository,
    this._notificationService,
  );

  /// [current] es el estado local conocido del producto. No hace nada si
  /// su cantidad ya está en 0.
  Future<Product?> call(String householdId, Product current) async {
    if (current.quantity <= 0) return null;

    final wasLowStock = current.isLowStock;
    final updated = current.copyWith(quantity: current.quantity - 1);
    await _repository.updateProduct(householdId, updated);

    if (!wasLowStock && updated.isLowStock) {
      await _notificationService.showLowStockAlert(updated);
    }
    return updated;
  }
}
