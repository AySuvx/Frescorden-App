// El WebViewController se inicializa una sola vez en initState, no en
// build(): crearlo en build() lo reinicializaría (recargando la página
// desde cero) en cada rebuild del widget — por ejemplo al rotar la
// pantalla o mostrar el teclado.

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
  late final WebViewController _controller;
  late String _allowedHost;

  @override
  void initState() {
    super.initState();
    _allowedHost = Uri.parse(widget.url).host;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final host = Uri.parse(request.url).host;
            final sameSite = host == _allowedHost ||
                host.endsWith('.$_allowedHost');
            return sameSite
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
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
                  const homeUrl = 'https://www.google.com';
                  _allowedHost = Uri.parse(homeUrl).host;
                  _controller.loadRequest(Uri.parse(homeUrl));
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
