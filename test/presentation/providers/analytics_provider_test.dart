// test/presentation/providers/analytics_provider_test.dart
//
// BDD de AnalyticsProvider, con FakeAnalyticsRepository (test/support/fake_repositories.dart)
// en vez de Firestore.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/analytics_summary.dart';
import 'package:frescorden/domain/usecases/get_analytics_usecase.dart';
import 'package:frescorden/presentation/providers/analytics_provider.dart';

import '../../support/fake_repositories.dart';

void main() {
  group('Historia de Usuario: Como usuario, quiero ver las analíticas del '
      'hogar activo', () {
    test('Escenario: antes de tener un hogar activo, se expone el resumen vacío', () {
      final repo = FakeAnalyticsRepository();
      final provider = AnalyticsProvider(GetAnalyticsUseCase(repo));

      expect(provider.summary, AnalyticsSummary.empty());
      expect(provider.isLoading, isFalse);
    });

    test(
      'Escenario: cambiar de hogar activo carga el resumen de ese hogar',
      () async {
        final repo = FakeAnalyticsRepository();
        repo.summaryToReturn = const AnalyticsSummary(
          wasteReductionPercentage: 80,
          moneySavedCop: 150000,
          averageRotationDays: 5,
          worstExpirationCategory: null,
          totalResolved: 10,
          categoryBreakdown: [],
          topConsumedProduct: null,
          topDiscardedProduct: null,
          discardedBreakdown: [],
        );
        final provider = AnalyticsProvider(GetAnalyticsUseCase(repo));

        provider.setActiveHousehold('hogar-1');
        await pumpEventQueue();

        expect(provider.summary.moneySavedCop, 150000);
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'Escenario: volver a null limpia el resumen sin consultar el '
      'repositorio',
      () async {
        final repo = FakeAnalyticsRepository();
        repo.summaryToReturn = const AnalyticsSummary(
          wasteReductionPercentage: 80,
          moneySavedCop: 150000,
          averageRotationDays: 5,
          worstExpirationCategory: null,
          totalResolved: 10,
          categoryBreakdown: [],
          topConsumedProduct: null,
          topDiscardedProduct: null,
          discardedBreakdown: [],
        );
        final provider = AnalyticsProvider(GetAnalyticsUseCase(repo));
        provider.setActiveHousehold('hogar-1');
        await pumpEventQueue();

        provider.setActiveHousehold(null);

        expect(provider.summary, AnalyticsSummary.empty());
      },
    );

    test(
      'Escenario: si el repositorio falla, se expone el error y no se '
      'propaga la excepción',
      () async {
        final repo = FakeAnalyticsRepository();
        repo.error = Exception('sin conexión');
        final provider = AnalyticsProvider(GetAnalyticsUseCase(repo));

        provider.setActiveHousehold('hogar-1');
        await pumpEventQueue();

        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
      },
    );
  });
}
