// Nombres de ruta: cada Navigator.push de la app pasa uno de estos como
// RouteSettings.name (no es una migración a rutas declarativas — se usa
// Navigator.push + MaterialPageRoute normal, solo nombrado). Dos usos:
//  - FirebaseAnalyticsObserver (ver main.dart) reporta qué pantalla se abrió.
//  - Navegación programática (deep links, tests) tiene un identificador
//    estable en vez de comparar por tipo de widget.
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
