import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frescorden/config/app_config.dart';
import 'package:frescorden/config/theme/theme_provider.dart';
import 'package:frescorden/data/datasources/firestore_product_history_datasource.dart';
import 'package:frescorden/domain/entities/app_user.dart';
import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/entities/product_history_entry.dart';
import 'package:frescorden/domain/entities/recipe.dart';
import 'package:frescorden/domain/entities/recipe_ingredient.dart';
import 'package:frescorden/domain/entities/usability_survey_response.dart';
import 'package:frescorden/domain/repositories/i_activity_log_repository.dart';
import 'package:frescorden/domain/usecases/get_admin_stats_usecase.dart';
import 'package:frescorden/domain/usecases/get_analytics_usecase.dart';
import 'package:frescorden/presentation/providers/admin_provider.dart';
import 'package:frescorden/presentation/providers/analytics_provider.dart';
import 'package:frescorden/presentation/providers/auth_provider.dart';
import 'package:frescorden/presentation/providers/household_provider.dart';
import 'package:frescorden/presentation/providers/notification_settings_provider.dart';
import 'package:frescorden/presentation/providers/product_provider.dart';
import 'package:frescorden/presentation/providers/recipe_provider.dart';
import 'package:frescorden/presentation/providers/restock_prediction_provider.dart';
import 'package:frescorden/presentation/providers/shopping_provider.dart';
import 'package:frescorden/presentation/providers/usability_survey_provider.dart';
import 'package:frescorden/presentation/providers/user_banner_provider.dart';
import 'package:frescorden/presentation/screens/about_screen.dart';
import 'package:frescorden/presentation/screens/add_product_screen.dart';
import 'package:frescorden/presentation/screens/admin_dashboard_screen.dart';
import 'package:frescorden/presentation/screens/analytics_screen.dart';
import 'package:frescorden/presentation/screens/contact_screen.dart';
import 'package:frescorden/presentation/screens/detalle_receta_screen.dart';
import 'package:frescorden/presentation/screens/household_screen.dart';
import 'package:frescorden/presentation/screens/inicio_screen.dart';
import 'package:frescorden/presentation/screens/login_screen.dart';
import 'package:frescorden/presentation/screens/productos_screen.dart';
import 'package:frescorden/presentation/screens/recetas_screen.dart';
import 'package:frescorden/presentation/screens/settings_screen.dart';
import 'package:frescorden/presentation/screens/shopping_list_screen.dart';
import 'package:frescorden/presentation/screens/usability_survey_screen.dart';

import '../../support/fake_repositories.dart';
import '../../support/fake_services.dart';

class MockHistoryDataSource extends Mock
    implements FirestoreProductHistoryDataSource {}

