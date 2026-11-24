import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';

const PROJECT = 'frescorden';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const SUBCOLLECTIONS = ['productos', 'product_history', 'activity_log', 'assistant_usage'];
const token = JSON.parse(readFileSync(`${homedir()}/.config/configstore/firebase-tools.json`, 'utf8')).tokens.access_token;
const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

async function api(url, body) {
  const res = await fetch(url, body ? { method: 'POST', headers, body: JSON.stringify(body) } : { headers });
  const json = await res.json();
  if (!res.ok) throw new Error(`${res.status} ${JSON.stringify(json).slice(0, 200)}`);
  return json;
}

async function testHouseholds() {
  const rows = await api(`${BASE}:runQuery`, {
    structuredQuery: {
      from: [{ collectionId: 'households' }],
      where: { fieldFilter: { field: { fieldPath: 'loadTest' }, op: 'EQUAL', value: { booleanValue: true } } },
      select: { fields: [{ fieldPath: 'name' }] },
    },
  });
  return rows.filter((r) => r.document && r.document.fields.name.stringValue.startsWith('LOADTEST ')).map((r) => r.document.name);
}

async function listNames(parent, collection) {
  const names = [];
  let pageToken = '';
  do {
    const url = `https://firestore.googleapis.com/v1/${parent}/${collection}?pageSize=300&mask.fieldPaths=loadTest${pageToken ? `&pageToken=${pageToken}` : ''}`;
    const page = await api(url);
    for (const d of page.documents ?? []) names.push(d.name);
    pageToken = page.nextPageToken ?? '';
  } while (pageToken);
  return names;
}

async function deleteAll(names) {
  for (let i = 0; i < names.length; i += 400) {
    await api(`${BASE}:commit`, { writes: names.slice(i, i + 400).map((n) => ({ delete: n })) });
  }
}

const households = await testHouseholds();
console.log(`Hogares de prueba encontrados: ${households.length}`);
let docs = 0;
for (const [i, h] of households.entries()) {
  const children = [];
  for (const sub of SUBCOLLECTIONS) children.push(...await listNames(h, sub));
  await deleteAll([...children, h]);
  docs += children.length + 1;
  if ((i + 1) % 10 === 0) console.log(`${i + 1}/${households.length} hogares borrados`);
}
const left = await testHouseholds();
console.log(`Documentos borrados: ${docs}. Hogares de prueba restantes: ${left.length}`);
