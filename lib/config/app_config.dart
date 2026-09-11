// lib/config/app_config.dart
//
// Panel Administrativo Global (Fase 4.5, Módulo 3):
// UID de Firebase Authentication con acceso al panel de administración
// (lib/screens/admin_dashboard_screen.dart). Se compara contra
// FirebaseAuth.instance.currentUser?.uid — cualquier otro usuario ve un
// aviso de acceso denegado. También referenciado (como valor literal, las
// reglas no pueden importar Dart) en firestore.rules, para autorizar las
// consultas agregadas de métricas globales (total de usuarios, de hogares).

const String kAdminUid = 'YMpWzkKQFiMvCqJdYDYX9fZe5Ow2';