void _mockPluginChannels() {
  AndroidFlutterLocalNotificationsPlugin.registerWith();

  const permissionsChannel =
      MethodChannel('flutter.baseflow.com/permissions/methods');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(permissionsChannel, (call) async {
    if (call.method == 'requestPermissions') return <int, int>{};
    if (call.method == 'checkPermissionStatus') return 1;
    return null;
  });

  const notificationsChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(notificationsChannel, (call) async {
    if (call.method == 'initialize') return true;
    return null;
  });
}

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap({
  required ProductProvider productProvider,
  required AuthProvider authProvider,
  required UserBannerProvider bannerProvider,
  UsabilitySurveyProvider? usabilityProvider,
  RecipeProvider? recipeProvider,
  RestockPredictionProvider? restockProvider,
  HouseholdProvider? householdProvider,
  IActivityLogRepository? activityLogRepository,
  AnalyticsProvider? analyticsProvider,
  ShoppingProvider? shoppingProvider,
  AdminProvider? adminProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<UserBannerProvider>.value(value: bannerProvider),
      ChangeNotifierProvider<RecipeProvider>.value(
        value: recipeProvider ?? RecipeProvider(FakeRecipeRepository([])),
      ),
      ChangeNotifierProvider<RestockPredictionProvider>.value(
        // Default: un mock que nunca toca Firebase (a diferencia de
        // FirestoreProductHistoryDataSource real) — seguro de construir
        // de forma inmediata (.value), ya que ningún test que no pase su
        // propio restockProvider llama a setActiveHousehold.
        value: restockProvider ?? RestockPredictionProvider(MockHistoryDataSource()),
      ),
      ChangeNotifierProvider<UsabilitySurveyProvider>.value(
        value: usabilityProvider ??
            UsabilitySurveyProvider(FakeUsabilitySurveyRepository()),
      ),
      ChangeNotifierProvider<HouseholdProvider>.value(
        value: householdProvider ??
            HouseholdProvider(
              FakeHouseholdRepository(),
              const Stream<AppUser?>.empty(),
              FakeHouseholdAnalyticsService(),
            ),
      ),
      Provider<IActivityLogRepository>.value(
        value: activityLogRepository ?? FakeActivityLogRepository(),
      ),
      ChangeNotifierProvider<AnalyticsProvider>.value(
        value: analyticsProvider ??
            AnalyticsProvider(GetAnalyticsUseCase(FakeAnalyticsRepository())),
      ),
      ChangeNotifierProvider<ShoppingProvider>.value(
        value: shoppingProvider ?? ShoppingProvider(FakeShoppingRepository({})),
      ),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<NotificationSettingsProvider>(
        create: (_) => NotificationSettingsProvider(),
      ),
      ChangeNotifierProvider<AdminProvider>.value(
        value: adminProvider ??
            AdminProvider(GetAdminStatsUseCase(FakeAdminRepository())),
      ),
    ],
    child: const MaterialApp(home: InicioScreen()),
  );
}

