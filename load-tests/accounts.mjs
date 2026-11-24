import { writeFileSync, existsSync, readFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { deleteApp } from 'firebase/app';
import { getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword, deleteUser } from 'firebase/auth';
import { initApp, args, ACCOUNTS_FILE } from './lib/firebase.mjs';

const opts = args({ action: 'create', count: 10, domain: 'loadtest.frescorden.test' });
const file = new URL(`./${ACCOUNTS_FILE}`, import.meta.url);

async function create() {
  if (existsSync(file)) throw new Error('accounts.json ya existe: elimínalo o usa --action=delete primero.');
  const accounts = [];
  for (let i = 0; i < opts.count; i++) {
    const app = initApp(`create-${i}`);
    const email = `lt-${Date.now().toString(36)}-${i}@${opts.domain}`;
    const password = randomBytes(18).toString('base64url');
    await createUserWithEmailAndPassword(getAuth(app), email, password);
    accounts.push({ email, password });
    await deleteApp(app);
    console.log(`Creada ${i + 1}/${opts.count}`);
  }
  writeFileSync(file, JSON.stringify(accounts, null, 2));
}

async function remove() {
  const accounts = JSON.parse(readFileSync(file, 'utf8'));
  for (const [i, a] of accounts.entries()) {
    const app = initApp(`delete-${i}`);
    const cred = await signInWithEmailAndPassword(getAuth(app), a.email, a.password);
    await deleteUser(cred.user);
    await deleteApp(app);
    console.log(`Eliminada ${i + 1}/${accounts.length}`);
  }
}

(opts.action === 'delete' ? remove() : create())
  .then(() => process.exit(0))
  .catch((e) => { console.error(e); process.exit(1); });
