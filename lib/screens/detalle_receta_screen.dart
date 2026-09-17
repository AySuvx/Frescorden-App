// lib/screens/detalle_receta_screen.dart
//
// Módulo de Recetas — recibe la entidad Recipe (y sus RecipeIngredient
// faltantes) en vez de Map<String,dynamic>.
//
//  - Hero compartido con la tarjeta de RecetasScreen (misma imagen
//    "volando" entre pantallas).
//  - GlassCard con los metadatos (⏱️ tiempo, 👥 porciones).
//  - Botón de 1 toque para mandar los ingredientes faltantes directo a la
//    Lista de Compras (ShoppingProvider.addItems).
//  - "Modo Cocina": los pasos de preparación son un checklist interactivo
//    (no texto plano) — cada toque marca el paso y vibra levemente.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme/app_spacing.dart';
import '../domain/entities/recipe.dart';
import '../domain/entities/recipe_ingredient.dart';
import '../domain/entities/shopping_item.dart';
import '../presentation/providers/shopping_provider.dart';
import '../presentation/widgets/common/glass_card.dart';
import '../presentation/widgets/common/primary_button.dart';

class DetalleRecetaScreen extends StatefulWidget {
  final Recipe receta;
  final List<RecipeIngredient> faltantes;

  const DetalleRecetaScreen({
    super.key,
    required this.receta,
    required this.faltantes,
  });

  @override
  State<DetalleRecetaScreen> createState() => _DetalleRecetaScreenState();
}

class _DetalleRecetaScreenState extends State<DetalleRecetaScreen> {
  /// Índices de pasos marcados como completados — "Modo Cocina". Vive solo
  /// en esta pantalla: no se persiste ni se manda a Firestore, es una ayuda
  /// mientras se cocina, no un dato del negocio.
  final Set<int> _pasosCompletados = {};

  bool _yaAgregoFaltantes = false;

  void _toggleStep(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      if (!_pasosCompletados.add(index)) {
        _pasosCompletados.remove(index);
      }
    });
  }

  void _agregarFaltantesALaLista() async {
    if (widget.faltantes.isEmpty) return;
    await context.read<ShoppingProvider>().addItems(
          widget.faltantes.map(
            (f) => ShoppingItem(
              name: f.name,
              quantity: f.quantity,
              unit: f.unit,
              category: 'Receta',
            ),
          ),
        );
    if (!mounted) return;
    setState(() => _yaAgregoFaltantes = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.faltantes.length} ingrediente${widget.faltantes.length == 1 ? '' : 's'} '
          'agregado${widget.faltantes.length == 1 ? '' : 's'} a tu Lista de Compras.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receta = widget.receta;
    final colorScheme = Theme.of(context).colorScheme;
    final completados = _pasosCompletados.length;
    final totalPasos = receta.steps.length;

    return Scaffold(
      appBar: AppBar(title: Text(receta.name)),
      body: ListView(
        // Scroll elástico estilo iOS.
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Center(
            child: Hero(
              tag: 'recipe-image-${receta.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                child: Image.asset(
                  receta.imagePath,
                  width: 180,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Metadatos con acabado de cristal.
          GlassCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMetaItem(
                  context,
                  icon: Icons.timer_outlined,
                  label: '${receta.prepTimeMinutes} min',
                ),
                _buildMetaItem(
                  context,
                  icon: Icons.people_outline,
                  label: '${receta.servings} personas',
                ),
                if (receta.isAiGenerated)
                  _buildMetaItem(
                    context,
                    icon: Icons.auto_awesome,
                    label: 'Creada con IA',
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text('Ingredientes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          ...receta.ingredients.map<Widget>((ingrediente) {
            final tieneIngrediente =
                !widget.faltantes.any((f) => f.name == ingrediente.name);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    tieneIngrediente
                        ? Icons.check_circle
                        : Icons.remove_circle_outline,
                    size: 20,
                    color: tieneIngrediente
                        ? colorScheme.primary
                        : colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${ingrediente.name} — ${ingrediente.quantity} ${ingrediente.unit}',
                    ),
                  ),
                ],
              ),
            );
          }),

          if (widget.faltantes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: _yaAgregoFaltantes
                  ? 'Agregado a la Lista de Compras'
                  : 'Agregar faltantes a la Lista de Compras',
              icon: _yaAgregoFaltantes
                  ? Icons.check
                  : Icons.add_shopping_cart,
              onPressed: _yaAgregoFaltantes ? null : _agregarFaltantesALaLista,
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // "Modo Cocina": pasos interactivos con
          // checkbox y háptico — no una lista de texto pasiva.
          Row(
            children: [
              Icon(Icons.soup_kitchen_outlined, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('Modo Cocina', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (totalPasos > 0)
                Text(
                  '$completados/$totalPasos',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Marca cada paso a medida que lo completas.',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...List.generate(receta.steps.length, (index) {
            final completado = _pasosCompletados.contains(index);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Material(
                color: completado
                    ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  onTap: () => _toggleStep(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: completado,
                          onChanged: (_) => _toggleStep(index),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              receta.steps[index],
                              style: TextStyle(
                                decoration: completado
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: completado
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetaItem(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
        ),
      ],
    );
  }
}
