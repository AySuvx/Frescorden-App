export function percentile(sorted, p) {
  if (sorted.length === 0) return null;
  const rank = (p / 100) * (sorted.length - 1);
  const lo = Math.floor(rank);
  const hi = Math.ceil(rank);
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);
}

export function summarize(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const n = sorted.length;
  if (n === 0) return { n: 0 };
  const mean = sorted.reduce((s, v) => s + v, 0) / n;
  const sd = n > 1 ? Math.sqrt(sorted.reduce((s, v) => s + (v - mean) ** 2, 0) / (n - 1)) : 0;
  const r = (v) => Math.round(v * 10) / 10;
  return {
    n,
    mean: r(mean),
    sd: r(sd),
    min: r(sorted[0]),
    p50: r(percentile(sorted, 50)),
    p95: r(percentile(sorted, 95)),
    p99: r(percentile(sorted, 99)),
    max: r(sorted[n - 1]),
  };
}

export class Recorder {
  constructor() {
    this.ok = new Map();
    this.errors = new Map();
  }

  async time(op, fn) {
    const start = performance.now();
    try {
      const result = await fn();
      this.#push(this.ok, op, performance.now() - start);
      return result;
    } catch (e) {
      const code = e?.code ?? e?.status ?? e?.name ?? 'error';
      const bucket = this.errors.get(op) ?? new Map();
      bucket.set(code, (bucket.get(code) ?? 0) + 1);
      this.errors.set(op, bucket);
      return undefined;
    }
  }

  record(op, ms) {
    this.#push(this.ok, op, ms);
  }

  #push(map, op, ms) {
    const list = map.get(op) ?? [];
    list.push(ms);
    map.set(op, list);
  }

  report() {
    const ops = new Set([...this.ok.keys(), ...this.errors.keys()]);
    const out = {};
    for (const op of ops) {
      const okCount = this.ok.get(op)?.length ?? 0;
      const errBucket = this.errors.get(op) ?? new Map();
      const errCount = [...errBucket.values()].reduce((s, v) => s + v, 0);
      out[op] = {
        latencyMs: summarize(this.ok.get(op) ?? []),
        ok: okCount,
        errors: errCount,
        errorRate: okCount + errCount > 0 ? Math.round((errCount / (okCount + errCount)) * 1000) / 10 : 0,
        errorCodes: Object.fromEntries(errBucket),
      };
    }
    return out;
  }
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
