// test/household_provider_test.dart
//
// BDD (Given/When/Then) de HouseholdProvider, con FakeHouseholdRepository
// (test/support/fake_repositories.dart) en vez de Firestore.
//
// Nota (Fase 6, Módulo 3): el brief de este módulo no dio un escenario
// puntual para HouseholdProvider (a diferencia de ProductProvider/
// ShoppingProvider/RecipeProvider) — se cubren las reglas de permisos de
// removeMember/leaveHousehold, que son la lógica de negocio real más
// valiosa y frágil del provider (ver comentarios del propio
// household_provider.dart junto a cada método).
//
// setUid() es intencionalmente público "para tests que quieran simular el
// cambio sin pasar por un Stream real" (ver su propio doc comment) — se usa
// acá en vez de construir un Stream<AppUser?> real.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/app_user.dart';
import 'package:frescorden/domain/entities/household.dart';
import 'package:frescorden/domain/repositories/i_household_repository.dart';
import 'package:frescorden/presentation/providers/household_provider.dart';

import 'support/fake_repositories.dart';

Household _household({
  required String createdBy,
  required List<String> members,
}) {
  final now = DateTime(2026, 1, 1);
  return Household(
    id: 'hogar-1',
    name: 'Mi Hogar',
    createdBy: createdBy,
    members: members,
    inviteCode: 'ABC123',
    codeExpiresAt: now.add(const Duration(hours: 24)),
    createdAt: now,
  );
}

/// Deja el provider con un hogar activo y su lista de miembros lista para
/// probar removeMember/leaveHousehold, simulando la cadena reactiva real
/// (uid → activeHouseholdId → household) sin un `Stream<AppUser?>` real.
Future<HouseholdProvider> _providerWithHousehold(
  FakeHouseholdRepository repo,
  Household household,
  String currentUid,
) async {
  final provider = HouseholdProvider(repo, const Stream<AppUser?>.empty());
  provider.setUid(currentUid);
  repo.emitActiveId(household.id);
  await pumpEventQueue();
  repo.emitHousehold(household);
  await pumpEventQueue();
  return provider;
}

void main() {
  group('Historia de Usuario: Como administrador de un hogar, quiero poder '
      'gestionar quién es miembro', () {
    late FakeHouseholdRepository repo;

    setUp(() => repo = FakeHouseholdRepository());
    tearDown(() => repo.dispose());

    test(
      'Escenario: el administrador expulsa a otro miembro exitosamente',
      () async {
        // Dado un hogar donde YO soy el administrador
        final hogar = _household(createdBy: 'admin-uid', members: ['admin-uid', 'miembro-uid']);
        final provider = await _providerWithHousehold(repo, hogar, 'admin-uid');
        addTearDown(provider.dispose);

        // Cuando expulso a otro miembro
        await provider.removeMember('miembro-uid');

        // Entonces la operación se delega al repositorio sin excepción
        expect(repo.removedMemberUids, ['miembro-uid']);
      },
    );

    test(
      'Escenario: un miembro regular NO puede expulsar a otro miembro',
      () async {
        // Dado un hogar donde YO soy un miembro regular (no el admin)
        final hogar = _household(
          createdBy: 'admin-uid',
          members: ['admin-uid', 'miembro-uid', 'otro-miembro-uid'],
        );
        final provider = await _providerWithHousehold(repo, hogar, 'miembro-uid');
        addTearDown(provider.dispose);

        // Cuando intento expulsar a otro miembro
        // Entonces se lanza HouseholdException y nunca se llega al repositorio
        await expectLater(
          () => provider.removeMember('otro-miembro-uid'),
          throwsA(isA<HouseholdException>()),
        );
        expect(repo.removedMemberUids, isEmpty);
      },
    );

    test(
      'Escenario: el administrador no puede expulsarse a sí mismo',
      () async {
        // Dado un hogar donde YO soy el administrador
        final hogar = _household(createdBy: 'admin-uid', members: ['admin-uid', 'miembro-uid']);
        final provider = await _providerWithHousehold(repo, hogar, 'admin-uid');
        addTearDown(provider.dispose);

        // Cuando intento "expulsarme" a mí mismo
        // Entonces se lanza HouseholdException
        await expectLater(
          () => provider.removeMember('admin-uid'),
          throwsA(isA<HouseholdException>()),
        );
        expect(repo.removedMemberUids, isEmpty);
      },
    );
  });

  group('Historia de Usuario: Como miembro de un hogar, quiero poder '
      'salir de él sin dejarlo huérfano', () {
    late FakeHouseholdRepository repo;

    setUp(() => repo = FakeHouseholdRepository());
    tearDown(() => repo.dispose());

    test(
      'Escenario: un miembro regular sale del hogar exitosamente',
      () async {
        // Dado un hogar donde YO soy un miembro regular
        final hogar = _household(createdBy: 'admin-uid', members: ['admin-uid', 'miembro-uid']);
        final provider = await _providerWithHousehold(repo, hogar, 'miembro-uid');
        addTearDown(provider.dispose);

        // Cuando salgo del hogar
        await provider.leaveHousehold();

        // Entonces me quito de members y se limpia mi activeHouseholdId
        expect(repo.removedMemberUids, ['miembro-uid']);
        expect(repo.clearedActiveHouseholdUids, ['miembro-uid']);
      },
    );

    test(
      'Escenario: el administrador NO puede salir de su propio hogar',
      () async {
        // Dado un hogar donde YO soy el administrador
        final hogar = _household(createdBy: 'admin-uid', members: ['admin-uid', 'miembro-uid']);
        final provider = await _providerWithHousehold(repo, hogar, 'admin-uid');
        addTearDown(provider.dispose);

        // Cuando intento salir del hogar
        // Entonces se lanza HouseholdException (debe expulsar a los demás
        // miembros primero)
        await expectLater(
          () => provider.leaveHousehold(),
          throwsA(isA<HouseholdException>()),
        );
        expect(repo.removedMemberUids, isEmpty);
        expect(repo.clearedActiveHouseholdUids, isEmpty);
      },
    );
  });
}
