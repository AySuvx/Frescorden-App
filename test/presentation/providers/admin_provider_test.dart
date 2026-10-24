// test/presentation/providers/admin_provider_test.dart
//
// BDD de AdminProvider, con FakeAdminRepository (test/support/fake_repositories.dart)
// en vez de Firestore.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/admin_stats.dart';
import 'package:frescorden/domain/usecases/get_admin_stats_usecase.dart';
import 'package:frescorden/presentation/providers/admin_provider.dart';

import '../../support/fake_repositories.dart';

void main() {
  group('Historia de Usuario: Como administrador global, quiero ver las '
      'métricas agregadas de toda la app', () {
    test(
      'Escenario: antes de cargar, se expone el estado vacío por defecto',
      () {
        final repo = FakeAdminRepository();
        final provider = AdminProvider(GetAdminStatsUseCase(repo));

        expect(provider.stats, AdminStats.empty());
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
      },
    );

    test(
      'Escenario: loadStats carga las estadísticas globales exitosamente',
      () async {
        final repo = FakeAdminRepository();
        repo.statsToReturn = const AdminStats(
          totalUsers: 42,
          newUsersLast7Days: 0,
          activeUsersLast7Days: 0,
          activeUsersLast30Days: 0,
          totalHouseholds: 0,
          totalHouseholdMembers: 0,
          householdsWithExpiredInviteCode: 0,
          globalWasteReductionPercentageLast30Days: null,
          globalConsumedLast30Days: 0,
          globalDiscardedLast30Days: 0,
          assistantQueriesLast30Days: 0,
          householdsUsingAssistantLast30Days: 0,
        );
        final provider = AdminProvider(GetAdminStatsUseCase(repo));

        await provider.loadStats();

        expect(provider.stats.totalUsers, 42);
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
      },
    );

    test(
      'Escenario: si el repositorio falla, se expone el error y no se '
      'propaga la excepción',
      () async {
        final repo = FakeAdminRepository();
        repo.error = Exception('permiso denegado');
        final provider = AdminProvider(GetAdminStatsUseCase(repo));

        await provider.loadStats();

        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
      },
    );
  });
}
