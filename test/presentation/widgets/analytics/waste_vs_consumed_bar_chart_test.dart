// test/presentation/widgets/analytics/waste_vs_consumed_bar_chart_test.dart
//
// Estabilidad visual de WasteVsConsumedBarChart: estado vacío (sin
// desglose por categoría) y con datos (barras + leyenda + tooltip).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frescorden/domain/entities/analytics_summary.dart';
import 'package:frescorden/domain/entities/category_waste_stats.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/usecases/get_analytics_usecase.dart';
import 'package:frescorden/presentation/providers/analytics_provider.dart';
import 'package:frescorden/presentation/widgets/analytics/waste_vs_consumed_bar_chart.dart';

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
        child: const WasteVsConsumedBarChart(),
      ),
    ),
  );
}

void main() {
  group('Estabilidad visual: WasteVsConsumedBarChart', () {
    testWidgets(
      'Escenario: sin desglose por categoría, se muestra el estado vacío',
      (tester) async {
        final provider = _providerWith(AnalyticsSummary.empty());

        await tester.pumpWidget(_wrap(provider));
        await tester.pump();

        expect(
          find.text('Aún no hay suficientes datos por categoría.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con desglose por categoría, se dibujan las barras sin '
      'excepciones',
      (tester) async {
        final provider = _providerWith(
          const AnalyticsSummary(
            wasteReductionPercentage: 70,
            moneySavedCop: 10000,
            averageRotationDays: 4,
            worstExpirationCategory: FoodCategory.lacteos,
            totalResolved: 5,
            categoryBreakdown: [
              CategoryWasteStats(
                category: FoodCategory.lacteos,
                consumedOnTime: 3,
                expired: 1,
              ),
              CategoryWasteStats(
                category: FoodCategory.frutas,
                consumedOnTime: 1,
                expired: 0,
              ),
            ],
            topConsumedProduct: null,
            topDiscardedProduct: null,
            discardedBreakdown: [],
          ),
        );

        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.text('Consumido a tiempo'), findsOneWidget);
        expect(find.text('Desperdiciado'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
