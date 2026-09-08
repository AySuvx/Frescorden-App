// lib/presentation/utils/notification_service.dart
//
// Antes, AddProductScreen programaba la notificación de vencimiento con un
// ID aleatorio (DateTime.now().millisecondsSinceEpoch...), lo que hacía
// imposible cancelarla después (nada asociaba ese ID al producto). Se
// centraliza aquí con IDs deterministas por producto (hash de su id de
// Firestore), para poder cancelar/reprogramar desde cualquier punto del
// ciclo de vida (guardar, editar, eliminar) sin guardar el ID aparte.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/product.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  // Dos IDs por producto (vencimiento / almacenamiento), derivados de su id
  // de Firestore — estables entre sesiones sin necesidad de persistirlos.
  int _expirationId(String productId) => productId.hashCode & 0x7FFFFFFF;
  int _storageId(String productId) =>
      (productId.hashCode ^ 0x5A5A5A5A) & 0x7FFFFFFF;

  /// Alerta 3 días antes de `expirationDate`. No hace nada si el producto
  /// no tiene fecha de vencimiento o si esos 3 días ya pasaron.
  Future<void> scheduleExpirationAlert(Product product) async {
    final expiryDate = product.expirationDate;
    if (expiryDate == null) return;
    final notifyAt = expiryDate.subtract(const Duration(days: 3));
    if (!notifyAt.isAfter(DateTime.now())) return;

    await initialize();
    try {
      await _plugin.zonedSchedule(
        _expirationId(product.id),
        'Producto por vencer',
        'El producto "${product.name}" vencerá en 3 días.',
        tz.TZDateTime.from(notifyAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'vencimiento_channel',
            'Notificaciones de Vencimiento',
            channelDescription:
                'Avisos de productos cercanos a su fecha de vencimiento',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('NotificationService.scheduleExpirationAlert error: $e');
    }
  }

  /// Alerta a los `storageCriticalDays` (5) de `entryDate`, solo para
  /// productos a granel. Se usa `entryDate` (obligatoria, siempre tiene
  /// valor) en vez de `createdAt` (nullable, aún no resuelto justo al
  /// guardar un producto nuevo porque se escribe con
  /// FieldValue.serverTimestamp) — mismo campo que ya usa
  /// Product.isStorageCritical para el mismo umbral.
  Future<void> scheduleBulkStorageAlert(Product product) async {
    if (!product.isBulk) return;
    final notifyAt = product.entryDate.add(
      Duration(days: product.storageCriticalDays),
    );
    if (!notifyAt.isAfter(DateTime.now())) return;

    await initialize();
    try {
      await _plugin.zonedSchedule(
        _storageId(product.id),
        'Producto almacenado hace varios días',
        '"${product.name}" lleva ${product.storageCriticalDays} días '
            'almacenado — revisa su estado.',
        tz.TZDateTime.from(notifyAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'almacenamiento_channel',
            'Notificaciones de Almacenamiento',
            channelDescription:
                'Avisos de productos a granel con mucho tiempo almacenado',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('NotificationService.scheduleBulkStorageAlert error: $e');
    }
  }

  /// Cancela ambas alertas posibles del producto (vencimiento y
  /// almacenamiento) — al eliminarlo o al consumirlo. Cancelar un ID sin
  /// notificación programada no falla, así que es seguro llamarlo siempre.
  Future<void> cancelForProduct(String productId) async {
    await initialize();
    await _plugin.cancel(_expirationId(productId));
    await _plugin.cancel(_storageId(productId));
  }
}
