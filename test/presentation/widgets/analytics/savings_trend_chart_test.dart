// test/presentation/widgets/analytics/savings_trend_chart_test.dart
//
// Estabilidad visual de SavingsTrendChart: estado vacío (menos de 2
// meses de historial) y con datos (la línea de tendencia se dibuja).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frescorden/domain/entities/analytics_summary.dart';
import 'package:frescorden/domain/entities/monthly_analytics.dart';
import 'package:frescorden/presentation/providers/analytics_provider.dart';
import 'package:frescorden/presentation/widgets/analytics/savings_trend_chart.dart';
import 'package:frescorden/domain/usecases/get_analytics_usecase.dart';

import '../../../support/fake_repositories.dart';

AnalyticsProvider _providerWith(List<MonthlyAnalytics> monthlyHistory) {
  final repo = FakeAnalyticsRepository()
    ..summaryToReturn = AnalyticsSummary(
      wasteReductionPercentage: 50,
      moneySavedCop: 1000,
      averageRotationDays: 3,
      worstExpirationCategory: null,
      totalResolved: 3,
      categoryBreakdown: const [],
      topConsumedProduct: null,
      topDiscardedProduct: null,
      discardedBreakdown: const [],
      monthlyHistory: monthlyHistory,
    );
  final provider = AnalyticsProvider(GetAnalyticsUseCase(repo));
  provider.setActiveHousehold('hogar-1');
  return provider;
}

Widget _wrap(AnalyticsProvider provider) {
  return MaterialApp(
    home: Scaffold(
      body: ChangeNotifierProvider<AnalyticsProvider>.value(
        value: provider,
        child: const SavingsTrendChart(),
      ),
    ),
  );
}

void main() {
  group('Estabilidad visual: SavingsTrendChart', () {
    testWidgets(
      'Escenario: con menos de 2 meses de historial, se muestra el '
      'estado vacío',
      (tester) async {
        final provider = _providerWith([
          MonthlyAnalytics(
            month: DateTime(2026, 9, 1),
            moneySavedCop: 5000,
            wasteReductionPercentage: 70,
            totalResolved: 3,
          ),
        ]);

        await tester.pumpWidget(_wrap(provider));
        await tester.pump();

        expect(
          find.textContaining('Necesitas al menos 2 meses'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con 2 o más meses de historial, se dibuja la línea de '
      'tendencia sin excepciones',
      (tester) async {
        final provider = _providerWith([
          MonthlyAnalytics(
            month: DateTime(2026, 8, 1),
            moneySavedCop: 3000,
            wasteReductionPercentage: 50,
            totalResolved: 2,
          ),
          MonthlyAnalytics(
            month: DateTime(2026, 9, 1),
            moneySavedCop: 7000,
            wasteReductionPercentage: 80,
            totalResolved: 4,
          ),
        ]);

        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        expect(
          find.textContaining('Necesitas al menos 2 meses'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
