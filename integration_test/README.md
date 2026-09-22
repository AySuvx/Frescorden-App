# Pruebas de integración (Use Case → Repository → DataSource → Emulator)

Ejercita las implementaciones reales de `lib/data/` (no los fakes de `test/support/`) contra el Firebase Emulator Suite (Firestore + Auth) — nunca contra el proyecto real.

## Requisitos

- Los mismos que `firestore-tests/` (ver su README): Firebase CLI y JDK 11+.
  ```bash
  export JAVA_HOME="/c/Users/braya/.jdks/corretto-17.0.18"
  export PATH="$JAVA_HOME/bin:$PATH"
  ```
- Un device Flutter con soporte real de plugins Firebase (platform channels nativos) y capaz de correr `integration_test`:
  - `firebase_options.dart` solo tiene configuración para `web` y `android` (Windows desktop no está configurado).
  - **Web (Chrome) NO sirve**: `flutter test integration_test/*.dart -d chrome` falla con "Web devices are not supported for integration tests yet." Se necesita `flutter drive` + chromedriver, no configurado en este proyecto.
  - Camino que sí funciona: **Android** — emulador (AVD `flutter_emulator`, vía `flutter emulators --launch flutter_emulator`) o **celular físico por USB** (con Depuración USB activada y autorizada).
  ```bash
  flutter devices
  ```

## Correr la suite

Desde la raíz del repo, con el device Android conectado (ej. `d7effa11`):

```bash
firebase emulators:exec --only firestore,auth --project demo-frescorden \
  "flutter test integration_test/household_and_product_flow_test.dart -d <device-id> --dart-define=EMULATOR_HOST=<IP-LAN-del-PC>"
```

`--project demo-frescorden` y `support/firebase_emulator_bootstrap.dart` (que inicializa Firebase con un `projectId` "demo-" y credenciales ficticias) garantizan que ninguna llamada pueda alcanzar el backend real.

### `EMULATOR_HOST`: por qué hace falta y cómo obtenerlo

- El plugin de Firestore/Auth remapea automáticamente cualquier host tipo loopback (`localhost`, `127.0.0.1`) a `10.0.2.2` en Android — es la IP con la que un **AVD** (emulador Android) ve al equipo host. Un **celular físico** no tiene esa IP especial, así que con el default el test falla con `firebase_auth/network-request-failed`, incluso usando `adb reverse`.
- Por eso `firebase.json` tiene los emuladores de `firestore`/`auth` escuchando en `"host": "0.0.0.0"` (no solo loopback), y `EMULATOR_HOST` debe ser la IP LAN real del PC (ej. `192.168.1.7`, ver `ipconfig` → adaptador Wi-Fi → "Dirección IPv4"). El celular debe estar en la misma red Wi-Fi que el PC (el cable USB solo sirve para ADB, no para esta conexión).
- Si el device es un **AVD** (no un celular físico), se puede omitir `--dart-define` — el default de `EMULATOR_HOST` ya es `10.0.2.2`.
- Si Windows Firewall bloquea la conexión entrante la primera vez, hay que permitirla (regla de entrada para `java.exe`/el puerto 8080 y 9099) — normalmente Windows pregunta al iniciar el emulador.

## Notas de implementación

- Cada "actor" del escenario (creador del hogar, quien se une, quien no es miembro) inicia sesión como un usuario anónimo nuevo vía `signInAsNewAnonymousUser()` — así `request.auth.uid` es real y distinto por actor, y `firestore.rules` se evalúa de verdad (no se bypassea como en `firestore-tests/`).
- No hay limpieza de datos entre tests (el cliente Firestore no expone un `clearFirestore()` como el SDK de Node de `firestore-tests/`): cada escenario usa un nombre de hogar único (`DateTime.now().microsecondsSinceEpoch`) para no chocar con datos de corridas anteriores.
- Los servicios de dominio (`INotificationService`, `IHouseholdAnalyticsService`) siguen usando los fakes de `test/support/fake_services.dart` — no son parte de la capa de datos que esta suite valida.
- En Android, `google-services.json` dispara un auto-init nativo del Firebase App `"[DEFAULT]"` (con el proyecto real) antes de que corra el test — `initializeFirebaseForEmulatorTests()` captura el `FirebaseException` de código `duplicate-app` y reutiliza esa app, redirigiendo sus SDKs al emulador local. La conexión nunca sale de la red local sin importar qué `projectId` traiga esa app auto-inicializada.
