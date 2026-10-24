// test/detalle_receta_screen_widget_test.dart
//
// Widget tests de estabilidad visual de DetalleRecetaScreen: metadatos,
// checklist de "Modo Cocina" y el botón de agregar faltantes a la Lista
// de Compras, usando ShoppingProvider real con FakeShoppingRepository.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frescorden/domain/entities/recipe.dart';
import 'package:frescorden/domain/entities/recipe_ingredient.dart';
import 'package:frescorden/presentation/providers/shopping_provider.dart';
import 'package:frescorden/presentation/screens/detalle_receta_screen.dart';
import 'package:frescorden/presentation/widgets/common/primary_button.dart';

import '../../support/fake_repositories.dart';

final _receta = const Recipe(
  id: 'receta-1',
  name: 'Sancocho',
  servings: 4,
  ingredients: [
    RecipeIngredient(name: 'papa', quantity: 2, unit: 'unidad'),
    RecipeIngredient(name: 'yuca', quantity: 1, unit: 'unidad'),
  ],
  imagePath: 'assets/iconos/fresco_receta.png',
  steps: ['Pelar y picar las verduras.', 'Cocinar por 40 minutos.'],
  prepTimeMinutes: 45,
);

Widget _wrap(ShoppingProvider provider, {List<RecipeIngredient> faltantes = const []}) {
  return MaterialApp(
    home: ChangeNotifierProvider<ShoppingProvider>.value(
      value: provider,
      child: DetalleRecetaScreen(receta: _receta, faltantes: faltantes),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Estabilidad visual: DetalleRecetaScreen', () {
    testWidgets(
      'Escenario: sin ingredientes faltantes, la receta renderiza sus '
      'metadatos y pasos sin mostrar el botón de agregar a la lista',
      (tester) async {
        final provider = ShoppingProvider(FakeShoppingRepository({}));
        addTearDown(provider.dispose);

        await tester.pumpWidget(_wrap(provider));
        await tester.pump();

        expect(find.text('Sancocho'), findsOneWidget);
        expect(find.text('45 min'), findsOneWidget);
        expect(find.text('4 personas'), findsOneWidget);
        expect(find.text('Modo Cocina'), findsOneWidget);
        expect(find.byType(PrimaryButton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: tocar un paso lo marca como completado (Modo Cocina)',
      (tester) async {
        final provider = ShoppingProvider(FakeShoppingRepository({}));
        addTearDown(provider.dispose);

        await tester.pumpWidget(_wrap(provider));
        await tester.pump();

        expect(find.text('0/2'), findsOneWidget);

        await tester.tap(find.text('Pelar y picar las verduras.'));
        await tester.pump();

        expect(find.text('1/2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con ingredientes faltantes, tocar el botón los agrega a '
      'la Lista de Compras',
      (tester) async {
        final provider = ShoppingProvider(FakeShoppingRepository({}));
        addTearDown(provider.dispose);
        const faltante = RecipeIngredient(name: 'papa', quantity: 2, unit: 'unidad');

        await tester.pumpWidget(_wrap(provider, faltantes: const [faltante]));
        await tester.pump();

        expect(
          find.text('Agregar faltantes a la Lista de Compras'),
          findsOneWidget,
        );

        await tester.tap(find.byType(PrimaryButton));
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('Agregado a la Lista de Compras'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
