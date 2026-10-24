// test/presentation/widgets/analytics/waste_category_pie_chart_test.dart
//
// Estabilidad visual de WasteCategoryPieChart: estado vacío (sin
// productos vencidos) y con datos (dona + total en el centro + leyenda).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frescorden/domain/entities/analytics_summary.dart';
import 'package:frescorden/domain/entities/category_waste_stats.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/usecases/get_analytics_usecase.dart';
import 'package:frescorden/presentation/providers/analytics_provider.dart';
import 'package:frescorden/presentation/widgets/analytics/waste_category_pie_chart.dart';

import '../../../support/fake_repositories.dart';

AnalyticsProvider _providerWith(AnalyticsSummary summary) {
  final repo = FakeAnalyticsRepository()..summaryToReturn = summary;
  final provider = AnalyticsProvider(GetAnalyticsUseCase(repo));
  provider.setActiveHousehold('hogar-1');
  return provider;
}

Widget _wrap(AnalyticsProvider provider) {
  return MaterialApp(
    home: Scaffold(
      body: ChangeNotifierProvider<AnalyticsProvider>.value(
        value: provider,
        child: const WasteCategoryPieChart(),
      ),
    ),
  );
}

void main() {
  group('Estabilidad visual: WasteCategoryPieChart', () {
    testWidgets(
      'Escenario: sin productos vencidos, se muestra el estado vacío',
      (tester) async {
        final provider = _providerWith(
          const AnalyticsSummary(
            wasteReductionPercentage: 100,
            moneySavedCop: 0,
            averageRotationDays: 0,
            worstExpirationCategory: null,
            totalResolved: 3,
            categoryBreakdown: [
              CategoryWasteStats(
                category: FoodCategory.lacteos,
                consumedOnTime: 3,
                expired: 0,
              ),
            ],
            topConsumedProduct: null,
            topDiscardedProduct: null,
            discardedBreakdown: [],
          ),
        );

        await tester.pumpWidget(_wrap(provider));
        await tester.pump();

        expect(
          find.textContaining('Sin desperdicio registrado todavía'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con productos vencidos, se dibuja la dona con el total '
      'en el centro y la leyenda',
      (tester) async {
        final provider = _providerWith(
          const AnalyticsSummary(
            wasteReductionPercentage: 60,
            moneySavedCop: 5000,
            averageRotationDays: 3,
            worstExpirationCategory: FoodCategory.lacteos,
            totalResolved: 5,
            categoryBreakdown: [
              CategoryWasteStats(
                category: FoodCategory.lacteos,
                consumedOnTime: 1,
                expired: 3,
              ),
              CategoryWasteStats(
                category: FoodCategory.frutas,
                consumedOnTime: 1,
                expired: 1,
              ),
            ],
            topConsumedProduct: null,
            topDiscardedProduct: null,
            discardedBreakdown: [],
          ),
        );

        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.text('4'), findsOneWidget); // total vencidos
        expect(find.text('vencidos'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
