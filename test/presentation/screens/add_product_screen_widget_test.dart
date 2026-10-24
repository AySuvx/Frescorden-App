// test/add_product_screen_widget_test.dart
//
// Widget tests de estabilidad visual de AddProductScreen: alta de un
// producto nuevo, edición de uno existente, y validaciones del
// formulario. Usa ProductProvider/AuthProvider reales con
// FakeProductRepository/FakeAuthRepository y FakeNotificationService (ver
// test/support/fake_services.dart) en vez de flutter_local_notifications.
//
// _checkExactAlarmPermission (ver AddProductScreen.initState) no necesita
// mockearse: corta en su primera línea con Platform.isAndroid == false,
// que es el host real de `flutter test` (Windows/Linux/macOS, nunca
// Android) — nunca llega a tocar permission_handler/device_info_plus.
//
// Dos particularidades de esta pantalla (larga, 349 líneas) frente al
// resto de la suite:
//  1. Navegar con Navigator.push necesita DOS pumps, no uno: un solo
//     `pump(600ms)` avanza el reloj pero no alcanza a construir el árbol
//     de la ruta nueva en ese mismo frame — un `pump()` vacío primero
//     (deja que se inserte la ruta) y luego el pump con duración (deja
//     que la transición termine) sí la deja completamente montada.
//  2. El formulario no cabe en el viewport default de flutter_test
//     (800x600 lógicos): se usa un viewport alto para que "Guardar" (al
//     final) sea alcanzable sin tener que simular un scroll.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frescorden/domain/entities/app_user.dart';
import 'package:frescorden/presentation/providers/auth_provider.dart';
import 'package:frescorden/presentation/providers/product_provider.dart';
import 'package:frescorden/presentation/screens/add_product_screen.dart';

