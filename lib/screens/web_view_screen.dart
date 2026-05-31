// lib/screens/web_view_screen.dart
//
// BUG #10 CORREGIDO: El WebViewController se creaba dentro del método build(),
//   lo que provoca que se reinicialice (y la página se recargue desde cero) en
//   cada rebuild del widget — por ejemplo, al rotar la pantalla, mostrar el
//   teclado o cuando un widget padre llama a setState.
//   FIX: Se convierte a StatefulWidget y el controller se inicializa una sola
//   vez en initState, idéntico al patrón ya correcto en _ShoppingWebView
//   de shopping_list_screen.dart.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  // BUG #10 FIX: controller inicializado en initState, no en build
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Navegando en ${widget.title}'),
        backgroundColor: Colors.green,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'reload':
                  _controller.reload();
                  break;
                case 'goHome':
                  _controller.loadRequest(
                      Uri.parse('https://www.google.com'));
                  break;
                case 'close':
                  Navigator.pop(context);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'reload',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Recargar'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'goHome',
                child: Row(
                  children: [
                    Icon(Icons.home),
                    SizedBox(width: 8),
                    Text('Ir al inicio'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
