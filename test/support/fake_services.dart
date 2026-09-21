// test/support/fake_services.dart
//
// Dobles de prueba en memoria para los servicios de dominio (I*Service)
// que consumen los Use Cases de Productos. No tocan Firebase ni
// flutter_local_notifications: solo registran qué se llamó, para que los
// tests puedan verificar el comportamiento real de cada Use Case.

import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/services/i_analytics_service.dart';
import 'package:frescorden/domain/services/i_notification_service.dart';

/// Fake de [INotificationService]: cada método registra los productos (o
/// ids) recibidos en su propia lista, sin programar nada real.
class FakeNotificationService implements INotificationService {
  final List<Product> expirationAlerts = [];
  final List<Product> bulkStorageAlerts = [];
  final List<Product> lowStockAlerts = [];
  final List<String> canceledProductIds = [];

  @override
  Future<void> scheduleExpirationAlert(Product product) async {
    expirationAlerts.add(product);
  }

  @override
  Future<void> scheduleBulkStorageAlert(Product product) async {
    bulkStorageAlerts.add(product);
  }

  @override
  Future<void> showLowStockAlert(Product product) async {
    lowStockAlerts.add(product);
  }

  @override
  Future<void> cancelForProduct(String productId) async {
    canceledProductIds.add(productId);
  }
}

/// Fake de [IAnalyticsService]: registra los outcomes recibidos en
/// [loggedOutcomes].
class FakeAnalyticsService implements IAnalyticsService {
  final List<String> loggedOutcomes = [];

  @override
  Future<void> logProductResolved({required String outcome}) async {
    loggedOutcomes.add(outcome);
  }
}
