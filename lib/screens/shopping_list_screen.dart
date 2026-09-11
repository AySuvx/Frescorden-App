// lib/screens/shopping_list_screen.dart
//
// Módulo de Compras Inteligentes:
// Se elimina el mock (3 canastas fijas con ítems hardcodeados) y se
// conecta a ShoppingProvider + ProductProvider. La lista ahora:
//  - Permite elegir el nivel de presupuesto (BudgetTier).
//  - Muestra solo lo que el usuario NO tiene ya en su inventario
//    (actualización dinámica real, no una lista estática).
//  - Suma el costo estimado de lo que falta y lo compara contra el techo
//    de presupuesto del nivel elegido.
//
// BUG #6 (se conserva): _ShoppingWebView es privada para no colisionar con
// WebViewScreen de web_view_screen.dart.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../domain/entities/budget_tier.dart';
import '../domain/entities/nutrition_group.dart';
import '../domain/entities/product.dart';
import '../domain/entities/shopping_item.dart';
import '../routes.dart';
import '../presentation/providers/product_provider.dart';
import '../presentation/providers/shopping_provider.dart';
import '../presentation/utils/currency_format.dart';

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
              // Antes: Colors.black87 fijo para "no seleccionado" —
              // invisible sobre el fondo oscuro del chip en modo oscuro.
              labelStyle: TextStyle(
                color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.people_outline, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 8),
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

  /// 'Plato Equilibrado' (Fase 4.5, Módulo 4): muestra qué grupos
  /// nutricionales cubre hoy el inventario real del hogar (chips verdes) y
  /// cuáles faltan (chips rojos), con un botón para agregar a la lista de
  /// compras los insumos sugeridos de los grupos faltantes en un solo toque.
  Widget _buildBalancedPlateSection(
    ShoppingProvider shoppingProvider,
    List<Product> inventory,
  ) {
    final missingGroups = shoppingProvider.missingNutritionGroups(inventory);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.balance, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Plato Equilibrado',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Grupos nutricionales que cubre tu despensa hoy',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final group in NutritionGroup.values)
                  // colorScheme.error/primaryContainer + su on*Container
                  // correspondiente ya vienen balanceados para buen
                  // contraste en claro Y oscuro (antes: Colors.red[50] /
                  // green[50] fijos, con texto que en modo oscuro se
                  // pintaba claro sobre un fondo también claro).
                  Chip(
                    avatar: Icon(
                      missingGroups.contains(group)
                          ? Icons.remove_circle_outline
                          : Icons.check_circle,
                      size: 18,
                      color: missingGroups.contains(group)
                          ? colorScheme.onErrorContainer
                          : colorScheme.onPrimaryContainer,
                    ),
                    label: Text(
                      group.label,
                      style: TextStyle(
                        color: missingGroups.contains(group)
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                    backgroundColor: missingGroups.contains(group)
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,
                  ),
              ],
            ),
            if (missingGroups.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    shoppingProvider.addBalancedPlateItems(inventory);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Insumos agregados a tu lista de compras',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(
                    'Agregar insumos faltantes (${missingGroups.length})',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
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
    // Antes: Colors.red[50]/green[50] fijos, con el primer renglón sin
    // color explícito (heredaba el texto claro del tema oscuro sobre un
    // fondo también claro — casi ilegible). *Container/on*Container se
    // adaptan solos a ambos modos.
    final onColor =
        over ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer;

    return Card(
      color: over ? colorScheme.errorContainer : colorScheme.primaryContainer,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              over ? Icons.warning_amber : Icons.check_circle,
              color: onColor,
            ),
            const SizedBox(width: 12),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shoppingProvider = context.watch<ShoppingProvider>();
    final inventory = context.watch<ProductProvider>().products;
    final missing = shoppingProvider.missingItems(inventory);

    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Compras')),
      // Lista única desplazable en vez de Column fija + Expanded: con la
      // tarjeta "Plato Equilibrado" (Fase 4.5, Módulo 4) el encabezado ya no
      // entra siempre en una pantalla de celular — un Expanded fijo para
      // "Por comprar" quedaba aplastado a una franja mínima. Con todo en un
      // solo ListView, cada sección ocupa el alto que necesita y el usuario
      // simplemente se desplaza; nada compite por espacio fijo.
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _buildTierSelector(shoppingProvider),
          _buildCustomBudgetField(shoppingProvider),
          _buildPersonCounter(shoppingProvider),
          _buildBalancedPlateSection(shoppingProvider, inventory),
          _buildBudgetSummary(shoppingProvider, inventory),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Por comprar:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (shoppingProvider.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (missing.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: Text(
                  '¡Ya tienes todo lo de esta canasta en tu inventario! 🎉',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final ShoppingItem item in missing)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '${item.name} — ${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} ${item.unit}',
                        ),
                        trailing: item.estimatedPrice != null
                            ? Text(item.estimatedPrice!.asCop)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona tu supermercado:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: _supermercados.entries.map<Widget>((entry) {
                    return ElevatedButton(
                      onPressed: () =>
                          _launchURL(context, entry.value, entry.key),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: Text(entry.key),
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

// BUG #6 FIX (se conserva): renombrada de WebViewScreen → _ShoppingWebView
// (privada). StatefulWidget correcto: el WebViewController se inicializa
// una sola vez en initState, no en cada llamada a build.
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
