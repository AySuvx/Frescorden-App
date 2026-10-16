// test/admin_dashboard_screen_widget_test.dart
//
// Widget tests de estabilidad visual de AdminDashboardScreen: acceso
// denegado para un usuario normal, y las métricas reales para el uid
// admin (kAdminUid), usando AdminProvider real con FakeAdminRepository.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frescorden/config/app_config.dart';
import 'package:frescorden/domain/entities/admin_stats.dart';
import 'package:frescorden/domain/entities/app_user.dart';
import 'package:frescorden/domain/usecases/get_admin_stats_usecase.dart';
import 'package:frescorden/presentation/providers/admin_provider.dart';
import 'package:frescorden/presentation/providers/auth_provider.dart';
import 'package:frescorden/presentation/screens/admin_dashboard_screen.dart';

import 'support/fake_repositories.dart';

Widget _wrap(AdminProvider adminProvider, AuthProvider authProvider) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminProvider>.value(value: adminProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: const AdminDashboardScreen(),
    ),
  );
}

void main() {
  group('Estabilidad visual: AdminDashboardScreen', () {
    testWidgets(
      'Escenario: un usuario normal ve acceso denegado, sin consultar '
      'AdminProvider',
      (tester) async {
        final adminRepo = FakeAdminRepository();
        final adminProvider = AdminProvider(GetAdminStatsUseCase(adminRepo));
        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-normal', emailVerified: true),
        );

        await tester.pumpWidget(_wrap(adminProvider, authProvider));
        await tester.pump();

        expect(find.text('Acceso denegado'), findsOneWidget);
        expect(adminProvider.isLoading, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: el administrador ve las métricas globales cargadas',
      (tester) async {
        final adminRepo = FakeAdminRepository();
        adminRepo.statsToReturn = const AdminStats(
          totalUsers: 42,
          newUsersLast7Days: 3,
          activeUsersLast7Days: 10,
          activeUsersLast30Days: 20,
          totalHouseholds: 15,
          totalHouseholdMembers: 30,
          householdsWithExpiredInviteCode: 2,
          globalWasteReductionPercentageLast30Days: 72.5,
          globalConsumedLast30Days: 50,
          globalDiscardedLast30Days: 20,
          assistantQueriesLast30Days: 100,
          householdsUsingAssistantLast30Days: 8,
        );
        final adminProvider = AdminProvider(GetAdminStatsUseCase(adminRepo));
        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: kAdminUid, emailVerified: true),
        );

        await tester.pumpWidget(_wrap(adminProvider, authProvider));
        // addPostFrameCallback dispara loadStats() en el primer frame.
        await tester.pump();
        // La entrada escalonada de las tarjetas KPI (flutter_animate,
        // interval: 60ms sobre ~9 tarjetas) necesita más que un pump corto
        // para terminar del todo — un Timer todavía pendiente al final del
        // test rompe la verificación de invariantes de flutter_test.
        await tester.pump(const Duration(milliseconds: 1500));

        expect(find.text('Acceso denegado'), findsNothing);
        expect(adminProvider.stats.totalUsers, 42);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
