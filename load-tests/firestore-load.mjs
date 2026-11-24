import { mkdirSync, writeFileSync, existsSync, readFileSync } from 'node:fs';
import { monitorEventLoopDelay } from 'node:perf_hooks';
import {
  getFirestore, collection, doc, setDoc, updateDoc, addDoc, deleteDoc, getDocs,
  onSnapshot, arrayUnion, Timestamp, serverTimestamp,
} from 'firebase/firestore';
import { signedInApp, testAccounts, args, PREFIX } from './lib/firebase.mjs';
import { Recorder, sleep } from './lib/stats.mjs';

const opts = args({
  mode: 'load',
  vus: 10,
  duration: 120,
  steps: '5,10,20,40',
  stepDuration: 60,
  think: 1000,
  maxErrorRate: 5,
  maxP95: 2000,
  raw: false,
  tag: '',
});

const FOODS = [
  ['Leche entera', 'lacteos', 'L'], ['Arroz', 'granosYCereales', 'kg'], ['Huevos', 'otros', 'unidad'],
  ['Tomate', 'verdurasYHortalizas', 'kg'], ['Banano', 'frutas', 'unidad'], ['Pan tajado', 'panaderia', 'unidad'],
  ['Queso campesino', 'lacteos', 'g'], ['Pechuga de pollo', 'carnesYEmbutidos', 'kg'], ['Lentejas', 'granosYCereales', 'g'],
  ['Zanahoria', 'verdurasYHortalizas', 'kg'],
];

const runId = new Date().toISOString().replace(/[:.]/g, '-');
const resultsDir = new URL('./results/', import.meta.url);
mkdirSync(resultsDir, { recursive: true });
const createdFile = new URL(`./results/${PREFIX}created-households.json`, import.meta.url);
const created = existsSync(createdFile) ? JSON.parse(readFileSync(createdFile, 'utf8')) : [];

const accounts = testAccounts();
const households = new Map();

async function ensureHousehold(account, accountIndex, session) {
  const pair = Math.floor(accountIndex / 2);
  if (households.has(pair)) return households.get(pair);
  const db = getFirestore(session.app);
  const ref = doc(collection(db, 'households'));
  const now = new Date();
  await setDoc(ref, {
    name: `LOADTEST ${runId} #${pair}`,
    createdBy: session.user.uid,
    members: [session.user.uid],
    memberEmails: [account.email],
    inviteCode: `LT${Math.random().toString(36).slice(2, 8).toUpperCase()}`,
    codeExpiresAt: Timestamp.fromDate(new Date(now.getTime() + 24 * 3600 * 1000)),
    createdAt: Timestamp.fromDate(now),
    loadTest: true,
  });
  const entry = { id: ref.id, members: new Set([session.user.uid]) };
  households.set(pair, entry);
  created.push(ref.id);
  writeFileSync(createdFile, JSON.stringify([...new Set(created)], null, 2));
  return entry;
}

async function joinHousehold(entry, account, session) {
  if (entry.members.has(session.user.uid)) return;
  const db = getFirestore(session.app);
  await updateDoc(doc(db, 'households', entry.id), {
    members: arrayUnion(session.user.uid),
    memberEmails: arrayUnion(account.email),
  });
  entry.members.add(session.user.uid);
}

async function setupVus(count, rec) {
  const vus = [];
  for (let i = 0; i < count; i++) {
    const accountIndex = i % accounts.length;
    const account = accounts[accountIndex];
    const session = await rec.time('setup.signIn', () => signedInApp(account, `${runId}-${i}`));
    if (!session) continue;
    const entry = households.get(Math.floor(accountIndex / 2)) ?? await ensureHousehold(account, accountIndex, session);
    await joinHousehold(entry, account, session);
    vus.push({ index: i, account, session, householdId: entry.id, db: getFirestore(session.app) });
  }
  return vus;
}

function listenForSync(vu, rec) {
  const ref = collection(vu.db, 'households', vu.householdId, 'productos');
  let first = true;
  return onSnapshot(ref, (snap) => {
    if (first) { first = false; return; }
    for (const change of snap.docChanges()) {
      if (change.type !== 'added' || change.doc.metadata.hasPendingWrites) continue;
      const data = change.doc.data();
      if (data.ltSentBy && data.ltSentBy !== vu.session.user.uid && data.ltSentAt) {
        rec.record('sync.otherMember', Date.now() - data.ltSentAt);
      }
    }
  }, () => {});
}

