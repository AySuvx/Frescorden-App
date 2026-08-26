// lib/screens/shopping_list_screen.dart
//
// BUG #6 CORREGIDO: Este archivo definía una clase 'WebViewScreen' que
// colisionaba con la clase del mismo nombre en WebViewScreen.dart. Además,
// la clase local era un StatefulWidget que gestionaba correctamente el
// ciclo de vida del WebViewController, mientras la externa era StatelessWidget
// e inicializaba el controller en el método build (anti-pattern).
// FIX: Se renombra la clase local a _ShoppingWebView (privada, scoped a este
// archivo) para eliminar la colisión. La lógica interna no cambia.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  void _launchURL(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.green,
          ),
          // BUG #6 FIX: se usa _ShoppingWebView en lugar de WebViewScreen
          // para evitar colisión de nombres con lib/screens/web_view_screen.dart
          body: _ShoppingWebView(url: url, title: title),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> shoppingSuggestions = [
      {
        'title': 'Lista básica (Presupuesto: \$50,000 COP)',
        'items': [
          'Arroz 5kg',
          'Huevos 30 unidades',
          'Frijoles 1kg',
          'Aceite 1L',
          'Panela 1kg',
          'Sal 500g',
          'Azúcar 1kg',
        ],
        'supermarkets': {
          'Éxito': 'https://www.exito.com/mercado/home',
          'Carulla': 'https://www.carulla.com/',
          'Olímpica': 'https://www.olimpica.com/',
        },
      },
      {
        'title': 'Lista familiar (Presupuesto: \$100,000 COP)',
        'items': [
          'Carne 2kg',
          'Leche 3L',
          'Verduras variadas',
          'Frutas 2kg',
          'Harina 1kg',
          'Pasta 2 paquetes',
          'Café 500g',
        ],
        'supermarkets': {
          'Éxito': 'https://www.exito.com/',
          'Carulla': 'https://www.carulla.com/',
          'Olímpica': 'https://www.olimpica.com/',
        },
      },
      {
        'title': 'Lista saludable (Presupuesto: \$80,000 COP)',
        'items': [
          'Quinua 1kg',
          'Avena 1kg',
          'Frutas 3kg',
          'Verduras 2kg',
          'Aceite de oliva 500ml',
          'Semillas de chía 500g',
          'Frutos secos 500g',
        ],
        'supermarkets': {
          'Éxito': 'https://www.exito.com/',
          'Carulla': 'https://www.carulla.com/',
          'Olímpica': 'https://www.olimpica.com/',
        },
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Compras'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: shoppingSuggestions.length,
          itemBuilder: (context, index) {
            final suggestion = shoppingSuggestions[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion['title'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Productos incluidos:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(suggestion['items'] as List<dynamic>)
                        .map<Widget>((item) {
                      return Text(
                        '- $item',
                        style: const TextStyle(fontSize: 16),
                      );
                    }),
                    const SizedBox(height: 16),
                    const Text(
                      'Selecciona tu supermercado:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      children:
                          (suggestion['supermarkets'] as Map<String, dynamic>)
                              .entries
                              .map<Widget>((entry) {
                        return ElevatedButton(
                          onPressed: () {
                            _launchURL(context, entry.value, entry.key);
                          },
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
            );
          },
        ),
      ),
    );
  }
}

// BUG #6 FIX: renombrada de WebViewScreen → _ShoppingWebView (privada).
// StatefulWidget correcto: el WebViewController se inicializa una sola vez
// en initState, no en cada llamada a build.
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
