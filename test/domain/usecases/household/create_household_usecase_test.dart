// test/domain/usecases/household/create_household_usecase_test.dart
//
// BDD (Given/When/Then) de CreateHouseholdUseCase, siguiendo el formato de
// la Sección 26 de la guía (caso válido / repositorio genera error), con
// dobles de prueba en vez de Firestore.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/household.dart';
import 'package:frescorden/domain/usecases/household/create_household_usecase.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fake_services.dart';

Household _household() {
  return Household(
    id: 'h1',
    name: 'Mi Hogar',
    createdBy: 'uid-admin',
    members: const ['uid-admin'],
    inviteCode: 'ABC123',
    codeExpiresAt: DateTime(2026, 1, 2),
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('Historia de Usuario: Como usuario, quiero crear un hogar nuevo', () {
    late FakeHouseholdRepository repo;
    late FakeHouseholdAnalyticsService analytics;
    late CreateHouseholdUseCase useCase;

    setUp(() {
      repo = FakeHouseholdRepository();
      analytics = FakeHouseholdAnalyticsService();
      useCase = CreateHouseholdUseCase(repo, analytics);
    });

    tearDown(() => repo.dispose());

    test(
      'Escenario: caso válido — se crea el hogar y se registra el evento '
      'de analítica',
      () async {
        // Dado que el repositorio puede crear el hogar
        repo.createHouseholdResult = _household();

        // Cuando se solicita crear un hogar nuevo
        final result = await useCase(
          name: 'Mi Hogar',
          creatorUid: 'uid-admin',
          creatorEmail: 'admin@frescorden.com',
        );
        await pumpEventQueue();

        // Entonces se devuelve el hogar creado y se registra el evento
        expect(result.id, 'h1');
        expect(analytics.householdCreatedCount, 1);
      },
    );

    test(
      'Escenario: el repositorio genera un error al crear',
      () async {
        // Dado que el repositorio falla (p. ej. sin conexión)
        repo.createHouseholdError = Exception('sin conexión');

        // Cuando se intenta crear el hogar
        // Entonces el error se propaga y no se registra el evento
        await expectLater(
          () => useCase(name: 'Mi Hogar', creatorUid: 'uid-admin'),
          throwsA(isException),
        );
        await pumpEventQueue();
        expect(analytics.householdCreatedCount, 0);
      },
    );
  });
}
