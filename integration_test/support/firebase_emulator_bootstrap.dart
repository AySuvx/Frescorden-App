// Inicializa Firebase apuntando SIEMPRE al Emulator Suite (Firestore +
// Auth), nunca al proyecto real — mismo principio de aislamiento que
// firestore-tests/ (projectId "demo-"), aplicado aquí del lado Flutter.
//
// Requiere `firebase emulators:exec --only firestore,auth --project
// demo-frescorden "flutter test integration_test/... -d <device-id>
// --dart-define=EMULATOR_HOST=<ip>"` (ver integration_test/README.md).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

const _demoOptions = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:000000000000:web:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-frescorden',
);

Future<void> initializeFirebaseForEmulatorTests() async {
  // En Android, google-services.json dispara un auto-init nativo del app
  // "[DEFAULT]" (con el proyecto real) ANTES de que corra este código —
  // Firebase.initializeApp() de nuevo lanza [core/duplicate-app]. `Firebase
  // .apps` no sirve para detectarlo de antemano: es una caché del lado
  // Dart que todavía no se sincronizó con el auto-init nativo en este
  // punto. Se intenta igual y se ignora ese único código de error — se
  // reutiliza la app existente y solo se redirigen sus SDKs al emulador
  // local: la conexión nunca sale de localhost, sin importar qué
  // projectId traiga.
  try {
    await Firebase.initializeApp(options: _demoOptions);
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
  // El plugin de Firestore/Auth remapea CUALQUIER host tipo loopback
  // ('localhost', '127.0.0.1') a '10.0.2.2' en Android, asumiendo un AVD
  // (donde esa IP especial sí apunta al host) — en un celular físico esa
  // IP no significa nada, ni siquiera reenviando el puerto con
  // `adb reverse`. Se usa la IP LAN real del equipo (no loopback, así que
  // el remapeo no se dispara); el emulador debe escuchar en
  // "0.0.0.0" (ver firebase.json) para aceptar esa conexión entrante.
  // Configurable con `--dart-define=EMULATOR_HOST=<ip>` — cambia con la
  // red Wi-Fi de quien corra la suite. Default: la IP típica de un AVD.
  const emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
}

/// Cierra la sesión activa (si hay una) y crea un usuario anónimo nuevo,
/// con un uid distinto en cada llamada — así cada "actor" del escenario
/// (creador del hogar, quien se une, quien no es miembro) tiene su propio
/// `request.auth.uid` real para que firestore.rules lo evalúe.
Future<String> signInAsNewAnonymousUser() async {
  await FirebaseAuth.instance.signOut();
  final credential = await FirebaseAuth.instance.signInAnonymously();
  return credential.user!.uid;
}
