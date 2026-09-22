// firestore-tests/security-rules.test.mjs
//
// Pruebas de seguridad de firestore.rules (Sección 12.7 de la Guía / Cap. 11
// del documento final). Corren contra el Firestore Emulator, nunca contra el
// proyecto real — ver README.md de esta carpeta para el comando de arranque.
//
// Formato BDD (Given/When/Then), matriz de autorización documentada en
// firestore.rules: no autenticado, autenticado dueño/no-dueño, miembro/no
// miembro del hogar, admin/usuario normal.

import { before, after, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  getDocs,
  query,
  collectionGroup,
} from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ADMIN_UID = 'YMpWzkKQFiMvCqJdYDYX9fZe5Ow2';
const OWNER_UID = 'usuario-dueno';
const OTHER_UID = 'usuario-ajeno';
const MEMBER_UID = 'miembro-hogar';
const NON_MEMBER_UID = 'no-miembro-hogar';
const HOUSEHOLD_ID = 'hogar-1';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-frescorden',
    firestore: {
      rules: readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

// El contexto de `withSecurityRulesDisabled` se limpia (cleanup) apenas el
// callback resuelve — no se debe extraer ni reutilizar su Firestore fuera de
// él (lo advierte el propio SDK). Por eso cada siembra de datos ocurre
// DENTRO del callback, en cada llamada.
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// Cachea una instancia de Firestore por UID: crear un contexto nuevo en cada
// test dispara "Firestore has already been started and its settings can no
// longer be changed" al reinicializar la app subyacente para el mismo UID.
const firestoreCache = new Map();
function dbFor(uid) {
  const key = uid ?? '__anon__';
  if (!firestoreCache.has(key)) {
    const ctx = uid ? testEnv.authenticatedContext(uid) : testEnv.unauthenticatedContext();
    firestoreCache.set(key, ctx.firestore());
  }
  return firestoreCache.get(key);
}

// ─── usuarios/{userId} ──────────────────────────────────────────────────

describe('Historia de seguridad: documento de usuario', () => {
  test('Escenario: usuario no autenticado NO puede leer un perfil', async () => {
    const db = dbFor(null);
    await assertFails(getDoc(doc(db, 'usuarios', OWNER_UID)));
  });

  test('Escenario: usuario autenticado SÍ puede leer/escribir su propio perfil', async () => {
    const db = dbFor(OWNER_UID);
    await assertSucceeds(setDoc(doc(db, 'usuarios', OWNER_UID), { email: 'a@a.com' }));
    await assertSucceeds(getDoc(doc(db, 'usuarios', OWNER_UID)));
  });

  test('Escenario: usuario autenticado NO puede leer el perfil de otro', async () => {
    const db = dbFor(OTHER_UID);
    await assertFails(getDoc(doc(db, 'usuarios', OWNER_UID)));
  });

  test('Escenario: el UID admin SÍ puede listar la colección de usuarios', async () => {
    const db = dbFor(ADMIN_UID);
    await assertSucceeds(getDocs(query(collection(db, 'usuarios'))));
  });

  test('Escenario: un usuario normal NO puede listar la colección de usuarios', async () => {
    const db = dbFor(OWNER_UID);
    await assertFails(getDocs(query(collection(db, 'usuarios'))));
  });
});

// ─── households/{householdId} ──────────────────────────────────────────

describe('Historia de seguridad: creación y lectura de hogares', () => {
  test('Escenario: usuario autenticado SÍ puede crear un hogar donde solo él es miembro', async () => {
    const db = dbFor(OWNER_UID);
    await assertSucceeds(
      setDoc(doc(db, 'households', HOUSEHOLD_ID), {
        name: 'Casa',
        createdBy: OWNER_UID,
        members: [OWNER_UID],
      }),
    );
  });

  test('Escenario: NO puede crear un hogar incluyendo a otro miembro desde el inicio', async () => {
    const db = dbFor(OWNER_UID);
    await assertFails(
      setDoc(doc(db, 'households', HOUSEHOLD_ID), {
        name: 'Casa',
        createdBy: OWNER_UID,
        members: [OWNER_UID, OTHER_UID],
      }),
    );
  });

  test('Escenario: usuario no autenticado NO puede crear un hogar', async () => {
    const db = dbFor(null);
    await assertFails(
      setDoc(doc(db, 'households', HOUSEHOLD_ID), {
        name: 'Casa',
        createdBy: OWNER_UID,
        members: [OWNER_UID],
      }),
    );
  });

  test('Escenario: cualquier autenticado (incluso no-miembro) SÍ puede leer un hogar por ID conocido', async () => {
    await seed((db) =>
      setDoc(doc(db, 'households', HOUSEHOLD_ID), {
        name: 'Casa',
        createdBy: OWNER_UID,
        members: [OWNER_UID],
      }),
    );
    const db = dbFor(NON_MEMBER_UID);
    await assertSucceeds(getDoc(doc(db, 'households', HOUSEHOLD_ID)));
  });

  test('Escenario: usuario no autenticado NO puede leer un hogar', async () => {
    await seed((db) =>
      setDoc(doc(db, 'households', HOUSEHOLD_ID), {
        name: 'Casa',
        createdBy: OWNER_UID,
        members: [OWNER_UID],
      }),
    );
    const db = dbFor(null);
    await assertFails(getDoc(doc(db, 'households', HOUSEHOLD_ID)));
  });

  test('Escenario: un usuario normal NO puede listar (query) todos los hogares', async () => {
    const db = dbFor(OWNER_UID);
    await assertFails(getDocs(query(collection(db, 'households'))));
  });

  test('Escenario: el UID admin SÍ puede listar todos los hogares', async () => {
    const db = dbFor(ADMIN_UID);
    await assertSucceeds(getDocs(query(collection(db, 'households'))));
  });
});

describe('Historia de seguridad: actualización de hogares (edición vs. unión)', () => {
  beforeEach(async () => {
    await seed((db) =>
      setDoc(doc(db, 'households', HOUSEHOLD_ID), {
        name: 'Casa',
        createdBy: MEMBER_UID,
        members: [MEMBER_UID],
        memberEmails: {},
      }),
    );
  });

  test('Escenario: un miembro existente SÍ puede editar libremente (p. ej. el nombre)', async () => {
    const db = dbFor(MEMBER_UID);
    await assertSucceeds(updateDoc(doc(db, 'households', HOUSEHOLD_ID), { name: 'Casa Nueva' }));
  });

  test('Escenario: alguien uniéndose SÍ puede agregarse a sí mismo al final de members', async () => {
    const db = dbFor(NON_MEMBER_UID);
    await assertSucceeds(
      updateDoc(doc(db, 'households', HOUSEHOLD_ID), {
        members: [MEMBER_UID, NON_MEMBER_UID],
        memberEmails: { [NON_MEMBER_UID]: 'nuevo@a.com' },
      }),
    );
  });

  test('Escenario: alguien uniéndose NO puede agregar a un tercero en su lugar', async () => {
    const db = dbFor(NON_MEMBER_UID);
    await assertFails(
      updateDoc(doc(db, 'households', HOUSEHOLD_ID), {
        members: [MEMBER_UID, OTHER_UID],
      }),
    );
  });

  test('Escenario: alguien uniéndose NO puede modificar otros campos ajenos a members/memberEmails', async () => {
    const db = dbFor(NON_MEMBER_UID);
    await assertFails(
      updateDoc(doc(db, 'households', HOUSEHOLD_ID), {
        members: [MEMBER_UID, NON_MEMBER_UID],
        name: 'Casa Hackeada',
      }),
    );
  });

  test('Escenario: nadie puede borrar un hogar, ni siquiera un miembro', async () => {
    const db = dbFor(MEMBER_UID);
    await assertFails(deleteDoc(doc(db, 'households', HOUSEHOLD_ID)));
  });

  test('Escenario: nadie puede borrar un hogar, ni siquiera el admin', async () => {
    const db = dbFor(ADMIN_UID);
    await assertFails(deleteDoc(doc(db, 'households', HOUSEHOLD_ID)));
  });
});

// ─── Subcolecciones por-hogar (productos, activity_log, product_history, assistant_usage) ──

describe('Historia de seguridad: inventario compartido del hogar', () => {
  beforeEach(async () => {
    await seed((db) =>
      setDoc(doc(db, 'households', HOUSEHOLD_ID), {
        name: 'Casa',
        createdBy: MEMBER_UID,
        members: [MEMBER_UID],
      }),
    );
  });

  test('Escenario: un miembro del hogar SÍ puede leer y escribir productos', async () => {
    const db = dbFor(MEMBER_UID);
    await assertSucceeds(
      setDoc(doc(db, 'households', HOUSEHOLD_ID, 'productos', 'p1'), { name: 'Arroz' }),
    );
    await assertSucceeds(getDoc(doc(db, 'households', HOUSEHOLD_ID, 'productos', 'p1')));
  });

  test('Escenario: un no-miembro NO puede leer ni escribir productos del hogar', async () => {
    const db = dbFor(NON_MEMBER_UID);
    await assertFails(
      setDoc(doc(db, 'households', HOUSEHOLD_ID, 'productos', 'p1'), { name: 'Arroz' }),
    );
    await assertFails(getDoc(doc(db, 'households', HOUSEHOLD_ID, 'productos', 'p1')));
  });
});

for (const sub of ['activity_log', 'product_history', 'assistant_usage']) {
  describe(`Historia de seguridad: colección append-only ${sub}`, () => {
    beforeEach(async () => {
      await seed(async (db) => {
        await setDoc(doc(db, 'households', HOUSEHOLD_ID), {
          name: 'Casa',
          createdBy: MEMBER_UID,
          members: [MEMBER_UID],
        });
        await setDoc(doc(db, 'households', HOUSEHOLD_ID, sub, 'e1'), {
          creado: true,
        });
      });
    });

    test(`Escenario: un miembro SÍ puede crear y leer entradas de ${sub}`, async () => {
      const db = dbFor(MEMBER_UID);
      await assertSucceeds(setDoc(doc(db, 'households', HOUSEHOLD_ID, sub, 'e2'), { x: 1 }));
      await assertSucceeds(getDoc(doc(db, 'households', HOUSEHOLD_ID, sub, 'e1')));
    });

    test(`Escenario: un no-miembro NO puede crear ni leer entradas de ${sub}`, async () => {
      const db = dbFor(NON_MEMBER_UID);
      await assertFails(setDoc(doc(db, 'households', HOUSEHOLD_ID, sub, 'e2'), { x: 1 }));
      await assertFails(getDoc(doc(db, 'households', HOUSEHOLD_ID, sub, 'e1')));
    });

    test(`Escenario: nadie puede modificar ni borrar una entrada ya escrita de ${sub}`, async () => {
      const db = dbFor(MEMBER_UID);
      await assertFails(updateDoc(doc(db, 'households', HOUSEHOLD_ID, sub, 'e1'), { x: 2 }));
      await assertFails(deleteDoc(doc(db, 'households', HOUSEHOLD_ID, sub, 'e1')));
    });
  });
}

describe('Historia de seguridad: métricas agregadas del Panel Administrativo', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'households', HOUSEHOLD_ID), {
        name: 'Casa',
        createdBy: MEMBER_UID,
        members: [MEMBER_UID],
      });
      await setDoc(doc(db, 'households', HOUSEHOLD_ID, 'product_history', 'e1'), {});
    });
  });

  test('Escenario: el admin SÍ puede hacer collectionGroup query sobre product_history de todos los hogares', async () => {
    const db = dbFor(ADMIN_UID);
    await assertSucceeds(getDocs(query(collectionGroup(db, 'product_history'))));
  });

  test('Escenario: un usuario normal NO puede hacer collectionGroup query sobre product_history', async () => {
    const db = dbFor(MEMBER_UID);
    await assertFails(getDocs(query(collectionGroup(db, 'product_history'))));
  });
});

