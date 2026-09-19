// UID de Firebase Authentication con acceso al panel de administración
// (presentation/screens/admin_dashboard_screen.dart). Se compara contra
// AuthProvider.currentUser?.uid — cualquier otro usuario ve un aviso de
// acceso denegado. También referenciado como valor literal en
// firestore.rules (las reglas no pueden importar Dart), para autorizar
// las consultas agregadas de métricas globales.

const String kAdminUid = 'YMpWzkKQFiMvCqJdYDYX9fZe5Ow2';
