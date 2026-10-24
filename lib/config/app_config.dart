// UID de Firebase Authentication con acceso al panel de administración
// (presentation/screens/admin_dashboard_screen.dart). Se compara contra
// AuthProvider.currentUser?.uid — cualquier otro usuario ve un aviso de
// acceso denegado. También referenciado como valor literal en
// firestore.rules (las reglas no pueden importar Dart), para autorizar
// las consultas agregadas de métricas globales.

const String kAdminUid = 'YMpWzkKQFiMvCqJdYDYX9fZe5Ow2';

/// Correos adicionales con el mismo acceso de administrador que kAdminUid.
/// Se identifican por correo (no por UID) porque no se conoce de antemano
/// el UID de esas cuentas — deben iniciar sesión con este correo exacto.
/// También repetido como literal en firestore.rules (mismo motivo que
/// kAdminUid: las reglas no pueden importar Dart).
const Set<String> kAdminEmails = {'familiaotalora98@gmail.com'};

const bool kAiPilotModeEnabled = true;