Product _product({
  required String id,
  required String name,
  int quantity = 1,
  String unit = 'unidad',
  DateTime? entryDate,
  DateTime? expirationDate,
  int? minStock,
  FoodCategory category = FoodCategory.otros,
}) {
  return Product(
    id: id,
    name: name,
    quantity: quantity,
    unit: unit,
    entryDate: entryDate ?? DateTime.now(),
    expirationDate: expirationDate,
    minStock: minStock,
    category: category,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'home_tutorial_seen': true,
      'usability_survey_prompted': true,
    });
    _mockPluginChannels();
  });

  group('Estabilidad visual: InicioScreen — panel lateral', () {
    testWidgets(
      'Escenario: el panel lateral muestra sus secciones e ítems sin '
      'excepciones',
      (tester) async {
        _useTallViewport(tester);
        final productProvider = ProductProvider(FakeProductRepository());
        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true),
        );
        final bannerProvider = UserBannerProvider();
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            bannerProvider: bannerProvider,
          ),
        );
        await tester.pump();

        tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('PRINCIPAL'), findsOneWidget);
        expect(find.text('PLANIFICACIÓN'), findsOneWidget);
        expect(find.text('CUENTA'), findsOneWidget);
        expect(find.text('Inicio'), findsOneWidget);
        expect(find.text('Mi Hogar'), findsOneWidget);
        expect(find.text('Cerrar Sesión'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: elegir una foto del selector de banner la aplica al '
      'encabezado',
      (tester) async {
        _useTallViewport(tester);
        final productProvider = ProductProvider(FakeProductRepository());
        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true),
        );
        final bannerProvider = UserBannerProvider();
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            bannerProvider: bannerProvider,
          ),
        );
        await tester.pump();

        final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
        scaffoldState.openDrawer();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Personaliza tu banner'), findsOneWidget);

        await tester.tap(find.byTooltip('Perritos.jpg'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(bannerProvider.selectedBannerName, 'Perritos.jpg');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: elegir "Predeterminado" limpia el banner personalizado',
      (tester) async {
        _useTallViewport(tester);
        final productProvider = ProductProvider(FakeProductRepository());
        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true),
        );
        final bannerProvider = UserBannerProvider();
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            bannerProvider: bannerProvider,
          ),
        );
        await tester.pump();

        tester
            .state<ScaffoldState>(find.byType(Scaffold).first)
            .openDrawer();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        await tester.tap(find.byTooltip('Predeterminado'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(bannerProvider.selectedBannerName, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Estabilidad visual: InicioScreen — invitación a la encuesta de '
      'usabilidad (SUS + NPS)', () {
    testWidgets(
      'Escenario: en la primera visita a Inicio, se guarda la marca de '
      'tiempo pero todavía no se invita a la encuesta',
      (tester) async {
        SharedPreferences.setMockInitialValues({'home_tutorial_seen': true});
        final productProvider = ProductProvider(FakeProductRepository());
        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true),
        );
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            bannerProvider: UserBannerProvider(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('¿Nos ayudas con tu opinión?'), findsNothing);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('first_inicio_visit'), isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con menos de 2 días desde la primera visita, no se '
      'invita todavía a la encuesta',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'home_tutorial_seen': true,
          'first_inicio_visit':
              DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        });
        final productProvider = ProductProvider(FakeProductRepository());
        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true),
        );
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            bannerProvider: UserBannerProvider(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('¿Nos ayudas con tu opinión?'), findsNothing);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('usability_survey_prompted'), isNot(true));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: pasados 2 días sin responder, se invita a la encuesta y '
      'aceptar navega al formulario',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'home_tutorial_seen': true,
          'first_inicio_visit':
              DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        });
        final productProvider = ProductProvider(FakeProductRepository());
        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true),
        );
        final usabilityProvider =
            UsabilitySurveyProvider(FakeUsabilitySurveyRepository());
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            bannerProvider: UserBannerProvider(),
            usabilityProvider: usabilityProvider,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('¿Nos ayudas con tu opinión?'), findsOneWidget);

        await tester.tap(find.text('Claro, vamos'));
        await tester.pumpAndSettle();

        expect(find.byType(UsabilitySurveyScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: pasados 2 días pero ya había respondido antes, no se '
      'invita de nuevo (y queda marcado como ya ofrecido)',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'home_tutorial_seen': true,
          'first_inicio_visit':
              DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        });
        final repo = FakeUsabilitySurveyRepository();
        await repo.submit(
          UsabilitySurveyResponse(
            uid: 'uid-1',
            susAnswers: List.filled(10, 3),
            npsScore: 8,
            submittedAt: DateTime.now(),
          ),
        );
        final productProvider = ProductProvider(FakeProductRepository());
        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true),
        );
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            bannerProvider: UserBannerProvider(),
            usabilityProvider: UsabilitySurveyProvider(repo),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('¿Nos ayudas con tu opinión?'), findsNothing);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('usability_survey_prompted'), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Estabilidad visual: InicioScreen — dashboard con inventario', () {
    testWidgets(
      'Escenario: con un producto próximo a vencer, la tarjeta "Vencen '
      'pronto" lo refleja y navega a Productos',
      (tester) async {
        _useTallViewport(tester);
        final repo = FakeProductRepository();
        final productProvider = ProductProvider(repo);
        productProvider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [
          _product(
            id: 'p1',
            name: 'Yogurt',
            expirationDate: DateTime.now().add(const Duration(days: 1)),
          ),
        ]);
        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true),
        );
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            bannerProvider: UserBannerProvider(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Vencen pronto'), findsOneWidget);

        await tester.tap(find.text('Vencen pronto'));
        await tester.pumpAndSettle();

        expect(find.byType(ProductosScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con un producto en stock bajo, la tarjeta '
      'correspondiente lo refleja',
      (tester) async {
        _useTallViewport(tester);
        final repo = FakeProductRepository();
        final productProvider = ProductProvider(repo);
        productProvider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [
          _product(id: 'p1', name: 'Arroz', quantity: 1, minStock: 2),
        ]);
        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true),
        );
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            bannerProvider: UserBannerProvider(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Stock bajo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con historial suficiente, la tarjeta de predicciones de '
      'reposición se muestra y "Agregar de nuevo" navega al formulario',
      (tester) async {
        _useTallViewport(tester);
        final repo = FakeProductRepository();
        final productProvider = ProductProvider(repo);
        productProvider.setActiveHousehold('hogar-1');
        final now = DateTime.now();
        repo.emit('hogar-1', [
          _product(
            id: 'p1',
            name: 'Leche',
            entryDate: now.subtract(const Duration(days: 8)),
          ),
        ]);

        final historyDataSource = MockHistoryDataSource();
        when(() => historyDataSource.getAll('hogar-1')).thenAnswer(
          (_) async => [
            ProductHistoryEntry(
              productId: 'old-1',
              name: 'Leche',
              category: FoodCategory.lacteos,
              entryDate: now.subtract(const Duration(days: 20)),
              resolvedAt: now.subtract(const Duration(days: 19)),
              outcome: ProductOutcome.consumedOnTime,
            ),
            ProductHistoryEntry(
              productId: 'old-2',
              name: 'Leche',
              category: FoodCategory.lacteos,
              entryDate: now.subtract(const Duration(days: 10)),
              resolvedAt: now.subtract(const Duration(days: 9)),
              outcome: ProductOutcome.consumedOnTime,
            ),
          ],
        );
        final restockProvider = RestockPredictionProvider(historyDataSource);
        restockProvider.setActiveHousehold('hogar-1');
        // Nota: NO se usa `await Future.delayed(Duration.zero)` acá — dentro
        // de un testWidgets (zona FakeAsync), un Future.delayed real nunca
        // se resuelve si nada avanza el reloj falso para él (deja el test
        // colgado para siempre). Los `tester.pump()` de abajo, después de
        // montar el widget, ya se encargan de drenar la carga pendiente.

        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true),
        );
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            bannerProvider: UserBannerProvider(),
            restockProvider: restockProvider,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Se te puede estar acabando'), findsOneWidget);
        expect(find.text('Leche'), findsOneWidget);

        await tester.tap(find.byTooltip('Agregar de nuevo'));
        // pumpAndSettle no sirve acá: AddProductScreen tiene una animación
        // que no termina nunca (lo deja esperando para siempre) — un pump
        // acotado es suficiente para confirmar que la navegación ocurrió.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(AddProductScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con una receta sugerida y un ingrediente faltante, la '
      'tarjeta lo indica y navega al detalle',
      (tester) async {
        _useTallViewport(tester);
        final repo = FakeProductRepository();
        final productProvider = ProductProvider(repo);
        productProvider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [_product(id: 'p1', name: 'Tomate')]);

        const recipe = Recipe(
          id: 'r1',
          name: 'Ensalada',
          servings: 2,
          ingredients: [
            RecipeIngredient(name: 'lechuga', quantity: 1, unit: 'unidad'),
          ],
          imagePath: 'assets/verduras.png',
          steps: ['Mezclar todo'],
        );
        final recipeProvider = RecipeProvider(FakeRecipeRepository([recipe]));

        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true),
        );
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            bannerProvider: UserBannerProvider(),
            recipeProvider: recipeProvider,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Receta sugerida de hoy'), findsOneWidget);
        expect(find.text('Ensalada'), findsOneWidget);
        expect(find.text('Te faltan 1 ingrediente'), findsOneWidget);

        await tester.tap(find.text('Ensalada'));
        await tester.pumpAndSettle();

        expect(find.byType(DetalleRecetaScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con todos los ingredientes de la receta sugerida '
      'disponibles, lo indica así',
      (tester) async {
        _useTallViewport(tester);
        final repo = FakeProductRepository();
        final productProvider = ProductProvider(repo);
        productProvider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [_product(id: 'p1', name: 'Lechuga')]);

        const recipe = Recipe(
          id: 'r1',
          name: 'Ensalada',
          servings: 2,
          ingredients: [
            RecipeIngredient(name: 'lechuga', quantity: 1, unit: 'unidad'),
          ],
          imagePath: 'assets/verduras.png',
          steps: ['Mezclar todo'],
        );
        final recipeProvider = RecipeProvider(FakeRecipeRepository([recipe]));

        final authProvider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true),
        );
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            bannerProvider: UserBannerProvider(),
            recipeProvider: recipeProvider,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Ya tienes todo lo que necesitas'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Estabilidad visual: InicioScreen — navegación del panel lateral', () {
    Future<ProductProvider> mount(
      WidgetTester tester, {
      AuthProvider? authProvider,
      HouseholdProvider? householdProvider,
      AnalyticsProvider? analyticsProvider,
      ShoppingProvider? shoppingProvider,
      AdminProvider? adminProvider,
    }) async {
      _useTallViewport(tester);
      final repo = FakeProductRepository();
      final productProvider = ProductProvider(repo);
      productProvider.setActiveHousehold('hogar-1');
      repo.emit('hogar-1', [_product(id: 'p1', name: 'Arroz')]);
      addTearDown(productProvider.dispose);

      await tester.pumpWidget(
        _wrap(
          productProvider: productProvider,
          authProvider: authProvider ??
              AuthProvider(
                FakeAuthRepository()
                  ..currentUser =
                      const AppUser(uid: 'uid-1', emailVerified: true),
              ),
          bannerProvider: UserBannerProvider(),
          householdProvider: householdProvider,
          analyticsProvider: analyticsProvider,
          shoppingProvider: shoppingProvider,
          adminProvider: adminProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // pumpAndSettle (no un pump de duración fija): el controlador de
      // apertura del Drawer no completa su animación con un solo pump
      // grande cuando el dashboard (inventario no vacío) ya está en
      // pantalla — confirmado inspeccionando el árbol de render
      // (widthFactor se quedaba en 0.0). Ningún widget de esta pantalla
      // tiene una animación perpetua, así que esto no se queda colgado.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      return productProvider;
    }

    testWidgets('Escenario: "Productos" navega a ProductosScreen', (
      tester,
    ) async {
      await mount(tester);

      await tester.tap(find.text('Productos (1)'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductosScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Escenario: "Mi Hogar" navega a HouseholdScreen', (
      tester,
    ) async {
      await mount(tester);

      await tester.tap(find.text('Mi Hogar'));
      await tester.pumpAndSettle();

      expect(find.byType(HouseholdScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Escenario: "Recetas" navega a RecetasScreen', (
      tester,
    ) async {
      await mount(tester);

      await tester.tap(find.text('Recetas'));
      await tester.pumpAndSettle();

      expect(find.byType(RecetasScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Escenario: "Lista de Compras" navega a ShoppingListScreen', (
      tester,
    ) async {
      await mount(tester);

      await tester.tap(find.text('Lista de Compras'));
      await tester.pumpAndSettle();

      expect(find.byType(ShoppingListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Escenario: "Analíticas" navega a AnalyticsScreen', (
      tester,
    ) async {
      await mount(tester);

      await tester.tap(find.text('Analíticas'));
      await tester.pumpAndSettle();

      expect(find.byType(AnalyticsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Escenario: "Configuración" navega a SettingsScreen', (
      tester,
    ) async {
      await mount(tester);

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Escenario: "Encuesta de Usabilidad" navega a UsabilitySurveyScreen',
      (tester) async {
        await mount(tester);

        await tester.tap(find.text('Encuesta de Usabilidad'));
        await tester.pumpAndSettle();

        expect(find.byType(UsabilitySurveyScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Escenario: "Contacto" navega a ContactScreen', (
      tester,
    ) async {
      await mount(tester);

      await tester.tap(find.text('Contacto'));
      await tester.pumpAndSettle();

      expect(find.byType(ContactScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Escenario: "Acerca de" navega a AboutScreen', (
      tester,
    ) async {
      await mount(tester);

      await tester.tap(find.text('Acerca de'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Escenario: un usuario normal no ve "Panel Administrativo"',
      (tester) async {
        await mount(tester);

        expect(find.text('Panel Administrativo'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: el admin ve "Panel Administrativo" y navega a '
      'AdminDashboardScreen',
      (tester) async {
        await mount(
          tester,
          authProvider: AuthProvider(
            FakeAuthRepository()
              ..currentUser =
                  const AppUser(uid: kAdminUid, emailVerified: true),
          ),
        );

        await tester.tap(find.text('Panel Administrativo'));
        await tester.pumpAndSettle();

        expect(find.byType(AdminDashboardScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: "Cerrar Sesión" cierra la sesión y navega al login',
      (tester) async {
        final repo = FakeAuthRepository();
        await mount(
          tester,
          authProvider: AuthProvider(
            repo
              ..currentUser =
                  const AppUser(uid: 'uid-1', emailVerified: true),
          ),
        );

        await tester.tap(find.text('Cerrar Sesión'));
        await tester.pumpAndSettle();

        expect(repo.calls, contains('signOut'));
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
