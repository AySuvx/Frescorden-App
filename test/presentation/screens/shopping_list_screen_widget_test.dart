// test/shopping_list_screen_widget_test.dart
//
// Widget tests de estabilidad visual de ShoppingListScreen: selector de
// nivel de presupuesto, contador de personas y la lista de "Por comprar"
// cruzada contra el inventario real, usando ShoppingProvider/ProductProvider
// reales con FakeShoppingRepository/FakeProductRepository.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frescorden/domain/entities/budget_tier.dart';
import 'package:frescorden/domain/entities/shopping_item.dart';
import 'package:frescorden/presentation/providers/product_provider.dart';
import 'package:frescorden/presentation/providers/shopping_provider.dart';
import 'package:frescorden/presentation/screens/shopping_list_screen.dart';

import '../../support/fake_repositories.dart';

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(ShoppingProvider shoppingProvider, ProductProvider productProvider) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<ShoppingProvider>.value(value: shoppingProvider),
        ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
      ],
      child: const ShoppingListScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Estabilidad visual: ShoppingListScreen', () {
    testWidgets(
      'Escenario: con una canasta cargada, la lista de "Por comprar" '
      'renderiza sin excepciones',
      (tester) async {
        _useTallViewport(tester);
        final shoppingRepo = FakeShoppingRepository({
          BudgetTier.basica: [
            const ShoppingItem(
              name: 'Arroz',
              quantity: 1,
              unit: 'kg',
              category: 'Granos',
              estimatedPrice: 5000,
            ),
            const ShoppingItem(
              name: 'Leche',
              quantity: 2,
              unit: 'L',
              category: 'Lácteos',
              estimatedPrice: 4000,
            ),
          ],
        });
        final shoppingProvider = ShoppingProvider(shoppingRepo);
        final productProvider = ProductProvider(FakeProductRepository());
        addTearDown(shoppingProvider.dispose);
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(_wrap(shoppingProvider, productProvider));
        // addPostFrameCallback dispara loadBasket() en el primer frame.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Lista de Compras'), findsOneWidget);
        // El nombre va dentro de un solo Text con cantidad y unidad
        // ("Arroz — 1 kg"), no en su propio widget.
        expect(find.textContaining('Arroz'), findsOneWidget);
        expect(find.textContaining('Leche'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: tocar el contador de personas escala la canasta',
      (tester) async {
        _useTallViewport(tester);
        final shoppingRepo = FakeShoppingRepository({
          BudgetTier.basica: [
            const ShoppingItem(
              name: 'Arroz',
              quantity: 1,
              unit: 'kg',
              category: 'Granos',
              estimatedPrice: 5000,
            ),
          ],
        });
        final shoppingProvider = ShoppingProvider(shoppingRepo);
        final productProvider = ProductProvider(FakeProductRepository());
        addTearDown(shoppingProvider.dispose);
        addTearDown(productProvider.dispose);

        await tester.pumpWidget(_wrap(shoppingProvider, productProvider));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // El contador arranca en el valor por defecto de ShoppingProvider
        // (4 personas/comensales), no en 1.
        final personasIniciales = shoppingProvider.personCount;
        expect(find.text('$personasIniciales'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pump(const Duration(milliseconds: 300));

        expect(shoppingProvider.personCount, personasIniciales + 1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
