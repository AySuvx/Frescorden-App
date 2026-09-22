// Pruebas de integración (Sección 12.2 de la Guía): Use Case → Repository
// → DataSource real (FirestoreHouseholdDataSource / FirestoreProductDataSource)
// → Firebase Emulator Suite (Firestore + Auth). A diferencia de las pruebas
// unitarias de test/domain/usecases/, aquí NO se usan fakes de repositorio:
// se ejercita la implementación real de Firestore, autenticada contra el
// Auth Emulator, para que firestore.rules también se evalúe de verdad.
//
// Correr con el Firebase Emulator Suite activo (ver README.md de esta
// carpeta) y en un device con soporte de plugins Firebase — Chrome (web).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frescorden/data/datasources/firestore_household_datasource.dart';
import 'package:frescorden/data/datasources/firestore_product_datasource.dart';
import 'package:frescorden/data/repositories/household_repository_impl.dart';
import 'package:frescorden/data/repositories/product_repository_impl.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/requests/save_product_request.dart';
import 'package:frescorden/domain/usecases/household/create_household_usecase.dart';
import 'package:frescorden/domain/usecases/household/join_household_usecase.dart';
import 'package:frescorden/domain/usecases/product/add_product_usecase.dart';
import 'package:frescorden/domain/usecases/product/update_product_usecase.dart';

import '../test/support/fake_services.dart';
import 'support/firebase_emulator_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Construidos DESPUÉS de Firebase.initializeApp() (en setUpAll): el
  // constructor por defecto de cada DataSource resuelve
  // FirebaseFirestore.instance de inmediato, que lanza [core/no-app] si
  // todavía no existe una app Firebase.
  late final HouseholdRepositoryImpl householdRepository;
  late final ProductRepositoryImpl productRepository;

  setUpAll(() async {
    await initializeFirebaseForEmulatorTests();
    householdRepository = HouseholdRepositoryImpl(FirestoreHouseholdDataSource());
    productRepository = ProductRepositoryImpl(FirestoreProductDataSource());
  });

  tearDown(() async {
    await FirebaseAuth.instance.signOut();
  });

  group('Historia de integración: crear un hogar y unirse por código', () {
    testWidgets(
      'Escenario: el creador queda como único miembro y quien usa el código se une',
      (tester) async {
        final creatorUid = await signInAsNewAnonymousUser();
        final createUseCase = CreateHouseholdUseCase(
          householdRepository,
          FakeHouseholdAnalyticsService(),
        );

        final household = await createUseCase.call(
          name: 'Hogar de integración ${DateTime.now().microsecondsSinceEpoch}',
          creatorUid: creatorUid,
        );

        expect(household.members, [creatorUid]);
        expect(household.isAdmin(creatorUid), isTrue);

        final joinerUid = await signInAsNewAnonymousUser();
        final joinUseCase = JoinHouseholdUseCase(
          householdRepository,
          FakeHouseholdAnalyticsService(),
        );

        final joined = await joinUseCase.call(
          code: household.inviteCode,
          uid: joinerUid,
          email: 'joiner@example.com',
        );

        expect(joined.id, household.id);
        expect(joined.members, containsAll([creatorUid, joinerUid]));
      },
    );
  });

  group('Historia de integración: inventario de productos dentro de un hogar', () {
    testWidgets(
      'Escenario: un miembro agrega, acumula por nombre y edita un producto',
      (tester) async {
        final ownerUid = await signInAsNewAnonymousUser();
        final household = await CreateHouseholdUseCase(
          householdRepository,
          FakeHouseholdAnalyticsService(),
        ).call(
          name: 'Hogar con inventario ${DateTime.now().microsecondsSinceEpoch}',
          creatorUid: ownerUid,
        );

        final addUseCase = AddProductUseCase(productRepository, FakeNotificationService());

        final first = await addUseCase.call(
          household.id,
          SaveProductRequest(
            name: 'Leche',
            quantity: 2,
            unit: 'litros',
            entryDate: DateTime.now(),
            category: FoodCategory.lacteos,
          ),
        );
        expect(first.wasAccumulated, isFalse);
        expect(first.product.quantity, 2);

        final accumulated = await addUseCase.call(
          household.id,
          SaveProductRequest(
            name: 'Leche',
            quantity: 3,
            unit: 'litros',
            entryDate: DateTime.now(),
            category: FoodCategory.lacteos,
          ),
        );
        expect(accumulated.wasAccumulated, isTrue);
        expect(accumulated.product.id, first.product.id);
        expect(accumulated.product.quantity, 5);

        final updateUseCase = UpdateProductUseCase(productRepository, FakeNotificationService());
        final updated = await updateUseCase.call(
          household.id,
          SaveProductRequest(
            id: accumulated.product.id,
            name: 'Leche',
            quantity: 1,
            unit: 'litros',
            entryDate: DateTime.now(),
            category: FoodCategory.lacteos,
          ),
        );
        expect(updated.quantity, 1);

        await productRepository.deleteProduct(household.id, updated.id);
        final afterDelete = await productRepository.findByName(household.id, 'Leche');
        expect(afterDelete, isNull);
      },
    );

    testWidgets(
      'Escenario: quien no es miembro del hogar recibe permission-denied al agregar un producto',
      (tester) async {
        final ownerUid = await signInAsNewAnonymousUser();
        final household = await CreateHouseholdUseCase(
          householdRepository,
          FakeHouseholdAnalyticsService(),
        ).call(
          name: 'Hogar ajeno ${DateTime.now().microsecondsSinceEpoch}',
          creatorUid: ownerUid,
        );

        await signInAsNewAnonymousUser();
        final addUseCase = AddProductUseCase(productRepository, FakeNotificationService());

        await expectLater(
          addUseCase.call(
            household.id,
            SaveProductRequest(
              name: 'Intruso',
              quantity: 1,
              unit: 'u',
              entryDate: DateTime.now(),
            ),
          ),
          throwsA(isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          )),
        );
      },
    );
  });
}
