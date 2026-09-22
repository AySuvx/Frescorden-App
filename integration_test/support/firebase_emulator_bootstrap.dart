// Inicializa Firebase apuntando SIEMPRE al Emulator Suite (Firestore +
// Auth), nunca al proyecto real — mismo principio de aislamiento que
// firestore-tests/ (projectId "demo-"), aplicado aquí del lado Flutter.
//
// Requiere `firebase emulators:exec --only firestore,auth --project
// demo-frescorden "flutter test integration_test/... -d <device-id>
// --dart-define=EMULATOR_HOST=<ip>"` (ver integration_test/README.md).

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

const _demoOptions = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:000000000000:web:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-frescorden',
);

/// Host del Emulator Suite — mismo valor que usa
/// [initializeFirebaseForEmulatorTests], expuesto para que otras pruebas
/// (ej. [markEmailVerified]) puedan armar su propia URL sin repetir el
/// `String.fromEnvironment`.
const emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '10.0.2.2',
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

/// Marca `emailVerified: true` para [uid] directo en el Auth Emulator, sin
/// pasar por el correo real — el flujo normal (registro → click en el
/// enlace de verificación) no es viable en un test automatizado. El SDK de
/// Firebase para Dart no expone esta operación (solo el propio usuario
/// puede verificarse a sí mismo); hace falta el endpoint REST de
/// administración de Identity Toolkit que expone el emulador,
/// autenticado con el token fijo "Bearer owner" (mismo que usa
/// `firebase-tools` internamente para export/import de cuentas — nunca
/// funciona contra el backend real, solo el emulador lo acepta).
Future<void> markEmailVerified(String uid) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.http(
        '$emulatorHost:9099',
        '/identitytoolkit.googleapis.com/v1/projects/demo-frescorden/accounts:update',
      ),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode({'localId': uid, 'emailVerified': true})));
    final response = await request.close();
    if (response.statusCode != 200) {
      final body = await response.transform(utf8.decoder).join();
      throw StateError(
        'No se pudo marcar emailVerified en el Auth Emulator '
        '(HTTP ${response.statusCode}): $body',
      );
    }
    await response.drain<void>();
  } finally {
    client.close();
  }
}
