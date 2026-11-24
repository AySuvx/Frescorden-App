import { readFileSync, existsSync } from 'node:fs';
import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, connectAuthEmulator } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator } from 'firebase/firestore';
import { initializeAppCheck, CustomProvider } from 'firebase/app-check';

const here = new URL('..', import.meta.url);

export function loadJson(name) {
  const url = new URL(name, here);
  if (!existsSync(url)) {
    throw new Error(`Falta ${name} en load-tests/. Ver README.md.`);
  }
  return JSON.parse(readFileSync(url, 'utf8'));
}

export const EMULATOR = process.env.LT_EMULATOR === '1';
export const PREFIX = EMULATOR ? 'emulator-' : '';
export const ACCOUNTS_FILE = `${PREFIX}accounts.json`;

export function firebaseConfig() {
  if (EMULATOR) return { apiKey: 'demo-key', projectId: 'demo-frescorden', appId: 'demo-app', authDomain: 'localhost' };
  return loadJson('firebase-config.json');
}

function appCheckDebugToken() {
  if (process.env.LT_APPCHECK_DEBUG_TOKEN) return process.env.LT_APPCHECK_DEBUG_TOKEN.trim();
  const url = new URL('appcheck-token.txt', here);
  return existsSync(url) ? readFileSync(url, 'utf8').trim() : '';
}

export function initApp(name) {
  const app = initializeApp(firebaseConfig(), name);
  if (EMULATOR) {
    connectAuthEmulator(getAuth(app), 'http://127.0.0.1:9099', { disableWarnings: true });
    connectFirestoreEmulator(getFirestore(app), '127.0.0.1', 8080);
  } else if (appCheckDebugToken()) {
    initializeAppCheck(app, {
      provider: new CustomProvider({ getToken: () => exchangeDebugToken(app.options) }),
      isTokenAutoRefreshEnabled: true,
    });
  }
  return app;
}

export function testAccounts() {
  const accounts = loadJson(ACCOUNTS_FILE);
  if (!Array.isArray(accounts) || accounts.length === 0) {
    throw new Error('accounts.json debe ser una lista de {email, password}.');
  }
  return accounts;
}

async function exchangeDebugToken({ projectId, appId, apiKey }) {
  const url = `https://content-firebaseappcheck.googleapis.com/v1/projects/${projectId}/apps/${appId}:exchangeDebugToken?key=${apiKey}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ debug_token: appCheckDebugToken() }),
  });
  if (!res.ok) throw new Error(`App Check rechazó el token de depuración (${res.status})`);
  const body = await res.json();
  const ttlMs = Number(String(body.ttl ?? '3600s').replace('s', '')) * 1000;
  return { token: body.token, expireTimeMillis: Date.now() + ttlMs };
}

export async function signedInApp(account, index) {
  const app = initApp(`vu-${index}`);
  const auth = getAuth(app);
  const cred = await signInWithEmailAndPassword(auth, account.email, account.password);
  return { app, user: cred.user };
}

export function args(defaults) {
  const out = { ...defaults };
  for (const raw of process.argv.slice(2)) {
    const m = raw.match(/^--([^=]+)(?:=(.*))?$/);
    if (!m) continue;
    const [, key, value] = m;
    const base = defaults[key];
    if (typeof base === 'number') out[key] = Number(value);
    else if (typeof base === 'boolean') out[key] = value === undefined ? true : value === 'true';
    else out[key] = value ?? true;
  }
  return out;
}
