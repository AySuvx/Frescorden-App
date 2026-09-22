// E2E del flujo crítico completo (Sección 12.4 de la Guía): Login → Crear
// producto → Consultar despensa → Consumir producto → Ver actualización —
// manejando los widgets reales de lib/presentation/ (no solo la capa de
// datos, como integration_test/household_and_product_flow_test.dart) contra
// el Firebase Emulator Suite. Ver integration_test/README.md.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frescorden/main.dart';
import 'package:frescorden/presentation/providers/household_provider.dart';

import 'support/firebase_emulator_bootstrap.dart';

/// Reintenta pump() hasta que [finder] encuentre algo — pumpAndSettle() no
/// sirve acá: SplashScreen mantiene un CircularProgressIndicator animando
/// indefinidamente mientras resuelve sesión/onboarding, así que nunca
/// "asienta". El tiempo real de bootstrap/red (emulador por LAN) tampoco es
/// fijo, así que un pump(duration) a ciegas sería frágil.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Tiempo de espera agotado buscando: $finder');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final testEmail = 'e2e.${DateTime.now().microsecondsSinceEpoch}@example.com';
  const testPassword = 'Passw0rd!';
  // Sin dígitos: el campo "Nombre del producto" de AddProductScreen solo
  // permite letras y espacios (FilteringTextInputFormatter), así que un
  // nombre como "Producto E2E" se guardaría silenciosamente como "Producto EE".
  const productName = 'Producto Prueba';

  setUpAll(() async {
    await initializeFirebaseForEmulatorTests();

    // Debe coincidir con SplashScreen._onboardingCompletedKey (privado, no
    // importable) — fuerza el destino Login en vez de Onboarding sin
    // depender de qué haya guardado en el dispositivo (el build de debug
    // comparte applicationId, y por tanto SharedPreferences, con la app real
    // instalada en el celular usado para correr esta suite).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    // El registro real (LoginScreen → "Registrarse") exige clic en un
    // enlace de verificación por correo, no automatizable acá. Se crea el
    // usuario de prueba directo con el SDK y se marca verificado vía el
    // endpoint admin del Auth Emulator (ver markEmailVerified) — el login
    // en sí (paso 1 del escenario) sí se ejercita por UI real más abajo.
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: testEmail, password: testPassword);
    await markEmailVerified(credential.user!.uid);
    await FirebaseAuth.instance.signOut();
  });

  group('Historia E2E: flujo crítico completo', () {
    testWidgets(
      'Escenario: iniciar sesión, agregar un producto, verlo en la despensa, '
      'consumirlo y ver la cantidad actualizada',
      (tester) async {
        await tester.pumpWidget(const FrescordenApp());
        await tester.pump();

        // 1. Login — SplashScreen (onboarding ya completado, sin sesión)
        // navega a LoginScreen; se llena y envía el formulario real.
        await _pumpUntilFound(tester, find.text('Correo Electrónico'));
        await tester.enterText(find.byType(TextField).at(0), testEmail);
        await tester.enterText(find.byType(TextField).at(1), testPassword);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
        await tester.pump();

        // Llega a InicioScreen, pero el FAB no está condicionado a que el
        // hogar personal ya esté bootstrapeado (ver
        // HouseholdProvider._bootstrapIfNeeded) — ese bootstrap corre async
        // contra el emulador y puede no haber terminado todavía. Sin esta
        // espera, "Guardar" falla con "no hay un hogar activo todavía"
        // porque ProductProvider aún no tiene `activeHouseholdId`.
        await _pumpUntilFound(tester, find.byTooltip('Agregar nuevo producto'));
        final householdProvider = Provider.of<HouseholdProvider>(
          tester.element(find.byTooltip('Agregar nuevo producto')),
          listen: false,
        );
        final householdDeadline = DateTime.now().add(const Duration(seconds: 20));
        while (!householdProvider.hasHousehold) {
          if (DateTime.now().isAfter(householdDeadline)) {
            fail('Tiempo de espera agotado esperando el hogar activo.');
          }
          await tester.pump(const Duration(milliseconds: 200));
        }

        // 2. Crear producto — flujo "Registro a Granel" (sin paso de
        // selección de categoría, cantidad 2 para poder consumir 1 después
        // sin que el producto llegue a cero y quede filtrado de la lista).
        await tester.tap(find.byTooltip('Agregar nuevo producto'));
        await tester.pump(const Duration(milliseconds: 350)); // AnimatedSlide/AnimatedOpacity del speed dial
        await tester.tap(find.text('Registro a Granel'));
        await _pumpUntilFound(tester, find.text('Nombre del producto'));

        await tester.enterText(find.byType(TextField).at(0), productName);
        await tester.enterText(find.byType(TextField).at(1), '2');
        // El formulario vive en un SingleChildScrollView más alto que la
        // pantalla — "Guardar" queda fuera del viewport hasta que se
        // scrollea hasta él; sin esto el tap cae fuera del árbol renderizado.
        final guardarButton = find.widgetWithText(ElevatedButton, 'Guardar');
        await tester.ensureVisible(guardarButton);
        await tester.pump();
        await tester.tap(guardarButton);
        await _pumpUntilFound(tester, find.byTooltip('Agregar nuevo producto'));

        // 3. Consultar despensa — abrir el drawer y entrar a "Productos".
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pump(const Duration(milliseconds: 300)); // animación del Drawer
        await tester.tap(
          find.ancestor(
            of: find.byIcon(Icons.shopping_basket),
            matching: find.byType(ListTile),
          ),
        );
        await _pumpUntilFound(tester, find.text(productName));
        expect(find.text('Cantidad: 2 kg'), findsOneWidget);

        // 4. Consumir un producto — botón "Descontar 1" (DecrementProductQuantityUseCase).
        await tester.tap(find.byTooltip('Descontar 1'));

        // 5. Ver actualización — ProductosScreen es reactiva
        // (context.watch<ProductProvider>()): la cantidad baja sola, sin
        // recargar la pantalla ni volver a navegar.
        await _pumpUntilFound(tester, find.text('Cantidad: 1 kg'));
        expect(find.text(productName), findsOneWidget);
      },
    );
  });
}
