// test/domain/usecases/product/consume_product_usecase_test.dart
//
// BDD (Given/When/Then) de ConsumeProductUseCase. Cubre también el
// comportamiento compartido de ProductResolutionUseCase (historial, log de
// actividad y analítica best-effort) — DiscardProductUseCase solo agrega
// un test propio confirmando que el outcome/acción difiere (ver
// discard_product_usecase_test.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/activity_log_entry.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/entities/product_history_entry.dart';
import 'package:frescorden/domain/usecases/product/consume_product_usecase.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fake_services.dart';

Product _product() {
  return Product(
    id: 'p1',
    name: 'Arroz',
    quantity: 1,
    unit: 'unidad',
    entryDate: DateTime(2026, 1, 1),
    category: FoodCategory.otros,
  );
}

void main() {
  group('Historia de Usuario: Como usuario, quiero registrar que consumí '
      'un producto a tiempo', () {
    late FakeProductRepository repo;
    late FakeNotificationService notifications;
    late FakeAnalyticsService analytics;
    late FakeProductHistoryRepository history;
    late FakeActivityLogRepository activityLog;
    late ConsumeProductUseCase useCase;

    setUp(() {
      repo = FakeProductRepository();
      notifications = FakeNotificationService();
      analytics = FakeAnalyticsService();
      history = FakeProductHistoryRepository();
      activityLog = FakeActivityLogRepository();
      useCase = ConsumeProductUseCase(
        repo,
        notifications,
        analytics,
        history,
        activityLog,
      );
    });

    test(
      'Escenario: caso válido — se elimina el producto y se registra '
      'como consumido a tiempo',
      () async {
        await useCase('hogar-1', 'p1', resolved: _product());
        await pumpEventQueue();

        expect(repo.deletedIds, ['p1']);
        expect(notifications.canceledProductIds, ['p1']);
        expect(history.logged.single.outcome, ProductOutcome.consumedOnTime);
        expect(activityLog.logged.single, ActivityAction.consumido);
        expect(analytics.loggedOutcomes.single, 'consumedOnTime');
      },
    );

    test(
      'Escenario: sin copia local del producto — se elimina pero no hay '
      'nada que registrar en historial/actividad/analítica',
      () async {
        await useCase('hogar-1', 'p1');
        await pumpEventQueue();

        expect(repo.deletedIds, ['p1']);
        expect(history.logged, isEmpty);
        expect(activityLog.logged, isEmpty);
        expect(analytics.loggedOutcomes, isEmpty);
      },
    );

    test(
      'Escenario: el repositorio genera un error al eliminar',
      () async {
        repo.deleteProductError = Exception('sin conexión');

        await expectLater(
          () => useCase('hogar-1', 'p1', resolved: _product()),
          throwsA(isException),
        );
        expect(history.logged, isEmpty);
      },
    );

    test(
      'Escenario: el historial falla — no rompe la resolución (best-effort)',
      () async {
        history.logResolutionError = Exception('firestore caído');

        await useCase('hogar-1', 'p1', resolved: _product());
        await pumpEventQueue();

        // El producto igual se elimina y el resto de efectos best-effort
        // se ejecutan, aunque el historial haya fallado.
        expect(repo.deletedIds, ['p1']);
        expect(activityLog.logged.single, ActivityAction.consumido);
      },
    );

    test(
      'Escenario: el log de actividad falla — no rompe la resolución '
      '(best-effort)',
      () async {
        activityLog.logActivityError = Exception('firestore caído');

        await useCase('hogar-1', 'p1', resolved: _product());
        await pumpEventQueue();

        expect(repo.deletedIds, ['p1']);
        expect(history.logged.single.outcome, ProductOutcome.consumedOnTime);
      },
    );
  });
}