import '../../support/fake_repositories.dart';
import '../../support/fake_services.dart';

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 12000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.text('abrir formulario'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Widget _wrap({
  required ProductProvider productProvider,
  required AuthProvider authProvider,
  Map<String, dynamic>? initialProduct,
}) {
  // Los providers van POR ENCIMA de MaterialApp (no dentro de `home`): cada
  // ruta empujada por el Navigator es un overlay hermano, no un
  // descendiente del contenido de la ruta anterior — un MultiProvider
  // metido dentro de `home` solo sería visible para esa primera ruta, y
  // AddProductScreen (empujado después) no lo encontraría
  // (ProviderNotFoundException).
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddProductScreen(
                    onSave: (_) {},
                    initialProduct: initialProduct,
                  ),
                ),
              ),
              child: const Text('abrir formulario'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Estabilidad visual: AddProductScreen', () {
    late FakeProductRepository productRepo;
    late FakeAuthRepository authRepo;
    late FakeNotificationService notificationService;
    late ProductProvider productProvider;
    late AuthProvider authProvider;

    setUp(() {
      productRepo = FakeProductRepository();
      authRepo = FakeAuthRepository()
        ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true);
      notificationService = FakeNotificationService();
      productProvider = ProductProvider(
        productRepo,
        null,
        null,
        notificationService,
      )..setActiveHousehold('hogar-1');
      authProvider = AuthProvider(authRepo);
    });

    tearDown(() {
      productProvider.dispose();
      productRepo.dispose();
    });

    testWidgets(
      'Escenario: registrar un producto nuevo válido lo guarda y cierra '
      'el formulario',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          _wrap(productProvider: productProvider, authProvider: authProvider),
        );
        await _openForm(tester);

        // El campo de nombre es el primer TextField del formulario (su
        // etiqueta "Nombre del producto" es un Text aparte, no parte de
        // la decoración del campo).
        await tester.enterText(find.byType(TextField).first, 'Leche');
        await tester.tap(find.text('Guardar'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(productRepo.added, hasLength(1));
        expect(productRepo.added.first.name, 'Leche');
        expect(notificationService.expirationAlerts, hasLength(1));
        // Se cerró el formulario y volvimos al botón de abrir.
        expect(find.text('abrir formulario'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: guardar sin nombre no guarda nada y muestra un aviso',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          _wrap(productProvider: productProvider, authProvider: authProvider),
        );
        await _openForm(tester);

        await tester.tap(find.text('Guardar'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(productRepo.added, isEmpty);
        expect(
          find.text('Por favor, completa todos los campos correctamente'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: editar un producto existente precarga sus datos en el '
      'formulario',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          _wrap(
            productProvider: productProvider,
            authProvider: authProvider,
            initialProduct: const {
              'id': 'prod-1',
              'name': 'Arroz',
              'quantity': '3',
              'unit': 'kg',
              'category': 'granosYCereales',
            },
          ),
        );
        await _openForm(tester);

        expect(find.text('Arroz'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: una cantidad de cero no guarda nada y muestra un aviso',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          _wrap(productProvider: productProvider, authProvider: authProvider),
        );
        await _openForm(tester);

        await tester.enterText(find.byType(TextField).first, 'Leche');
        await tester.enterText(find.widgetWithText(TextField, 'Ej: 3'), '0');
        await tester.tap(find.text('Guardar'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(productRepo.added, isEmpty);
        expect(
          find.text('La cantidad debe ser mayor a cero'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: un stock mínimo inválido no guarda nada y muestra un '
      'aviso',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          _wrap(productProvider: productProvider, authProvider: authProvider),
        );
        await _openForm(tester);

        await tester.enterText(find.byType(TextField).first, 'Leche');
        // El campo de stock mínimo tiene `digitsOnly` como inputFormatter:
        // escribir "-1" con enterText (que sí respeta los formatters) deja
        // solo "1" en el campo. Para forzar un valor negativo real, se
        // asigna el controller directamente, sin pasar por el formatter.
        final minStockField = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Ej: 2'),
        );
        minStockField.controller!.text = '-1';
        await tester.pump();
        await tester.tap(find.text('Guardar'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(productRepo.added, isEmpty);
        expect(
          find.text('El stock mínimo debe ser un número entero válido'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: sin sesión iniciada, no guarda nada y pide iniciar '
      'sesión',
      (tester) async {
        _useTallViewport(tester);
        authRepo.currentUser = null;
        await tester.pumpWidget(
          _wrap(productProvider: productProvider, authProvider: authProvider),
        );
        await _openForm(tester);

        await tester.enterText(find.byType(TextField).first, 'Leche');
        await tester.tap(find.text('Guardar'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(productRepo.added, isEmpty);
        expect(
          find.text('Debes iniciar sesión para guardar un producto'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: si falla el guardado, se informa el error y el '
      'formulario no se cierra',
      (tester) async {
        _useTallViewport(tester);
        productRepo.addProductError = Exception('sin conexión');
        await tester.pumpWidget(
          _wrap(productProvider: productProvider, authProvider: authProvider),
        );
        await _openForm(tester);

        await tester.enterText(find.byType(TextField).first, 'Leche');
        await tester.tap(find.text('Guardar'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(productRepo.added, isEmpty);
        expect(
          find.text('Error al guardar el producto. Intenta de nuevo.'),
          findsOneWidget,
        );
        expect(find.text('abrir formulario'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: cambiar la unidad y la categoría se refleja en el '
      'producto guardado',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          _wrap(productProvider: productProvider, authProvider: authProvider),
        );
        await _openForm(tester);

        await tester.enterText(find.byType(TextField).first, 'Leche');

        await tester.tap(find.text('unidad'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('L').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Guardar'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(productRepo.added, hasLength(1));
        expect(productRepo.added.first.unit, 'L');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: elegir una fecha de vencimiento y luego quitarla',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          _wrap(productProvider: productProvider, authProvider: authProvider),
        );
        await _openForm(tester);

        expect(find.text('Sin fecha de vencimiento'), findsOneWidget);

        await tester.tap(find.text('Sin fecha de vencimiento'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.text('Sin fecha de vencimiento'), findsNothing);
        expect(find.byIcon(Icons.clear), findsOneWidget);

        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump();

        expect(find.text('Sin fecha de vencimiento'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: elegir una fecha de almacenamiento muestra cuántos días '
      'lleva y permite quitarla',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          _wrap(productProvider: productProvider, authProvider: authProvider),
        );
        await _openForm(tester);

        expect(
          find.text('Seleccionar fecha de entrada al hogar'),
          findsOneWidget,
        );

        await tester.tap(find.text('Seleccionar fecha de entrada al hogar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Guardado el:'), findsOneWidget);
        expect(find.textContaining('días)'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.clear).last);
        await tester.pump();

        expect(
          find.text('Seleccionar fecha de entrada al hogar'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: hideStorageDate oculta la sección de fecha de '
      'almacenamiento',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ProductProvider>.value(
                value: productProvider,
              ),
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ],
            child: MaterialApp(
              home: AddProductScreen(onSave: (_) {}, hideStorageDate: true),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.text('Fecha de almacenamiento (opcional)'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: el registro a granel preselecciona categoría y unidad '
      'típicas',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ProductProvider>.value(
                value: productProvider,
              ),
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ],
            child: MaterialApp(
              home: AddProductScreen(onSave: (_) {}, isBulkEntry: true),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Registro a Granel'), findsOneWidget);
        expect(find.text('kg'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
