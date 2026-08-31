// lib/screens/shopping_list_screen.dart
//
// FASE 2 (Fresc-O-rden) — Módulo de Compras Inteligentes:
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
import '../domain/entities/product.dart';
import '../domain/entities/shopping_item.dart';
import '../presentation/providers/product_provider.dart';
import '../presentation/providers/shopping_provider.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShoppingProvider>().loadBasket();
    });
  }

  void _launchURL(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.green,
          ),
          body: _ShoppingWebView(url: url, title: title),
        ),
      ),
    );
  }

  Widget _buildTierSelector(ShoppingProvider shoppingProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: BudgetTier.values.map((tier) {
          final selected = tier == shoppingProvider.selectedTier;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${tier.label} (\$${tier.budgetCap})'),
              selected: selected,
              selectedColor: Colors.green,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => shoppingProvider.selectTier(tier),
            ),
          );
        }).toList(),
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

    return Card(
      color: over ? Colors.red[50] : Colors.green[50],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              over ? Icons.warning_amber : Icons.check_circle,
              color: over ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimado de lo que falta: \$$total COP',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    over
                        ? 'Superas el presupuesto de \$$cap COP por \$${total - cap}'
                        : 'Dentro del presupuesto de \$$cap COP (quedan \$${cap - total})',
                    style: TextStyle(
                      fontSize: 13,
                      color: over ? Colors.red[700] : Colors.green[700],
                    ),
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
      appBar: AppBar(
        title: const Text('Lista de Compras'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          _buildTierSelector(shoppingProvider),
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
          Expanded(
            child: shoppingProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : missing.isEmpty
                    ? const Center(
                        child: Text(
                          '¡Ya tienes todo lo de esta canasta en tu inventario! 🎉',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: missing.length,
                        itemBuilder: (context, index) {
                          final ShoppingItem item = missing[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                '${item.name} — ${item.quantity} ${item.unit}',
                              ),
                              trailing: item.estimatedPrice != null
                                  ? Text('\$${item.estimatedPrice}')
                                  : null,
                            ),
                          );
                        },
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
