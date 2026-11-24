# Pruebas de carga y estrés de FRESCORDEN

Scripts en Node.js que ejercen el backend de la aplicación con el SDK web oficial de Firebase (13.4.0): mismas reglas de seguridad, misma autenticación y mismos prompts del asistente que la versión 1.19.0.

| Script | Qué mide |
|---|---|
| `accounts.mjs` | Crea y elimina las cuentas de prueba (`--action=create` / `--action=delete`) |
| `firestore-load.mjs` | Latencia y errores de leer el inventario, agregar, editar y resolver productos, y el tiempo que tarda un cambio en llegar al otro integrante del hogar |
| `ai-load.mjs` | Tokens de entrada, salida y razonamiento, latencia y errores de las tres funciones con Gemini (asistente en conversaciones de varios turnos, receta de respaldo y reconocimiento por foto) |

Firebase Storage no se prueba: la aplicación no lo usa (`storage.rules` deniega todo).

## Preparación

1. `npm install`
2. `firebase apps:sdkconfig WEB 1:1512037775:web:2efffdfb9d242fdfebfffa --project frescorden` y guardar el objeto de configuración como `firebase-config.json`.
3. App Check: registrar un token de depuración para la app web en la consola de Firebase (App Check → Apps → Administrar tokens de depuración) y exportarlo como `LT_APPCHECK_DEBUG_TOKEN`.
4. `node accounts.mjs --count=28` (una cuenta por usuario virtual: así cada hogar tiene 2 integrantes)
5. Para el reconocimiento por foto: copiar fotos JPEG de productos en `photos/`.

## Ejecución

```
node firestore-load.mjs --mode=load --vus=28 --duration=120
node firestore-load.mjs --mode=stress --steps=10,25,50,100,200 --stepDuration=60
node ai-load.mjs --fn=chat --n=10 --turns=5
node ai-load.mjs --fn=recipe,vision --n=20
node ai-load.mjs --fn=recipe --n=20 --concurrency=1,5,10,20
```

`--maxRequests` (300 por defecto) limita el total de solicitudes a Gemini en una ejecución. La prueba de estrés de Firestore se detiene cuando la tasa de error supera `--maxErrorRate` (5 %) o el p95 supera `--maxP95` (2000 ms).

Los resultados quedan en `results/` en JSON.

## Limpieza

Las reglas no permiten que un cliente borre hogares, historial ni actividad. `cleanup.mjs` busca todos los hogares con `loadTest: true` y nombre «LOADTEST …», y los borra junto con sus subcolecciones. Usa la API REST de Firestore con la sesión de la Firebase CLI, así que primero hay que correr cualquier comando de `firebase` para renovar el token.

```
firebase projects:list
node cleanup.mjs
node accounts.mjs --action=delete
```

## Validación en el emulador

`LT_EMULATOR=1 firebase emulators:exec --only auth,firestore --project demo-frescorden "cd load-tests && node accounts.mjs --count=4 && node firestore-load.mjs --vus=4 --duration=15"`

El emulador no reproduce el rendimiento ni los límites de producción; solo sirve para comprobar que los scripts funcionan con las reglas.
