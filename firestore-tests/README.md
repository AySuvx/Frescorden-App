# Pruebas de seguridad de Firestore Rules

Suite de `@firebase/rules-unit-testing` que valida `firestore.rules` contra el Firestore Emulator — nunca contra el proyecto real.

## Requisitos

- Node.js ≥ 18, Firebase CLI (`firebase --version`).
- **JDK 11+** para el emulador (el JDK 8 del sistema no alcanza). Ejemplo con una instalación existente:
  ```bash
  export JAVA_HOME="/c/Users/braya/.jdks/corretto-17.0.18"
  export PATH="$JAVA_HOME/bin:$PATH"
  ```

## Instalar dependencias (una vez)

```bash
npm --prefix firestore-tests install
```

## Correr la suite

Desde la raíz del repo:

```bash
firebase emulators:exec --only firestore --project demo-frescorden "npm --prefix firestore-tests test"
```

`--project demo-frescorden` usa un projectId "demo-" (no el real `frescorden` de `firebase.json`) — convención de Firebase para garantizar que ninguna llamada pueda alcanzar el backend real por accidente.

## Notas de implementación

- El contexto de `testEnv.withSecurityRulesDisabled(...)` se limpia (`cleanup()`) apenas el callback resuelve — sembrar datos fuera de ese callback (guardando el Firestore en una variable externa) revive el error `Firestore has already been started...`. Por eso todo seeding pasa por el helper `seed()` del test, que ejecuta la escritura DENTRO del callback.
- Las instancias de Firestore por UID autenticado (`dbFor`) sí se cachean y reutilizan entre tests — a diferencia del contexto de bypass, estas no se limpian entre llamadas.
