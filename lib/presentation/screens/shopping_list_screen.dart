// Conectada a ShoppingProvider + ProductProvider:
//  - Permite elegir el nivel de presupuesto (BudgetTier).
//  - Muestra solo lo que el usuario NO tiene ya en su inventario
//    (actualización dinámica real, no una lista estática).
//  - Suma el costo estimado de lo que falta y lo compara contra el techo
//    de presupuesto del nivel elegido.
//
// _ShoppingWebView es privada para no colisionar con WebViewScreen de
// web_view_screen.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../config/theme/app_spacing.dart';
import '../../domain/entities/budget_tier.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/nutrition_group.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/shopping_item.dart';
import '../../routes.dart';
import '../providers/product_provider.dart';
import '../providers/shopping_provider.dart';
import '../utils/currency_format.dart';
import '../utils/food_category_ui.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/common/secondary_button.dart';
import '../widgets/common/skeleton_loader.dart';

/// Enlaces a supermercados colombianos, ofrecidos junto a la lista para que
/// el usuario compare precios. No es contenido de dominio (no afecta la
/// lógica de presupuesto), así que se mantiene como configuración simple de
/// la pantalla.
const Map<String, String> _supermercados = {
  'Éxito': 'https://www.exito.com/',
  'Carulla': 'https://www.carulla.com/',
  'Olímpica': 'https://www.olimpica.com/',
};

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShoppingProvider>().loadBasket();
    });
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  void _launchURL(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: _ShoppingWebView(url: url, title: title),
        ),
        settings: const RouteSettings(name: AppRoutes.shoppingWebView),
      ),
    );
  }

  /// Explica en una línea qué hace este módulo y por qué — antes la
  /// pantalla arrancaba directo en controles (nivel, presupuesto, personas)
  /// sin decir para qué sirven, lo que lo hacía sentir confuso para quien
  /// entraba por primera vez.
  Widget _buildIntroBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/Frescorden-logo/stickers/sticker-fresh.png',
            width: 48,
            height: 48,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solo lo que de verdad te falta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Cruzamos tu inventario real con el presupuesto que elijas, '
                  'para no hacerte comprar de más.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierSelector(ShoppingProvider shoppingProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: BudgetTier.values.map((tier) {
          final selected = tier == shoppingProvider.selectedTier &&
              shoppingProvider.customBudget == null;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${tier.label} (${tier.budgetCap.asCop})'),
              selected: selected,
              selectedColor: colorScheme.primary,
              labelStyle: TextStyle(
                color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                HapticFeedback.lightImpact();
                shoppingProvider.selectTier(tier);
                // Un chip es un preset completo (canasta + techo): si había
                // un presupuesto manual escrito, se limpia para no dejar un
                // techo "fantasma" que no coincide con lo mostrado.
                shoppingProvider.setCustomBudget(null);
                _budgetController.clear();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Campo de texto para un presupuesto personalizado — complementa los
  /// chips fijos de BudgetTier sin reemplazarlos.
  Widget _buildCustomBudgetField(ShoppingProvider shoppingProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _budgetController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Tu Presupuesto (\$)',
          hintText: 'Ej: 75000',
          isDense: true,
          prefixIcon: const Icon(Icons.edit_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (value) {
          // Acepta números escritos con puntos/comas de miles (75.000).
          final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
          shoppingProvider.setCustomBudget(int.tryParse(digitsOnly));
        },
      ),
    );
  }

  /// Contador de personas/comensales: escala cantidades y precios de la
  /// canasta (ver ShoppingProvider._scaled).
  Widget _buildPersonCounter(ShoppingProvider shoppingProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.people_outline,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'N° de personas / comensales',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => shoppingProvider
                .setPersonCount(shoppingProvider.personCount - 1),
          ),
          Text(
            '${shoppingProvider.personCount}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => shoppingProvider
                .setPersonCount(shoppingProvider.personCount + 1),
          ),
        ],
      ),
    );
  }

  /// Chip de un grupo nutricional con 3 estados posibles — el color NO es
  /// la única señal (accesibilidad): la etiqueta siempre nombra el estado.
  ///   - Cubierto (verde): ya hay un producto de ese grupo en la despensa.
  ///   - En tu lista (ámbar): no está en la despensa, pero ya se agregó a
  ///     "Por comprar" — falta comprarlo, no falta decidirlo.
  ///   - Falta (rojo): ni en la despensa ni en la lista todavía.
  Widget _buildNutritionChip(
    NutritionGroup group, {
    required bool covered,
    required bool alreadyInList,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, stateLabel, background, onColor) = switch (true) {
      _ when covered => (
        Icons.check_circle,
        'Cubierto',
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      _ when alreadyInList => (
        Icons.shopping_cart_outlined,
        'En tu lista',
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
      _ => (
        Icons.remove_circle_outline,
        'Falta',
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
    };

    return Chip(
      avatar: Icon(icon, size: 18, color: onColor),
      label: Text('${group.label} — $stateLabel', style: TextStyle(color: onColor)),
      backgroundColor: background,
    );
  }

  /// Un ítem de [group.suggestedItems] ya está en la canasta o en los
  /// agregados manuales — es decir, el usuario YA lo puso en su lista de
  /// compras, aunque todavía no lo tenga en la despensa. Es el estado
  /// intermedio entre "Falta" y "Cubierto" (ver `_buildBalancedPlateSection`
  /// y `_groupState`).
  bool _groupAlreadyInList(
    ShoppingProvider shoppingProvider,
    NutritionGroup group,
  ) {
    final listNames = {
      for (final item in [
        ...shoppingProvider.basket,
        ...shoppingProvider.extraItems,
      ])
        item.name.toLowerCase(),
    };
    return group.suggestedItems.any(
      (item) => listNames.contains(item.name.toLowerCase()),
    );
  }

  /// 'Plato Equilibrado': un plato balanceado combina proteína,
  /// carbohidrato, fruta/verdura y lácteo/grasa en cada comida — estos
  /// chips muestran, grupo por grupo, si ya lo tienes en casa (verde), ya
  /// lo agregaste a la lista pero falta comprarlo (ámbar), o todavía no
  /// está en ningún lado (rojo). El botón agrega de un toque los insumos
  /// sugeridos de los grupos que siguen en rojo.
  Widget _buildBalancedPlateSection(
    ShoppingProvider shoppingProvider,
    List<Product> inventory,
  ) {
    final missingGroups = shoppingProvider.missingNutritionGroups(inventory);
    final pendingGroups = missingGroups
        .where((g) => !_groupAlreadyInList(shoppingProvider, g))
        .toSet();
    final colorScheme = Theme.of(context).colorScheme;

    return CustomCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.balance, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Plato Equilibrado',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Un plato balanceado combina estos 4 grupos en cada comida — '
            'te mostramos cuáles ya tienes, cuáles ya agregaste a tu lista '
            'y cuáles todavía faltan.',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final group in NutritionGroup.values)
                _buildNutritionChip(
                  group,
                  covered: !missingGroups.contains(group),
                  alreadyInList:
                      missingGroups.contains(group) &&
                      !pendingGroups.contains(group),
                ),
            ],
          ),
          if (pendingGroups.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'Agregar insumos faltantes (${pendingGroups.length})',
              icon: const Icon(Icons.add_shopping_cart),
              onPressed: () {
                shoppingProvider.addBalancedPlateItems(inventory);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Insumos agregados a tu lista de compras'),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Fondo revelado al deslizar un ítem de "Por comprar" hacia la
  /// izquierda — comunica visualmente la acción ("Ya lo tengo") antes de
  /// que el usuario suelte el dedo.
  Widget _buildDismissBackground(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ya lo tengo',
            style: TextStyle(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.check_circle, color: colorScheme.onSecondaryContainer),
        ],
      ),
    );
  }

  /// Agrupa "Por comprar" por categoría (ícono de marca + nombre), en vez
  /// de una lista plana — más fácil de escanear y más parecido a cómo se
  /// organiza un súper real (lácteos, carnes, aseo...). El orden sigue
  /// `FoodCategory.values`, así que es estable entre recargas.
  Map<FoodCategory, List<ShoppingItem>> _groupByCategory(
    List<ShoppingItem> items,
  ) {
    final grouped = <FoodCategory, List<ShoppingItem>>{};
    for (final category in FoodCategory.values) {
      final itemsInCategory = items
          .where((i) => FoodCategory.fromName(i.category) == category)
          .toList();
      if (itemsInCategory.isNotEmpty) grouped[category] = itemsInCategory;
    }
    return grouped;
  }

  Widget _buildCategoryHeader(FoodCategory category, int count) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Image.asset(category.iconAsset, width: 22, height: 22),
          const SizedBox(width: AppSpacing.sm),
          Text(
            category.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingItemTile(
    ShoppingProvider shoppingProvider,
    ShoppingItem item,
  ) {
    return Dismissible(
      key: ValueKey(item.name),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(context),
      onDismissed: (_) {
        shoppingProvider.removeFromMissing(item);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${item.name}" quitado de la lista'),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: shoppingProvider.undoLastRemoval,
            ),
          ),
        );
      },
      child: CustomCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: EdgeInsets.zero,
        child: ListTile(
          title: Text(
            '${item.name} — ${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} ${item.unit}',
          ),
          trailing: item.estimatedPrice != null
              ? Text(item.estimatedPrice!.asCop)
              : null,
        ),
      ),
    );
  }

  Widget _buildEmptyMissingState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          Image.asset(
            'assets/Frescorden-logo/stickers/sticker-joy.png',
            width: 96,
            height: 96,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '¡Ya tienes todo de esta canasta!',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No necesitas comprar nada más por ahora.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSummary(
    ShoppingProvider shoppingProvider,
    List<Product> inventory,
  ) {
    final total = shoppingProvider.estimatedTotal(inventory);
    final cap = shoppingProvider.budgetCap;
    final over = total > cap;
    final colorScheme = Theme.of(context).colorScheme;
    final onColor =
        over ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer;

    return CustomCard(
      color: over ? colorScheme.errorContainer : colorScheme.primaryContainer,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            over ? Icons.warning_amber : Icons.check_circle,
            color: onColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimado de lo que falta: ${total.asCop}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: onColor,
                  ),
                ),
                Text(
                  over
                      ? 'Superas el presupuesto de ${cap.asCop} por ${(total - cap).asCop}'
                      : 'Dentro del presupuesto de ${cap.asCop} (quedan ${(cap - total).asCop})',
                  style: TextStyle(fontSize: 13, color: onColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shoppingProvider = context.watch<ShoppingProvider>();
    final inventory = context.watch<ProductProvider>().products;
    final missing = shoppingProvider.missingItems(inventory);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Compras')),
      // Lista única desplazable en vez de Column fija + Expanded: con la
      // tarjeta "Plato Equilibrado" el encabezado ya no
      // entra siempre en una pantalla de celular — un Expanded fijo para
      // "Por comprar" quedaba aplastado a una franja mínima. Con todo en un
      // solo ListView, cada sección ocupa el alto que necesita y el usuario
      // simplemente se desplaza; nada compite por espacio fijo.
      body: ListView(
        // Scroll elástico estilo iOS.
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _buildIntroBanner(),
          _buildTierSelector(shoppingProvider),
          _buildCustomBudgetField(shoppingProvider),
          _buildPersonCounter(shoppingProvider),
          _buildBalancedPlateSection(shoppingProvider, inventory),
          _buildBudgetSummary(shoppingProvider, inventory),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Por comprar:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (missing.isNotEmpty)
                    Text(
                      'Deslízalo hacia la izquierda si ya lo tienes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (shoppingProvider.isLoading)
            // Skeleton en vez de spinner: sin imagen
            // por ítem — la lista real tampoco la tiene — y sin padding
            // propio, porque ya vive dentro del ListView general de la
            // pantalla (ver nota en SkeletonLoader sobre anidar scrolls).
            const SkeletonLoader(
              itemCount: 3,
              showLeading: false,
              padding: EdgeInsets.symmetric(horizontal: 16),
            )
          else if (missing.isEmpty)
            _buildEmptyMissingState()
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in _groupByCategory(missing).entries) ...[
                    _buildCategoryHeader(entry.key, entry.value.length),
                    for (final item in entry.value)
                      _buildMissingItemTile(shoppingProvider, item),
                  ],
                ],
              ),
            ),
          CustomCard(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storefront, color: colorScheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Compara precios antes de comprar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Estos enlaces abren el catálogo online de cada súper, '
                  'para que revises precios antes de salir de casa.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _supermercados.entries.map<Widget>((entry) {
                    return SecondaryButton(
                      label: entry.key,
                      expand: false,
                      onPressed: () =>
                          _launchURL(context, entry.value, entry.key),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// WebViewController se inicializa una sola vez en initState, no en cada
// llamada a build.
class _ShoppingWebView extends StatefulWidget {
  final String url;
  final String title;

  const _ShoppingWebView({required this.url, required this.title});

  @override
  State<_ShoppingWebView> createState() => _ShoppingWebViewState();
}

class _ShoppingWebViewState extends State<_ShoppingWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
