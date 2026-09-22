// test/domain/usecases/product/discard_product_usecase_test.dart
//
// BDD (Given/When/Then) de DiscardProductUseCase. El comportamiento base
// (eliminar, historial, log de actividad, analítica best-effort) ya está
// cubierto en consume_product_usecase_test.dart vía ProductResolutionUseCase
// — este archivo solo confirma que el outcome/acción registrados son los
// de "desperdiciado", no los de "consumido".

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/activity_log_entry.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/entities/product_history_entry.dart';
import 'package:frescorden/domain/usecases/product/discard_product_usecase.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fake_services.dart';

Product _product() {
  return Product(
    id: 'p1',
    name: 'Leche',
    quantity: 1,
    unit: 'unidad',
    entryDate: DateTime(2026, 1, 1),
    category: FoodCategory.lacteos,
  );
}

void main() {
  group('Historia de Usuario: Como usuario, quiero registrar que un '
      'producto se venció sin aprovecharlo', () {
    test(
      'Escenario: caso válido — se elimina el producto y se registra '
      'como desperdiciado',
      () async {
        final repo = FakeProductRepository();
        final notifications = FakeNotificationService();
        final analytics = FakeAnalyticsService();
        final history = FakeProductHistoryRepository();
        final activityLog = FakeActivityLogRepository();
        final useCase = DiscardProductUseCase(
          repo,
          notifications,
          analytics,
          history,
          activityLog,
        );

        await useCase('hogar-1', 'p1', resolved: _product());
        await pumpEventQueue();

        expect(repo.deletedIds, ['p1']);
        expect(history.logged.single.outcome, ProductOutcome.expired);
        expect(activityLog.logged.single, ActivityAction.desperdiciado);
        expect(analytics.loggedOutcomes.single, 'expired');
      },
    );
  });
}
