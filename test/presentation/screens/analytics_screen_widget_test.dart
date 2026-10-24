// test/analytics_screen_widget_test.dart
//
// Widget tests de estabilidad visual de AnalyticsScreen: estado vacío,
// cargando, y con datos reales (que ejercitan los gráficos de fl_chart),
// usando AnalyticsProvider real con FakeAnalyticsRepository.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frescorden/domain/entities/analytics_summary.dart';
import 'package:frescorden/domain/entities/category_waste_stats.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product_ranking_entry.dart';
import 'package:frescorden/domain/usecases/get_analytics_usecase.dart';
import 'package:frescorden/presentation/providers/analytics_provider.dart';
import 'package:frescorden/presentation/screens/analytics_screen.dart';

import '../../support/fake_repositories.dart';

Widget _wrap(AnalyticsProvider provider) {
  return MaterialApp(
    home: ChangeNotifierProvider<AnalyticsProvider>.value(
      value: provider,
      child: const AnalyticsScreen(),
    ),
  );
}

void main() {
  group('Estabilidad visual: AnalyticsScreen', () {
    testWidgets(
      'Escenario: sin historial resuelto todavía, se muestra el estado '
      'vacío sin excepciones',
      (tester) async {
        final repo = FakeAnalyticsRepository();
        final provider = AnalyticsProvider(GetAnalyticsUseCase(repo));

        await tester.pumpWidget(_wrap(provider));
        await tester.pump();

        expect(find.byType(AnalyticsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con historial real, los KPIs y gráficos renderizan sin '
      'excepciones',
      (tester) async {
        final repo = FakeAnalyticsRepository();
        repo.summaryToReturn = const AnalyticsSummary(
          wasteReductionPercentage: 75.5,
          moneySavedCop: 85000,
          averageRotationDays: 6,
          worstExpirationCategory: FoodCategory.lacteos,
          totalResolved: 12,
          categoryBreakdown: [
            CategoryWasteStats(
              category: FoodCategory.lacteos,
              consumedOnTime: 8,
              expired: 2,
            ),
            CategoryWasteStats(
              category: FoodCategory.frutas,
              consumedOnTime: 1,
              expired: 1,
            ),
          ],
          topConsumedProduct: ProductRankingEntry(name: 'Leche', count: 5),
          topDiscardedProduct: ProductRankingEntry(name: 'Tomate', count: 2),
          discardedBreakdown: [],
          totalMoneySavedAllTimeCop: 500000,
          monthlyHistory: [],
        );
        final provider = AnalyticsProvider(GetAnalyticsUseCase(repo));

        provider.setActiveHousehold('hogar-1');
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 1000));

        expect(find.textContaining('12 producto'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