// ─── inviteCodes/{code} ─────────────────────────────────────────────────

describe('Historia de seguridad: códigos de invitación', () => {
  const CODE = 'ABC123';

  beforeEach(async () => {
    await seed((db) =>
      setDoc(doc(db, 'households', HOUSEHOLD_ID), {
        name: 'Casa',
        createdBy: MEMBER_UID,
        members: [MEMBER_UID],
      }),
    );
  });

  test('Escenario: cualquier autenticado SÍ puede leer un código por su valor exacto', async () => {
    await seed((db) => setDoc(doc(db, 'inviteCodes', CODE), { householdId: HOUSEHOLD_ID }));
    const db = dbFor(NON_MEMBER_UID);
    await assertSucceeds(getDoc(doc(db, 'inviteCodes', CODE)));
  });

  test('Escenario: usuario no autenticado NO puede leer un código de invitación', async () => {
    await seed((db) => setDoc(doc(db, 'inviteCodes', CODE), { householdId: HOUSEHOLD_ID }));
    const db = dbFor(null);
    await assertFails(getDoc(doc(db, 'inviteCodes', CODE)));
  });

  test('Escenario: nadie puede listar (enumerar) todos los códigos de invitación', async () => {
    const db = dbFor(MEMBER_UID);
    await assertFails(getDocs(query(collection(db, 'inviteCodes'))));
  });

  test('Escenario: un miembro del hogar referenciado SÍ puede crear/rotar su código', async () => {
    const db = dbFor(MEMBER_UID);
    await assertSucceeds(
      setDoc(doc(db, 'inviteCodes', CODE), { householdId: HOUSEHOLD_ID }),
    );
  });

  test('Escenario: alguien que NO es miembro del hogar referenciado NO puede crear un código para él', async () => {
    const db = dbFor(NON_MEMBER_UID);
    await assertFails(
      setDoc(doc(db, 'inviteCodes', CODE), { householdId: HOUSEHOLD_ID }),
    );
  });

  test('Escenario: nadie puede borrar un código de invitación', async () => {
    await seed((db) => setDoc(doc(db, 'inviteCodes', CODE), { householdId: HOUSEHOLD_ID }));
    const db = dbFor(MEMBER_UID);
    await assertFails(deleteDoc(doc(db, 'inviteCodes', CODE)));
  });
});
