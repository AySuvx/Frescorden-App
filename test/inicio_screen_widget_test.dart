import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frescorden/data/datasources/firestore_product_history_datasource.dart';
import 'package:frescorden/domain/entities/app_user.dart';
import 'package:frescorden/presentation/providers/auth_provider.dart';
import 'package:frescorden/presentation/providers/product_provider.dart';
import 'package:frescorden/presentation/providers/recipe_provider.dart';
import 'package:frescorden/presentation/providers/restock_prediction_provider.dart';
import 'package:frescorden/presentation/providers/usability_survey_provider.dart';
import 'package:frescorden/presentation/providers/user_banner_provider.dart';
import 'package:frescorden/presentation/screens/inicio_screen.dart';

import 'support/fake_repositories.dart';

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
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<UserBannerProvider>.value(value: bannerProvider),
      ChangeNotifierProvider<RecipeProvider>(
        create: (_) => RecipeProvider(FakeRecipeRepository([])),
      ),
      ChangeNotifierProvider<RestockPredictionProvider>(
        create: (_) =>
            RestockPredictionProvider(FirestoreProductHistoryDataSource()),
      ),
      ChangeNotifierProvider<UsabilitySurveyProvider>(
        create: (_) => UsabilitySurveyProvider(FakeUsabilitySurveyRepository()),
      ),
    ],
    child: const MaterialApp(home: InicioScreen()),
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
  });
}
