// lib/routes.dart
//
// Nombres de ruta (mejora arquitectónica previa al rediseño de interfaz):
// cada Navigator.push de la app pasa uno de estos como RouteSettings.name.
// No es una migración a rutas declarativas (go_router no entra en este
// cambio) — se conserva Navigator.push + MaterialPageRoute tal cual, solo
// se nombra cada una. Dos usos concretos que esto habilita:
//  - FirebaseAnalyticsObserver (ver main.dart) ya reporta qué pantalla se
//    abrió en vez de "desconocida" — antes no había nada que extraer.
//  - Cualquier navegación programática futura (deep links, tests) tiene un
//    identificador estable en vez de comparar por tipo de widget.
class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const inicio = '/inicio';
  static const categoryPicker = '/category-picker';
  static const addProduct = '/add-product';
  static const productos = '/productos';
  static const household = '/household';
  static const assistant = '/assistant';
  static const recetas = '/recetas';
  static const detalleReceta = '/recetas/detalle';
  static const shoppingList = '/shopping-list';
  static const shoppingWebView = '/shopping-list/webview';
  static const analytics = '/analytics';
  static const settings = '/settings';
  static const contact = '/contact';
  static const about = '/about';
  static const adminDashboard = '/admin-dashboard';
}
