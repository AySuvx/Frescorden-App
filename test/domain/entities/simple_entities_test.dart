// test/domain/entities/simple_entities_test.dart
//
// Construcción de entidades de dominio sin lógica propia más allá de
// guardar sus campos (MonthlyAnalytics, ProductRankingEntry, PresetFood,
// ProductRecognitionResult, CategoryWasteStats) — se agrupan en un solo
// archivo en vez de uno por entidad, consistente con su tamaño.
//
// Construcción SIN `const`, a propósito: un `const` se canoniza en tiempo
// de compilación — el constructor nunca "corre" en tiempo de ejecución,
// así que la cobertura de línea no lo cuenta como ejecutado aunque el
// test sí lo ejercite.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/category_waste_stats.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/monthly_analytics.dart';
import 'package:frescorden/domain/entities/preset_food.dart';
import 'package:frescorden/domain/entities/product_ranking_entry.dart';
import 'package:frescorden/domain/entities/product_recognition_result.dart';

void main() {
  group('MonthlyAnalytics', () {
    test('guarda sus campos tal cual se construyó', () {
      final month = DateTime(2026, 9, 1);
      final point = MonthlyAnalytics(
        month: month,
        moneySavedCop: 50000,
        wasteReductionPercentage: 12.5,
        totalResolved: 20,
      );

      expect(point.month, month);
      expect(point.moneySavedCop, 50000);
      expect(point.wasteReductionPercentage, 12.5);
      expect(point.totalResolved, 20);
    });
  });

  group('ProductRankingEntry', () {
    test('guarda sus campos tal cual se construyó', () {
      final entry = ProductRankingEntry(name: 'Tomate', count: 7);

      expect(entry.name, 'Tomate');
      expect(entry.count, 7);
    });
  });

  group('PresetFood', () {
    test('guarda sus campos tal cual se construyó', () {
      final food = PresetFood(
        name: 'Arroz',
        category: FoodCategory.otros,
        unit: 'kg',
      );

      expect(food.name, 'Arroz');
      expect(food.category, FoodCategory.otros);
      expect(food.unit, 'kg');
    });
  });

  group('ProductRecognitionResult', () {
    test('guarda sus campos tal cual se construyó', () {
      final result = ProductRecognitionResult(
        name: 'Manzana',
        category: FoodCategory.frutas,
        unit: 'unidad',
      );

      expect(result.name, 'Manzana');
      expect(result.category, FoodCategory.frutas);
      expect(result.unit, 'unidad');
    });
  });

  group('CategoryWasteStats', () {
    test('total suma consumido a tiempo + vencido', () {
      final stats = CategoryWasteStats(
        category: FoodCategory.lacteos,
        consumedOnTime: 8,
        expired: 2,
      );

      expect(stats.total, 10);
    });
  });
}
