// Registrar un producto nuevo desde el formulario. Encapsula la regla de
// "upsert silencioso": si ya existe un producto con el mismo código de
// barras (o, en su defecto, el mismo nombre) en el hogar, se acumula la
// cantidad en vez de crear un duplicado — comportamiento ya existente en
// ProductProvider.saveProduct, ahora aislado como regla de dominio (P-01).

import '../../../core/errors/domain_exception.dart';
import '../../entities/product.dart';
import '../../repositories/i_product_repository.dart';
import '../../requests/save_product_request.dart';
import '../../services/i_notification_service.dart';

class AddProductUseCase {
  final IProductRepository _repository;
  final INotificationService _notificationService;

  const AddProductUseCase(this._repository, this._notificationService);

  /// Devuelve el producto resultante (nuevo o con la cantidad acumulada)
  /// y si el resultado fue una acumulación sobre uno existente
  /// (`wasAccumulated`), para que el llamador decida cómo registrar la
  /// actividad ("creado" vs. "editado").
  Future<({Product product, bool wasAccumulated})> call(
    String householdId,
    SaveProductRequest request,
  ) async {
    if (request.quantity <= 0) {
      throw const ValidationException('La cantidad debe ser mayor a cero.');
    }

    // El formulario de alta no recoge código de barras (ver
    // add_product_screen._guardarProducto): la búsqueda de duplicado se
    // hace por nombre exacto dentro del hogar.
    final existing = await _repository.findByName(householdId, request.name);

    final Product result;
    final bool wasAccumulated;
    if (existing != null) {
      // BUG CRÍTICO CORREGIDO (hallado en prueba visual en dispositivo):
      // acumular con `existing.copyWith(quantity: newQty)` conservaba el
      // resto de campos del registro viejo (expirationDate, categoría,
      // unidad...), ignorando lo que el usuario acababa de escribir en el
      // formulario — producía una fecha de vencimiento "fantasma" en
      // productos guardados sin fecha. Se reconstruye desde `request`
      // (refleja lo que el usuario ingresó ahora) y solo se preservan el
      // id (mismo documento) y la cantidad acumulada.
      result = Product(
        id: existing.id,
        name: request.name,
        quantity: existing.quantity + request.quantity,
        unit: request.unit,
        imagePath: request.imagePath,
        expirationDate: request.expirationDate,
        entryDate: request.entryDate,
        isBulk: request.isBulk,
        category: request.category,
        minStock: request.minStock,
      );
      await _repository.updateProduct(householdId, result);
      wasAccumulated = true;
    } else {
      result = await _repository.addProduct(
        householdId,
        Product(
          id: '',
          name: request.name,
          quantity: request.quantity,
          unit: request.unit,
          imagePath: request.imagePath,
          expirationDate: request.expirationDate,
          entryDate: request.entryDate,
          isBulk: request.isBulk,
          category: request.category,
          minStock: request.minStock,
        ),
      );
      wasAccumulated = false;
    }

    await _notificationService.scheduleExpirationAlert(result);
    await _notificationService.scheduleBulkStorageAlert(result);
    if (result.isLowStock) {
      await _notificationService.showLowStockAlert(result);
    }

    return (product: result, wasAccumulated: wasAccumulated);
  }
}
