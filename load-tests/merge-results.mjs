import { readFileSync, writeFileSync } from 'node:fs';
import { summarize } from './lib/stats.mjs';

const files = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const outArg = process.argv.find((a) => a.startsWith('--out='));
if (files.length === 0) {
  console.error('Uso: node merge-results.mjs results/a.json results/b.json [--out=results/merged.json]');
  process.exit(1);
}
const runs = files.map((f) => JSON.parse(readFileSync(f, 'utf8')));
const merged = { sources: files, vus: 0, iterations: 0, generators: [], operations: {} };
const raw = {};
const errors = {};
for (const run of runs) {
  const phase = run.phases[run.phases.length - 1];
  if (!phase.raw) throw new Error('Los resultados deben generarse con --raw.');
  merged.vus += phase.vus;
  merged.iterations += phase.iterations;
  merged.generators.push(phase.generator);
  for (const [op, values] of Object.entries(phase.raw)) (raw[op] ??= []).push(...values);
  for (const [op, r] of Object.entries(phase.report)) errors[op] = (errors[op] ?? 0) + r.errors;
}
for (const [op, values] of Object.entries(raw)) {
  const ok = values.length;
  merged.operations[op] = { latencyMs: summarize(values), ok, errors: errors[op] ?? 0, errorRate: Math.round(((errors[op] ?? 0) / (ok + (errors[op] ?? 0))) * 1000) / 10 };
}
const out = outArg ? outArg.slice(6) : 'results/firestore-merged.json';
writeFileSync(out, JSON.stringify(merged, null, 2));
console.log(JSON.stringify(merged, null, 2));
