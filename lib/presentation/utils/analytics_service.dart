// Firebase Analytics: eventos de adopción de las funciones clave de la
// app — mismo estilo singleton que NotificationService/QuotaService,
// llamado directo desde los providers de presentación (no hay
// interfaz/DI: es infraestructura transversal, no una regla de negocio
// del dominio).
//
// screen_view automático: ya lo cubre FirebaseAnalyticsObserver, registrado
// en MaterialApp.navigatorObservers (ver main.dart) — funciona porque cada
// Navigator.push de la app pasa un RouteSettings.name (ver lib/routes.dart).
// Este servicio se enfoca en los eventos de negocio puntuales que un
// screen_view no puede responder por sí solo: "¿qué features usa la
// gente?" es más que "¿qué pantallas abrió?" — un usuario puede entrar al
// asistente sin llegar a hacerle una consulta exitosa, por ejemplo.
//
// Todas las llamadas son best-effort: un fallo de Analytics nunca debe
// afectar la acción real del usuario que ya se completó.

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../../domain/services/i_analytics_service.dart';

class AnalyticsService implements IAnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> _log(String name, [Map<String, Object>? parameters]) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('AnalyticsService.$name error: $e');
    }
  }

  /// Trazabilidad de Desperdicio vs. Consumo: quién retira un producto y
  /// qué eligió (ver ProductProvider.deleteProduct).
  @override
  Future<void> logProductResolved({required String outcome}) =>
      _log('product_resolved', {'outcome': outcome});

  /// Adopción del Asistente Culinario: una consulta exitosa.
  Future<void> logAssistantQuery() => _log('assistant_query');

  Future<void> logHouseholdCreated() => _log('household_created');
  Future<void> logHouseholdJoined() => _log('household_joined');
}
