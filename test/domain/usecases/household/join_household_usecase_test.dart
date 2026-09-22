// test/domain/usecases/household/join_household_usecase_test.dart
//
// BDD (Given/When/Then) de JoinHouseholdUseCase, siguiendo el formato de
// la Sección 26 de la guía (caso válido / código inválido → repositorio
// genera error), con dobles de prueba en vez de Firestore.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/household.dart';
import 'package:frescorden/domain/repositories/i_household_repository.dart';
import 'package:frescorden/domain/usecases/household/join_household_usecase.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fake_services.dart';

Household _household() {
  return Household(
    id: 'h1',
    name: 'Casa de Juan',
    createdBy: 'uid-admin',
    members: const ['uid-admin', 'uid-nuevo'],
    inviteCode: 'XYZ789',
    codeExpiresAt: DateTime(2026, 1, 2),
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('Historia de Usuario: Como usuario, quiero unirme a un hogar '
      'existente con un código de invitación', () {
    late FakeHouseholdRepository repo;
    late FakeHouseholdAnalyticsService analytics;
    late JoinHouseholdUseCase useCase;

    setUp(() {
      repo = FakeHouseholdRepository();
      analytics = FakeHouseholdAnalyticsService();
      useCase = JoinHouseholdUseCase(repo, analytics);
    });

    tearDown(() => repo.dispose());

    test(
      'Escenario: caso válido — se une al hogar y se registra el evento '
      'de analítica',
      () async {
        // Dado un código de invitación vigente
        repo.joinHouseholdResult = _household();

        // Cuando el usuario se une con ese código
        final result = await useCase(
          code: 'XYZ789',
          uid: 'uid-nuevo',
          email: 'nuevo@frescorden.com',
        );
        await pumpEventQueue();

        // Entonces se devuelve el hogar y se registra el evento
        expect(result.id, 'h1');
        expect(result.members, contains('uid-nuevo'));
        expect(analytics.householdJoinedCount, 1);
      },
    );

    test(
      'Escenario: código inexistente o expirado — el repositorio rechaza '
      'la unión y no se registra el evento',
      () async {
        // Dado un código que ya no sirve
        repo.joinHouseholdError = const HouseholdException(
          'El código de invitación no es válido o ya expiró.',
        );

        // Cuando el usuario intenta unirse con ese código
        // Entonces se propaga el HouseholdException, sin registrar el evento
        await expectLater(
          () => useCase(code: 'CADUCO', uid: 'uid-nuevo'),
          throwsA(isA<HouseholdException>()),
        );
        await pumpEventQueue();
        expect(analytics.householdJoinedCount, 0);
      },
    );
  });
}
