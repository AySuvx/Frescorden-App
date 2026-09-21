// Firebase Analytics: eventos de adopción de las funciones clave de la
// app — mismo estilo singleton que NotificationService/QuotaService.
// Implementa un contrato ISP por módulo (I*AnalyticsService en
// domain/services/) para que cada Provider dependa solo de los eventos que
// le corresponden, inyectado por constructor en vez de llamado directo.
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
import '../../domain/services/i_assistant_analytics_service.dart';
import '../../domain/services/i_household_analytics_service.dart';

class AnalyticsService
    implements IAnalyticsService, IHouseholdAnalyticsService, IAssistantAnalyticsService {
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
  @override
  Future<void> logAssistantQuery() => _log('assistant_query');

  @override
  Future<void> logHouseholdCreated() => _log('household_created');

  @override
  Future<void> logHouseholdJoined() => _log('household_joined');
}
