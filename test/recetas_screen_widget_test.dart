// test/recetas_screen_widget_test.dart
//
// Widget tests de estabilidad visual (Fase 6, Módulo 3): verifican que
// RecetasScreen renderiza sin excepciones con sus componentes de UI reales
// — PressableScale + StatusBadge en cada tarjeta de receta, GlassCard en el
// fallback de IA cuando la mejor coincidencia es baja — usando
// RecipeProvider/ProductProvider reales con los fakes de
// test/support/fake_repositories.dart en vez de Firestore/Gemini.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/entities/recipe.dart';
import 'package:frescorden/domain/entities/recipe_ingredient.dart';
import 'package:frescorden/presentation/providers/product_provider.dart';
import 'package:frescorden/presentation/providers/recipe_provider.dart';
import 'package:frescorden/presentation/widgets/common/glass_card.dart';
import 'package:frescorden/presentation/widgets/common/pressable_scale.dart';
import 'package:frescorden/screens/recetas_screen.dart';

import 'support/fake_repositories.dart';

Product _product(String name) {
  return Product(
    id: name,
    name: name,
    quantity: 1,
    unit: 'unidad',
    entryDate: DateTime(2026, 1, 1),
  );
}

Recipe _recipe(String id, String name, List<String> ingredientNames) {
  return Recipe(
    id: id,
    name: name,
    servings: 2,
    ingredients: [
      for (final n in ingredientNames)
        RecipeIngredient(name: n, quantity: 1, unit: 'unidad'),
    ],
    imagePath: 'assets/verduras.png',
    steps: const ['Paso único'],
  );
}

Widget _wrap(ProductProvider productProvider, RecipeProvider recipeProvider) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
        ChangeNotifierProvider<RecipeProvider>.value(value: recipeProvider),
      ],
      child: const RecetasScreen(),
    ),
  );
}

void main() {
  group('Estabilidad visual: RecetasScreen', () {
    late FakeProductRepository productRepo;
    late ProductProvider productProvider;

    setUp(() {
      productRepo = FakeProductRepository();
      productProvider = ProductProvider(productRepo);
      productProvider.setActiveHousehold('hogar-1');
      productRepo.emit('hogar-1', []);
    });

    tearDown(() {
      productProvider.dispose();
      productRepo.dispose();
    });

    /// Viewport de tamaño de teléfono real: el default de flutter_test
    /// (800x600 lógicos) es más corto que cualquier teléfono real (ver
    /// mismo ajuste en productos_screen_widget_test.dart).
    void useRealisticPhoneViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets(
      'Escenario: con buena coincidencia, las tarjetas usan PressableScale '
      'y no aparece el fallback de IA',
      (tester) async {
        useRealisticPhoneViewport(tester);

        // Dado un catálogo donde la mejor receta supera el umbral de
        // coincidencia baja (0.5) — Arroz con Pollo con ambos ingredientes
        final recipeRepo = FakeRecipeRepository([
          _recipe('r1', 'Arroz con Pollo', ['Arroz', 'Pollo']),
        ]);
        final recipeProvider = RecipeProvider(recipeRepo);
        addTearDown(recipeProvider.dispose);
        productRepo.emit('hogar-1', [_product('Arroz'), _product('Pollo')]);

        // Cuando se renderiza la pantalla (loadRecipes se dispara solo en
        // initState vía addPostFrameCallback)
        await tester.pumpWidget(_wrap(productProvider, recipeProvider));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // Entonces la tarjeta de la receta usa PressableScale y muestra
        // "100% disponible", y NO aparece la tarjeta de fallback de IA
        // (GlassCard). findsWidgets (no findsOneWidget): PrimaryButton
        // también se apoya en PressableScale internamente, así que puede
        // haber más de una instancia en pantalla — no es el foco de este
        // escenario, solo que la tarjeta de receta use el componente real.
        expect(find.byType(PressableScale), findsWidgets);
        expect(find.text('100% disponible'), findsOneWidget);
        expect(find.byType(GlassCard), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con coincidencia baja, se ofrece el fallback de IA en '
      'un GlassCard',
      (tester) async {
        useRealisticPhoneViewport(tester);

        // Dado un catálogo donde ninguna receta llega al 50% de
        // disponibilidad
        final recipeRepo = FakeRecipeRepository([
          _recipe('r1', 'Sancocho', ['Pollo', 'Papa', 'Yuca', 'Mazorca']),
        ]);
        final recipeProvider = RecipeProvider(recipeRepo);
        addTearDown(recipeProvider.dispose);
        productRepo.emit('hogar-1', [_product('Pollo')]); // 1/4 = 25%

        // Cuando se renderiza la pantalla
        await tester.pumpWidget(_wrap(productProvider, recipeProvider));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // Entonces aparece la tarjeta de fallback de IA (GlassCard),
        // además de la tarjeta normal de la receta (PressableScale; el
        // PrimaryButton del fallback también usa PressableScale
        // internamente, por eso findsWidgets y no findsOneWidget)
        expect(find.byType(GlassCard), findsOneWidget);
        expect(find.byType(PressableScale), findsWidgets);
        expect(find.text('Tienes 1 de 4 ingredientes'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: sin recetas en el catálogo, el estado vacío renderiza '
      'sin excepciones',
      (tester) async {
        useRealisticPhoneViewport(tester);

        // Dado un catálogo vacío
        final recipeRepo = FakeRecipeRepository([]);
        final recipeProvider = RecipeProvider(recipeRepo);
        addTearDown(recipeProvider.dispose);

        // Cuando se renderiza la pantalla
        await tester.pumpWidget(_wrap(productProvider, recipeProvider));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // Entonces no se lanza ninguna excepción
        expect(tester.takeException(), isNull);
      },
    );
  });
}
