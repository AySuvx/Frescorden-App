// Editar un producto ya existente (identificado por SaveProductRequest.id).
// A diferencia de AddProductUseCase, no hay lógica de "buscar duplicado":
// el registro a modificar ya es conocido.

import '../../../core/errors/domain_exception.dart';
import '../../entities/product.dart';
import '../../repositories/i_product_repository.dart';
import '../../requests/save_product_request.dart';
import '../../services/i_notification_service.dart';

class UpdateProductUseCase {
  final IProductRepository _repository;
  final INotificationService _notificationService;

  const UpdateProductUseCase(this._repository, this._notificationService);

  /// [previous] es el estado del producto ANTES de esta edición — se usa
  /// solo para decidir si la alerta de stock bajo debe dispararse (únicamente
  /// al CRUZAR el umbral, no en cada edición de un producto que ya estaba
  /// bajo).
  Future<Product> call(
    String householdId,
    SaveProductRequest request, {
    Product? previous,
  }) async {
    if (request.quantity <= 0) {
      throw const ValidationException('La cantidad debe ser mayor a cero.');
    }
    final id = request.id;
    if (id == null) {
      throw ArgumentError(
        'UpdateProductUseCase requiere SaveProductRequest.id.',
      );
    }

    final updated = Product(
      id: id,
      name: request.name,
      quantity: request.quantity,
      unit: request.unit,
      imagePath: request.imagePath,
      expirationDate: request.expirationDate,
      entryDate: request.entryDate,
      isBulk: request.isBulk,
      category: request.category,
      minStock: request.minStock,
    );
    await _repository.updateProduct(householdId, updated);

    await _notificationService.scheduleExpirationAlert(updated);
    await _notificationService.scheduleBulkStorageAlert(updated);
    final wasLowStock = previous?.isLowStock ?? false;
    if (!wasLowStock && updated.isLowStock) {
      await _notificationService.showLowStockAlert(updated);
    }

    return updated;
  }
}
