// lib/screens/recetas_screen.dart
//
// Módulo de Recetas — conectado a RecipeProvider + ProductProvider.
//
// Coincidencia flexible: ya no se oculta ninguna
// receta por faltarle ingredientes (se eliminó el filtro "solo
// disponibles"). El catálogo completo se muestra ordenado de mayor a
// menor disponibilidad (`sortedByMatch`), con un chip que dice cuántos
// ingredientes tiene el usuario. Cuando la mejor coincidencia del catálogo
// es baja, se ofrece crear una receta colombiana a la medida con IA.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme/app_spacing.dart';
import '../domain/entities/product.dart';
import '../domain/entities/recipe.dart';
import '../routes.dart';
import '../presentation/providers/product_provider.dart';
import '../presentation/providers/recipe_provider.dart';
import '../presentation/widgets/common/custom_card.dart';
import '../presentation/widgets/common/glass_card.dart';
import '../presentation/widgets/common/pressable_scale.dart';
import '../presentation/widgets/common/primary_button.dart';
import '../presentation/widgets/common/skeleton_loader.dart';
import '../presentation/widgets/common/status_badge.dart';
import 'detalle_receta_screen.dart';

/// Umbral de "coincidencia baja": si ni la mejor receta del catálogo llega
/// a la mitad de sus ingredientes, se ofrece el fallback de IA.
const _lowMatchThreshold = 0.5;

class RecetasScreen extends StatefulWidget {
  const RecetasScreen({super.key});

  @override
  State<RecetasScreen> createState() => _RecetasScreenState();
}

class _RecetasScreenState extends State<RecetasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeProvider>().loadRecipes();
    });
  }

  Future<void> _crearRecetaConIa(
    RecipeProvider recipeProvider,
    List<Product> inventory,
  ) async {
    final receta = await recipeProvider.generateAiRecipe(inventory);
    if (receta == null || !mounted) return;
    _abrirDetalle(receta, inventory);
  }

  void _abrirDetalle(Recipe receta, List<Product> inventory) {
    final faltantes = context
        .read<RecipeProvider>()
        .missingIngredientsFor(receta, inventory);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleRecetaScreen(
          receta: receta,
          faltantes: faltantes,
        ),
        settings: const RouteSettings(name: AppRoutes.detalleReceta),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final inventory = context.watch<ProductProvider>().products;
    final recetas = recipeProvider.sortedByMatch(inventory);
    final bestMatch = recipeProvider.bestMatchPercentage(inventory);
    final showAiFallback = bestMatch < _lowMatchThreshold;

    return Scaffold(
      appBar: AppBar(title: const Text('Recetas Sugeridas')),
      body: recipeProvider.isLoading
          ? const SkeletonLoader()
          : recetas.isEmpty
              ? _buildEmptyState(context, recipeProvider, inventory)
              : ListView(
                  // Scroll elástico estilo iOS.
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  children: [
                    if (showAiFallback)
                      _buildAiFallbackCard(context, recipeProvider, inventory),
                    for (final receta in recetas)
                      _buildRecetaCard(context, recipeProvider, receta, inventory),
                  ],
                ),
    );
  }

  Widget _buildRecetaCard(
    BuildContext context,
    RecipeProvider recipeProvider,
    Recipe receta,
    List<Product> inventory,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final faltantes = recipeProvider.missingIngredientsFor(receta, inventory);
    final total = receta.ingredients.length;
    final have = total - faltantes.length;
    final disponible = faltantes.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: PressableScale(
        child: CustomCard(
          onTap: () => _abrirDetalle(receta, inventory),
          child: Row(
            children: [
              Hero(
                tag: 'recipe-image-${receta.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  child: Image.asset(
                    receta.imagePath,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receta.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${receta.prepTimeMinutes} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.people_outline,
                          size: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${receta.servings}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Coincidencia flexible: reusa
                    // StatusBadge con sus tonos verde ("fresh") y ámbar
                    // ("expiringSoon") — no se oculta la receta, solo se
                    // etiqueta qué tan cerca está de poder prepararse.
                    StatusBadge(
                      status: disponible
                          ? ProductFreshness.fresh
                          : ProductFreshness.expiringSoon,
                      label: disponible
                          ? '100% disponible'
                          : 'Tienes $have de $total ingredientes',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiFallbackCard(
    BuildContext context,
    RecipeProvider recipeProvider,
    List<Product> inventory,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(Icons.auto_awesome, size: 32, color: colorScheme.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '¿No encuentras algo que te sirva?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Crea una receta colombiana a tu medida con lo que ya '
              'tienes en el inventario del hogar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
            if (recipeProvider.aiError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                recipeProvider.aiError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Crear Receta Colombiana con IA',
              icon: Icons.auto_awesome,
              isLoading: recipeProvider.isGeneratingAiRecipe,
              onPressed: () => _crearRecetaConIa(recipeProvider, inventory),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    RecipeProvider recipeProvider,
    List<Product> inventory,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant_menu, size: 40, color: colorScheme.primary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No hay recetas disponibles por ahora',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Crear Receta Colombiana con IA',
                icon: Icons.auto_awesome,
                isLoading: recipeProvider.isGeneratingAiRecipe,
                onPressed: () => _crearRecetaConIa(recipeProvider, inventory),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
