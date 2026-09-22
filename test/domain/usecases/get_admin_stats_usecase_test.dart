// test/domain/usecases/get_admin_stats_usecase_test.dart
//
// BDD (Given/When/Then) de GetAdminStatsUseCase. Hoy es una delegación
// pura al repositorio (punto de extensión, ver el propio use case) — el
// test cubre esa delegación y la propagación de errores (p. ej. cuando
// las reglas de Firestore rechazan la consulta por no ser el UID admin).

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/admin_stats.dart';
import 'package:frescorden/domain/usecases/get_admin_stats_usecase.dart';

import '../../support/fake_repositories.dart';

void main() {
  group('Historia de Usuario: Como administrador, quiero ver métricas '
      'globales de toda la app', () {
    test(
      'Escenario: caso válido — devuelve las métricas del repositorio '
      'tal cual',
      () async {
        final repo = FakeAdminRepository()
          ..statsToReturn = const AdminStats(
            totalUsers: 42,
            newUsersLast7Days: 3,
            activeUsersLast7Days: 10,
            activeUsersLast30Days: 20,
            totalHouseholds: 15,
            totalHouseholdMembers: 30,
            householdsWithExpiredInviteCode: 2,
            globalWasteReductionPercentageLast30Days: 75.5,
            globalConsumedLast30Days: 100,
            globalDiscardedLast30Days: 25,
            assistantQueriesLast30Days: 50,
            householdsUsingAssistantLast30Days: 8,
          );
        final useCase = GetAdminStatsUseCase(repo);

        final result = await useCase();

        expect(result.totalUsers, 42);
        expect(result.totalHouseholds, 15);
      },
    );

    test(
      'Escenario: el repositorio rechaza la consulta (p. ej. usuario sin '
      'permisos de administrador)',
      () async {
        final repo = FakeAdminRepository()
          ..error = Exception('permission-denied');
        final useCase = GetAdminStatsUseCase(repo);

        await expectLater(() => useCase(), throwsA(isException));
      },
    );
  });
}