async function iteration(vu, rec) {
  const products = collection(vu.db, 'households', vu.householdId, 'productos');
  await rec.time('inventory.read', () => getDocs(products));

  const [name, category, unit] = FOODS[Math.floor(Math.random() * FOODS.length)];
  const now = new Date();
  const expiration = new Date(now.getTime() + (1 + Math.floor(Math.random() * 10)) * 86400000);
  const ref = await rec.time('product.add', () => addDoc(products, {
    name, quantity: '1', unit, category, isBulk: false,
    entryDate: now.toISOString(), expirationDate: expiration.toISOString(),
    loadTest: true, ltSentAt: Date.now(), ltSentBy: vu.session.user.uid,
  }));
  if (!ref) return;
  await sleep(opts.think);

  await rec.time('product.update', () => updateDoc(ref, { quantity: '2' }));
  await sleep(opts.think);

  const outcome = Math.random() < 0.8 ? 'consumedOnTime' : 'expired';
  await rec.time('product.resolve', async () => {
    await deleteDoc(ref);
    await Promise.all([
      addDoc(collection(vu.db, 'households', vu.householdId, 'product_history'), {
        productId: ref.id, name, category,
        entryDate: now.toISOString(), expirationDate: expiration.toISOString(),
        resolvedAt: new Date().toISOString(), outcome, loadTest: true,
      }),
      addDoc(collection(vu.db, 'households', vu.householdId, 'activity_log'), {
        productName: name, action: outcome === 'expired' ? 'desperdiciado' : 'consumido',
        userEmail: vu.account.email, userId: vu.session.user.uid,
        timestamp: serverTimestamp(), loadTest: true,
      }),
    ]);
  });
  await sleep(opts.think);
}

async function runPhase(vus, seconds, rec) {
  const until = Date.now() + seconds * 1000;
  let iterations = 0;
  const unsubs = vus.map((vu) => listenForSync(vu, rec));
  const lag = monitorEventLoopDelay({ resolution: 10 });
  lag.enable();
  const cpuStart = process.cpuUsage();
  const wallStart = performance.now();
  await Promise.all(vus.map(async (vu) => {
    while (Date.now() < until) {
      await iteration(vu, rec);
      iterations++;
    }
  }));
  lag.disable();
  const cpu = process.cpuUsage(cpuStart);
  const wallMs = performance.now() - wallStart;
  unsubs.forEach((u) => u());
  const generator = {
    eventLoopLagMs: {
      mean: Math.round(lag.mean / 1e5) / 10,
      p95: Math.round(lag.percentile(95) / 1e5) / 10,
      p99: Math.round(lag.percentile(99) / 1e5) / 10,
      max: Math.round(lag.max / 1e5) / 10,
    },
    cpuCoreUsagePct: Math.round(((cpu.user + cpu.system) / 1000 / wallMs) * 1000) / 10,
  };
  return { iterations, generator };
}

function worstOf(report) {
  let errorRate = 0;
  let p95 = 0;
  for (const [op, r] of Object.entries(report)) {
    if (op.startsWith('setup.')) continue;
    errorRate = Math.max(errorRate, r.errorRate);
    if (!op.startsWith('sync.')) p95 = Math.max(p95, r.latencyMs.p95 ?? 0);
  }
  return { errorRate, p95 };
}

async function main() {
  const started = new Date().toISOString();
  const phases = [];
  if (opts.mode === 'load') {
    const rec = new Recorder();
    const vus = await setupVus(opts.vus, rec);
    const { iterations, generator } = await runPhase(vus, opts.duration, rec);
    phases.push({ vus: vus.length, seconds: opts.duration, iterations, generator, report: rec.report(), ...(opts.raw ? { raw: Object.fromEntries(rec.ok) } : {}) });
    console.log(`VUs=${vus.length} iteraciones=${iterations} generador: lag p95=${generator.eventLoopLagMs.p95} ms, CPU=${generator.cpuCoreUsagePct} % de un núcleo`);
  } else {
    const steps = String(opts.steps).split(',').map(Number);
    for (const count of steps) {
      const rec = new Recorder();
      const vus = await setupVus(count, rec);
      const { iterations, generator } = await runPhase(vus, opts.stepDuration, rec);
      const report = rec.report();
      const worst = worstOf(report);
      phases.push({ vus: vus.length, seconds: opts.stepDuration, iterations, worst, generator, report, ...(opts.raw ? { raw: Object.fromEntries(rec.ok) } : {}) });
      console.log(`VUs=${vus.length} iteraciones=${iterations} peor tasa de error=${worst.errorRate}% peor p95=${worst.p95} ms | generador: lag p95=${generator.eventLoopLagMs.p95} ms, CPU=${generator.cpuCoreUsagePct} % de un núcleo`);
      if (worst.errorRate > opts.maxErrorRate || worst.p95 > opts.maxP95) {
        console.log('Umbral superado: se detiene la prueba de estrés.');
        break;
      }
    }
  }
  const out = { runId, started, finished: new Date().toISOString(), options: opts, accounts: accounts.length, households: households.size, phases };
  const file = new URL(`./results/${PREFIX}firestore-${opts.mode}${opts.tag ? `-${opts.tag}` : ''}-${runId}.json`, import.meta.url);
  writeFileSync(file, JSON.stringify(out, null, 2));
  console.log(JSON.stringify(phases.map((p) => ({ vus: p.vus, iterations: p.iterations, report: p.report })), null, 2));
  console.log(`Resultados: ${file.pathname}`);
  process.exit(0);
}

main().catch((e) => { console.error(e); process.exit(1); });
