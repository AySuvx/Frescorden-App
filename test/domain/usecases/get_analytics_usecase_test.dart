// test/domain/usecases/get_analytics_usecase_test.dart
//
// BDD (Given/When/Then) de GetAnalyticsUseCase. Hoy es una delegación pura
// al repositorio (punto de extensión, ver el propio use case) — el test
// cubre esa delegación y la propagación de errores.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/analytics_summary.dart';
import 'package:frescorden/domain/usecases/get_analytics_usecase.dart';

import '../../support/fake_repositories.dart';

void main() {
  group('Historia de Usuario: Como usuario, quiero ver el resumen de '
      'analítica de mi hogar', () {
    test(
      'Escenario: caso válido — devuelve el resumen del hogar solicitado',
      () async {
        final repo = FakeAnalyticsRepository()
          ..summaryToReturn = const AnalyticsSummary(
            wasteReductionPercentage: 80,
            moneySavedCop: 50000,
            averageRotationDays: 4.5,
            worstExpirationCategory: null,
            totalResolved: 12,
            categoryBreakdown: [],
            topConsumedProduct: null,
            topDiscardedProduct: null,
            discardedBreakdown: [],
          );
        final useCase = GetAnalyticsUseCase(repo);

        final result = await useCase('hogar-1');

        expect(result.totalResolved, 12);
        expect(result.wasteReductionPercentage, 80);
      },
    );

    test(
      'Escenario: el repositorio genera un error al calcular el resumen',
      () async {
        final repo = FakeAnalyticsRepository()
          ..error = Exception('sin conexión');
        final useCase = GetAnalyticsUseCase(repo);

        await expectLater(
          () => useCase('hogar-1'),
          throwsA(isException),
        );
      },
    );
  });
}
