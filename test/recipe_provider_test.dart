// test/recipe_provider_test.dart
//
// BDD (Given/When/Then) de RecipeProvider contra su comportamiento real,
// con FakeRecipeRepository (test/support/fake_repositories.dart) en vez del
// catálogo de assets/data/recetas.json.
//
// Nota (Fase 6, Módulo 3): el escenario original pedía que RecipeProvider
// "asigne el StatusBadge (Verde/Ámbar)", pero esa asignación de color vive
// en recetas_screen.dart (`disponible = faltantes.isEmpty` decide el
// status del StatusBadge ahí, no en el provider) — mismo patrón de
// separación Provider/Screen ya resuelto para ProductProvider en este
// módulo. Este archivo cubre lo que el provider sí calcula: el porcentaje
// de coincidencia y el orden resultante, que es exactamente lo que la
// pantalla usa para decidir ese color.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/entities/recipe.dart';
import 'package:frescorden/domain/entities/recipe_ingredient.dart';
import 'package:frescorden/presentation/providers/recipe_provider.dart';

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

void main() {
  group('Historia de Usuario: Como usuario, quiero saber qué tan bien '
      'encaja cada receta con los insumos de mi hogar', () {
    late FakeRecipeRepository repo;
    late RecipeProvider provider;

    setUp(() async {
      repo = FakeRecipeRepository([
        _recipe('r1', 'Arroz con Pollo', ['Arroz', 'Pollo']), // 100% con el inventario de abajo
        _recipe('r2', 'Sancocho', ['Pollo', 'Papa', 'Yuca', 'Mazorca']), // 25%
        _recipe('r3', 'Ensalada', ['Lechuga', 'Tomate']), // 0%
      ]);
      provider = RecipeProvider(repo);
      await provider.loadRecipes();
    });

    test(
      'Escenario: el porcentaje de coincidencia refleja exactamente cuántos '
      'ingredientes ya tiene el usuario',
      () {
        // Dado un listado de insumos del hogar
        final inventory = [_product('Arroz'), _product('Pollo')];

        // Cuando se calcula el match de cada receta
        final arrozConPollo = provider.recipes.firstWhere((r) => r.id == 'r1');
        final sancocho = provider.recipes.firstWhere((r) => r.id == 'r2');
        final ensalada = provider.recipes.firstWhere((r) => r.id == 'r3');

        // Entonces el porcentaje es exacto (2/2, 1/4, 0/2) — esto es lo que
        // recetas_screen.dart usa para decidir el StatusBadge verde/ámbar
        expect(provider.isAvailable(arrozConPollo, inventory), isTrue);
        expect(provider.missingIngredientsFor(sancocho, inventory).length, 3);
        expect(provider.isAvailable(ensalada, inventory), isFalse);
        expect(provider.missingIngredientsFor(ensalada, inventory).length, 2);
      },
    );

    test(
      'Escenario: sortedByMatch ordena el catálogo completo de mayor a '
      'menor disponibilidad, sin ocultar ninguna receta',
      () {
        // Dado un listado de insumos del hogar con coincidencia parcial
        final inventory = [_product('Arroz'), _product('Pollo')];

        // Cuando se calcula el match para ordenar el catálogo
        final ordenado = provider.sortedByMatch(inventory);

        // Entonces las 3 recetas siguen presentes (coincidencia flexible:
        // ya no se oculta ninguna por faltarle ingredientes)...
        expect(ordenado.length, 3);
        // ...ordenadas de mayor a menor disponibilidad
        expect(ordenado.map((r) => r.id), ['r1', 'r2', 'r3']);
      },
    );

    test(
      'Escenario: bestMatchPercentage refleja la mejor receta disponible',
      () {
        // Dado un inventario con un ingrediente que solo aparece en
        // Sancocho (ni en Arroz con Pollo ni en Ensalada, para que ninguna
        // otra receta compita con un porcentaje más alto)
        final soloParaSancocho = [_product('Papa')];

        // Cuando se consulta bestMatchPercentage
        final mejor = provider.bestMatchPercentage(soloParaSancocho);

        // Entonces refleja la receta con mayor porcentaje (Sancocho: 1/4)
        expect(mejor, closeTo(0.25, 0.001));
      },
    );

    test(
      'Escenario: bestMatchPercentage es 1.0 mientras el catálogo no ha '
      'cargado todavía, para no ofrecer el fallback de IA antes de tiempo',
      () async {
        // Dado un RecipeProvider recién creado, ANTES de loadRecipes()
        final repoVacio = FakeRecipeRepository([]);
        final providerSinCargar = RecipeProvider(repoVacio);

        // Cuando se consulta bestMatchPercentage sin inventario alguno
        final resultado = providerSinCargar.bestMatchPercentage([]);

        // Entonces es 1.0 (100%), no 0% — evita ofrecer IA prematuramente
        expect(resultado, 1.0);
      },
    );

    test(
      'Escenario: availableRecipes solo incluye las recetas 100% disponibles',
      () {
        // Dado el mismo inventario de arriba (Arroz con Pollo al 100%,
        // Sancocho al 25%, Ensalada al 0%)
        final inventory = [_product('Arroz'), _product('Pollo')];

        // Cuando se filtran solo las disponibles
        final disponibles = provider.availableRecipes(inventory);

        // Entonces solo queda la que tiene el 100% de sus ingredientes
        expect(disponibles.map((r) => r.id), ['r1']);
      },
    );
  });

  group('Historia de Usuario: Como usuario, quiero que un error al cargar '
      'el catálogo no rompa la pantalla', () {
    test(
      'Escenario: si el repositorio falla, loadRecipes deja el catálogo '
      'vacío y expone el error',
      () async {
        final repo = FakeRecipeRepository([])..getRecipesError = Exception('sin red');
        final provider = RecipeProvider(repo);

        await provider.loadRecipes();

        expect(provider.error, isNotNull);
        expect(provider.recipes, isEmpty);
        expect(provider.isLoading, isFalse);
      },
    );
  });

  group('Historia de Usuario: Como usuario, quiero generar una receta con '
      'IA cuando el catálogo no encaja bien', () {
    test(
      'Escenario: con cuota agotada, no se llama al repositorio y se '
      'informa el motivo',
      () async {
        final repo = FakeRecipeRepository([]);
        final quota = FakeQuotaService()..remaining = 0;
        final provider = RecipeProvider(repo, quota);

        final receta = await provider.generateAiRecipe([]);

        expect(receta, isNull);
        expect(
          provider.aiError,
          'Ya usaste tus consultas de IA de hoy. Vuelve mañana.',
        );
        expect(quota.recordedQueries, 0);
      },
    );

    test(
      'Escenario: con cuota disponible, genera la receta y descuenta una '
      'consulta',
      () async {
        final receta = _recipe('ai-1', 'Sopa Express', ['Papa']);
        final repo = FakeRecipeRepository([])..aiRecipeToReturn = receta;
        final quota = FakeQuotaService();
        final provider = RecipeProvider(repo, quota);

        final resultado = await provider.generateAiRecipe([]);

        expect(resultado, receta);
        expect(provider.aiError, isNull);
        expect(quota.recordedQueries, 1);
        expect(provider.isGeneratingAiRecipe, isFalse);
      },
    );

    test(
      'Escenario: si Gemini falla, se informa el error sin descontar la '
      'cuota',
      () async {
        final repo = FakeRecipeRepository([])..aiRecipeError = Exception('Gemini caído');
        final quota = FakeQuotaService();
        final provider = RecipeProvider(repo, quota);

        final resultado = await provider.generateAiRecipe([]);

        expect(resultado, isNull);
        expect(
          provider.aiError,
          'No se pudo crear la receta. Intenta de nuevo.',
        );
        expect(quota.recordedQueries, 0);
      },
    );

    test(
      'Escenario: una generación ya en curso ignora un segundo llamado '
      'concurrente',
      () async {
        final receta = _recipe('ai-1', 'Sopa Express', ['Papa']);
        final completer = Completer<Recipe>();
        final repo = FakeRecipeRepository([])..aiRecipeFuture = completer.future;
        final quota = FakeQuotaService();
        final provider = RecipeProvider(repo, quota);

        // La primera llamada queda "en curso": ya pasó el await de la
        // cuota (que marca _isGeneratingAiRecipe = true) pero sigue
        // esperando la respuesta del repositorio.
        final primera = provider.generateAiRecipe([]);
        await Future<void>.delayed(Duration.zero);

        final segunda = await provider.generateAiRecipe([]);
        completer.complete(receta);
        final resultado = await primera;

        expect(segunda, isNull, reason: 'la segunda llamada se ignora por estar ya en curso');
        expect(resultado, receta);
        expect(quota.recordedQueries, 1);
      },
    );
  });
}
