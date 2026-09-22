// test/domain/usecases/household/remove_member_usecase_test.dart
//
// BDD (Given/When/Then) de RemoveMemberUseCase, aislado del Provider (ya
// cubierto a nivel de integración en household_provider_test.dart). Cubre
// las 4 combinaciones de autorización: admin expulsa a otro, miembro
// regular intenta expulsar, admin intenta autoexpulsarse y un miembro
// regular sale voluntariamente.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/household.dart';
import 'package:frescorden/domain/repositories/i_household_repository.dart';
import 'package:frescorden/domain/usecases/household/remove_member_usecase.dart';

import '../../../support/fake_repositories.dart';

Household _household() {
  return Household(
    id: 'h1',
    name: 'Casa de Juan',
    createdBy: 'uid-admin',
    members: const ['uid-admin', 'uid-miembro'],
    inviteCode: 'ABC123',
    codeExpiresAt: DateTime(2026, 1, 2),
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('Historia de Usuario: Como administrador de un hogar, quiero '
      'poder gestionar quién es miembro', () {
    late FakeHouseholdRepository repo;
    late RemoveMemberUseCase useCase;

    setUp(() {
      repo = FakeHouseholdRepository();
      useCase = RemoveMemberUseCase(repo);
    });

    tearDown(() => repo.dispose());

    test(
      'Escenario: caso válido — el administrador expulsa a otro miembro',
      () async {
        // Cuando el admin expulsa a un miembro regular
        await useCase(
          _household(),
          requesterUid: 'uid-admin',
          targetUid: 'uid-miembro',
        );

        // Entonces se quita al miembro y no se limpia el hogar activo
        // del admin (no es autoexpulsión)
        expect(repo.removedMemberUids, ['uid-miembro']);
        expect(repo.clearedActiveHouseholdUids, isEmpty);
      },
    );

    test(
      'Escenario: un miembro regular intenta expulsar a otro — se rechaza',
      () async {
        await expectLater(
          () => useCase(
            _household(),
            requesterUid: 'uid-miembro',
            targetUid: 'uid-admin',
          ),
          throwsA(isA<HouseholdException>()),
        );
        expect(repo.removedMemberUids, isEmpty);
      },
    );

    test(
      'Escenario: el administrador intenta expulsarse a sí mismo — se '
      'rechaza (debe usar "salir del hogar" con otro admin, o transferir '
      'el rol)',
      () async {
        await expectLater(
          () => useCase(
            _household(),
            requesterUid: 'uid-admin',
            targetUid: 'uid-admin',
          ),
          throwsA(isA<HouseholdException>()),
        );
        expect(repo.removedMemberUids, isEmpty);
      },
    );

    test(
      'Escenario: un miembro regular sale voluntariamente del hogar',
      () async {
        // Cuando el propio miembro se retira
        await useCase(
          _household(),
          requesterUid: 'uid-miembro',
          targetUid: 'uid-miembro',
        );

        // Entonces se quita a sí mismo Y se limpia su hogar activo
        expect(repo.removedMemberUids, ['uid-miembro']);
        expect(repo.clearedActiveHouseholdUids, ['uid-miembro']);
      },
    );

    test(
      'Escenario: el repositorio genera un error al expulsar',
      () async {
        repo.removeMemberError = Exception('sin conexión');

        await expectLater(
          () => useCase(
            _household(),
            requesterUid: 'uid-admin',
            targetUid: 'uid-miembro',
          ),
          throwsA(isException),
        );
      },
    );
  });
}
