// Contrato que define QUÉ notificaciones locales necesita el dominio de
// Productos, sin especificar CÓMO se programan (flutter_local_notifications
// vive en la capa de infraestructura). Igual que IProductRepository: el
// dominio depende de esta abstracción, no de NotificationService directo.

import '../entities/product.dart';

abstract interface class INotificationService {
  /// Alerta 3 días antes de `expirationDate`.
  Future<void> scheduleExpirationAlert(Product product);

  /// Alerta inmediata para un producto que ya está dentro de los 3 días
  /// previos al vencimiento cuando se registra o se le cambia la fecha.
  Future<void> showExpirationSoonAlert(Product product, int daysLeft);

  /// Alerta a los `storageCriticalDays` de `entryDate`, solo productos a granel.
  Future<void> scheduleBulkStorageAlert(Product product);

  /// Alerta inmediata al cruzar el umbral de `minStock`.
  Future<void> showLowStockAlert(Product product);

  /// Cancela las alertas programadas del producto (vencimiento,
  /// almacenamiento y stock bajo).
  Future<void> cancelForProduct(String productId);
}
