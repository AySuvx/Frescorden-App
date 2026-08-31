// lib/domain/entities/analytics_summary.dart
//
// FASE 3 — Capa de Dominio de Analíticas:
// Resumen agregado de KPIs, calculado por AnalyticsRepositoryImpl a partir
// del historial de productos resueltos (ProductHistoryEntry). Ver ese
// archivo para el detalle de cómo se calcula cada campo.

import 'food_category.dart';

class AnalyticsSummary {
  /// % de productos resueltos que se consumieron a tiempo (0-100).
  final double wasteReductionPercentage;

  /// Suma estimada en COP de lo "salvado" al consumir a tiempo en vez de
  /// desperdiciar (Opción A: precio estimado vía catálogo de canastas).
  final int moneySavedCop;

  /// Promedio de días en inventario antes de resolverse (consumido o
  /// vencido), sobre todo el historial.
  final double averageRotationDays;

  /// Categoría con mayor tasa de vencimiento (vencidos / total de esa
  /// categoría). `null` si no hay historial suficiente para calcularla.
  final FoodCategory? worstExpirationCategory;

  /// Total de entradas de historial consideradas. Permite a la UI mostrar
  /// un estado "sin datos aún" en vez de un 0% engañoso cuando el usuario
  /// todavía no tiene historial.
  final int totalResolved;

  const AnalyticsSummary({
    required this.wasteReductionPercentage,
    required this.moneySavedCop,
    required this.averageRotationDays,
    required this.worstExpirationCategory,
    required this.totalResolved,
  });

  factory AnalyticsSummary.empty() => const AnalyticsSummary(
        wasteReductionPercentage: 0,
        moneySavedCop: 0,
        averageRotationDays: 0,
        worstExpirationCategory: null,
        totalResolved: 0,
      );

  bool get hasData => totalResolved > 0;
}
