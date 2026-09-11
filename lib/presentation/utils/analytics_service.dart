// lib/presentation/utils/analytics_service.dart
//
// Firebase Analytics (Fase 4.5, Módulo 3): eventos de adopción de las
// funciones clave de la app — mismo estilo singleton que
// NotificationService/QuotaService, llamado directo desde los providers de
// presentación (no hay interfaz/DI: es infraestructura transversal, no
// una regla de negocio del dominio).
//
// Deliberadamente NO se instrumenta screen_view automático (FirebaseAnalyticsObserver):
// las pantallas navegan con MaterialPageRoute sin `RouteSettings.name`
// en todos los call sites, así que el extractor por defecto no tendría
// nombres que reportar. En vez de agregar nombres de ruta en cada
// Navigator.push de la app (cambio grande, de bajo valor sin rediseñar la
// navegación), se registran eventos de negocio puntuales en los puntos
// donde ya vive la lógica (providers), que es justo lo que responde
// "¿qué features usa la gente?" — la pregunta real detrás de esta métrica.
//
// Todas las llamadas son best-effort: un fallo de Analytics nunca debe
// afectar la acción real del usuario que ya se completó.

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
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
  Future<void> logProductResolved({required String outcome}) =>
      _log('product_resolved', {'outcome': outcome});

  /// Adopción del Asistente Culinario: una consulta exitosa.
  Future<void> logAssistantQuery() => _log('assistant_query');

  /// Adopción del Módulo de Grupos Familiares.
  Future<void> logHouseholdCreated() => _log('household_created');
  Future<void> logHouseholdJoined() => _log('household_joined');
}
