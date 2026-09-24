// firestore-tests/storage-rules.test.mjs
//
// Pruebas de seguridad de storage.rules (Sección 12.7 de la Guía / Cap. 11
// del documento final). Corren contra el Storage Emulator, nunca contra el
// proyecto real — ver README.md de esta carpeta para el comando de arranque.
//
// Ningún módulo de la app usa Storage, así que la regla es denegar todo: la
// matriz verifica que ni un usuario autenticado, ni el dueño de una ruta con
// su propio uid, ni el administrador puedan leer o escribir.

import { before, after, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  initializeTestEnvironment,
  assertFails,
} from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getBytes, deleteObject } from 'firebase/storage';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ADMIN_UID = 'YMpWzkKQFiMvCqJdYDYX9fZe5Ow2';
const USER_UID = 'usuario-normal';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-frescorden',
    storage: {
      rules: readFileSync(join(__dirname, '..', 'storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

const bytes = new Uint8Array([1, 2, 3]);

describe('Historia: Storage no debe exponer datos a nadie', () => {
  test('Given un usuario no autenticado, When sube un archivo, Then se rechaza', async () => {
    const storage = testEnv.unauthenticatedContext().storage();
    await assertFails(uploadBytes(ref(storage, 'productos/foto.jpg'), bytes));
  });

  test('Given un usuario no autenticado, When lee un archivo, Then se rechaza', async () => {
    const storage = testEnv.unauthenticatedContext().storage();
    await assertFails(getBytes(ref(storage, 'productos/foto.jpg')));
  });

  test('Given un usuario autenticado, When sube a su propia ruta, Then se rechaza', async () => {
    const storage = testEnv.authenticatedContext(USER_UID).storage();
    await assertFails(uploadBytes(ref(storage, `usuarios/${USER_UID}/perfil.jpg`), bytes));
  });

  test('Given un usuario autenticado, When lee una ruta ajena, Then se rechaza', async () => {
    const storage = testEnv.authenticatedContext(USER_UID).storage();
    await assertFails(getBytes(ref(storage, 'usuarios/otro-usuario/perfil.jpg')));
  });

  test('Given un usuario autenticado, When elimina un archivo, Then se rechaza', async () => {
    const storage = testEnv.authenticatedContext(USER_UID).storage();
    await assertFails(deleteObject(ref(storage, 'productos/foto.jpg')));
  });

  test('Given el administrador, When sube un archivo, Then se rechaza (no hay excepciones)', async () => {
    const storage = testEnv.authenticatedContext(ADMIN_UID).storage();
    await assertFails(uploadBytes(ref(storage, 'productos/foto.jpg'), bytes));
  });
});
