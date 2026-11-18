// Restringe un WebViewController a navegar solo dentro del mismo sitio
// (mismo host o un subdominio suyo) — usado por WebViewScreen y
// _ShoppingWebView para cerrar la navegación sin restricciones que
// reportaba SonarCloud (dart:S7485).

import 'package:webview_flutter/webview_flutter.dart';

NavigationDelegate sameSiteNavigationDelegate(String Function() allowedHost) {
  return NavigationDelegate(
    onNavigationRequest: (request) {
      final host = Uri.parse(request.url).host;
      final allowed = allowedHost();
      final sameSite = host == allowed || host.endsWith('.$allowed');
      return sameSite
          ? NavigationDecision.navigate
          : NavigationDecision.prevent;
    },
  );
}
