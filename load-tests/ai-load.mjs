import { mkdirSync, writeFileSync, readdirSync, readFileSync, existsSync } from 'node:fs';
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import { getAI, getGenerativeModel, AgentPlatformBackend, Schema } from 'firebase/ai';
import { initApp, testAccounts, args } from './lib/firebase.mjs';
import { summarize, sleep } from './lib/stats.mjs';

const opts = args({
  fn: 'all',
  n: 20,
  turns: 5,
  concurrency: '1',
  pause: 500,
  maxRequests: 300,
  location: '',
  model: 'gemini-3.5-flash',
});

const SYSTEM_CHAT = `Eres el asistente culinario de Frescorden. Respondes únicamente sobre:
recetas con los alimentos disponibles, conservación y empaque de alimentos,
reducción de desperdicio, y cómo usar las funciones de la app.
Si te preguntan algo fuera de ese ámbito, redirige la conversación con
amabilidad hacia estos temas. Responde en español, breve y práctico.

Cuando sugieras una receta, usa siempre esta estructura:
**Nombre de la receta**
**Ingredientes de tu inventario:** (los que ya tiene el usuario)
**Ingredientes adicionales:** (los que necesitaría comprar)
**Pasos:** (breves, numerados)

Al final de CADA receta que sugieras, en su propia línea, agrega siempre
este enlace en formato Markdown (sin excepciones, incluso si sugieres
varias recetas en la misma respuesta — una línea de enlace por receta):
[Ver preparación en YouTube](https://www.youtube.com/results?search_query=Receta+NombreDeLaReceta)
Reemplaza "NombreDeLaReceta" por el nombre real de la receta, con espacios
reemplazados por "+" y sin tildes ni caracteres especiales (ej. una receta
llamada "Arroz con Pollo" da como resultado
https://www.youtube.com/results?search_query=Receta+Arroz+con+Pollo).
`;

const SYSTEM_RECIPE = `Eres un chef experto en cocina colombiana casera y sencilla, del día a día
(no gourmet ni con ingredientes difíciles de conseguir en Colombia).
Cuando te pidan una receta, responde con una receta colombiana realista,
priorizando los ingredientes del inventario que te compartan — si falta
algún ingrediente típico imprescindible, inclúyelo igual, el usuario podrá
comprarlo. Los pasos deben ser breves, claros y numerados en el orden de
preparación.
`;

const SYSTEM_VISION = `Eres un identificador de productos de supermercado para una app de
inventario de alimentos del hogar. Te muestran la foto de un producto
(empaque, fruta, verdura, etc.) y debes identificar tres cosas: su nombre
genérico y corto, SIN marca comercial (ej. "Leche entera", no "Leche
Alquería Deslactosada 1100ml"); la categoría de alimento que mejor le
corresponde; y la unidad más natural para medirlo en un inventario
doméstico.

Para productos empacados (bolsas, botellas, cajas, latas): el empaque casi
siempre tiene el nombre del alimento impreso — LEE ESE TEXTO para
identificar el producto (ej. una botella con la palabra "Agua" es agua, una
bolsa con "Arroz" es arroz), en vez de intentar adivinarlo solo por la
forma o el color del empaque. Ignora la marca y el eslogan publicitario;
usa solo la palabra que nombra el alimento en sí.

Si la imagen no muestra un alimento reconocible, usa "Producto no
identificado" como nombre y la categoría "otros".
`;

const CATEGORIES = [
  'lacteos', 'carnesYEmbutidos', 'granosYCereales', 'panaderia', 'bebidas', 'congelados',
  'condimentosYSalsas', 'enlatadosYConservas', 'otros', 'frutas', 'verdurasYHortalizas',
];
const UNITS = ['unidad', 'kg', 'g', 'L', 'ml', 'lbs', 'oz'];

const PANTRY = [
  ['Leche entera', 1, 'L'], ['Arroz', 2, 'kg'], ['Huevos', 12, 'unidad'], ['Tomate', 1, 'kg'],
  ['Cebolla cabezona', 3, 'unidad'], ['Papa pastusa', 2, 'kg'], ['Pechuga de pollo', 1, 'kg'],
  ['Queso campesino', 500, 'g'], ['Plátano maduro', 4, 'unidad'], ['Lentejas', 500, 'g'],
  ['Zanahoria', 1, 'kg'], ['Pan tajado', 1, 'unidad'], ['Arepas', 10, 'unidad'],
  ['Frijol rojo', 500, 'g'], ['Carne molida', 500, 'g'], ['Yuca', 1, 'kg'],
  ['Cilantro', 1, 'unidad'], ['Ajo', 1, 'unidad'], ['Aguacate', 2, 'unidad'], ['Mantequilla', 250, 'g'],
  ['Pasta', 500, 'g'], ['Atún en lata', 2, 'unidad'],
];

const QUESTIONS = [
  '¿Qué puedo cocinar hoy con lo que tengo?',
  '¿Cómo conservo mejor el cilantro para que no se dañe rápido?',
  'Dame una receta rápida para la cena.',
  '¿Qué hago con los productos que están por vencer?',
  '¿Cómo agrego un producto a granel en la app?',
  'Sugiéreme un almuerzo para cuatro personas.',
  '¿Puedo congelar el pan tajado?',
];

function inventoryContext(size) {
  const items = [...PANTRY].sort(() => Math.random() - 0.5).slice(0, size).map(([name, qty, unit]) => ({
    name, qty, unit, days: Math.floor(Math.random() * 15) - 2,
  }));
  items.sort((a, b) => a.days - b.days);
  const lines = items.slice(0, 20).map((p) => {
    const when = p.days < 0 ? `vencido hace ${-p.days} días` : `vence en ${p.days} días`;
    return `- ${p.name}: ${p.qty} ${p.unit}, ${when}`;
  }).join('\n');
  return `Inventario disponible (priorizado por lo que vence antes o lleva más tiempo almacenado):\n${lines}`;
}

function usageOf(response) {
  const u = response?.usageMetadata ?? {};
  const imageTokens = (u.promptTokensDetails ?? []).filter((d) => d.modality === 'IMAGE').reduce((s, d) => s + (d.tokenCount ?? 0), 0);
  return {
    prompt: u.promptTokenCount ?? 0,
    promptImage: imageTokens,
    output: u.candidatesTokenCount ?? 0,
    thoughts: u.thoughtsTokenCount ?? 0,
    cached: u.cachedContentTokenCount ?? 0,
    total: u.totalTokenCount ?? 0,
  };
}

let requestsSent = 0;
function budget() {
  if (requestsSent >= opts.maxRequests) throw Object.assign(new Error('maxRequests alcanzado'), { code: 'budget' });
  requestsSent++;
}

async function timed(fn) {
  const start = performance.now();
  try {
    const response = await fn();
    return { ok: true, ms: performance.now() - start, usage: usageOf(response) };
  } catch (e) {
    return { ok: false, ms: performance.now() - start, error: `${e?.code ?? e?.status ?? 'error'}: ${String(e?.message ?? e).slice(0, 160)}` };
  }
}

function models(ai) {
  return {
    chat: getGenerativeModel(ai, { model: opts.model, systemInstruction: SYSTEM_CHAT }),
    recipe: getGenerativeModel(ai, {
      model: opts.model,
      systemInstruction: SYSTEM_RECIPE,
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: Schema.object({
          properties: {
            nombre: Schema.string({ description: 'Nombre de la receta' }),
            personas: Schema.integer({ description: 'Porciones, típicamente entre 2 y 6' }),
            tiempo_minutos: Schema.integer({ description: 'Tiempo total de preparación en minutos' }),
            ingredientes: Schema.array({
              items: Schema.object({
                properties: {
                  nombre: Schema.string(),
                  cantidad: Schema.number(),
                  unidad: Schema.string({ description: 'Ej: gramos, ml, unidades, tazas, dientes' }),
                },
              }),
            }),
            pasos: Schema.array({ items: Schema.string({ description: 'Un paso de preparación, breve' }) }),
          },
        }),
      },
    }),
    vision: getGenerativeModel(ai, {
      model: opts.model,
      systemInstruction: SYSTEM_VISION,
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: Schema.object({
          properties: {
            nombre: Schema.string({ description: 'Nombre genérico y corto del producto, sin marca' }),
            categoria: Schema.enumString({ enum: CATEGORIES, description: 'Categoría de alimento que mejor corresponde' }),
            unidad: Schema.enumString({ enum: UNITS, description: 'Unidad más natural para medir este producto' }),
          },
        }),
      },
    }),
  };
}

async function chatConversation(m) {
  const chat = m.chat.startChat();
  const turns = [];
  for (let t = 0; t < opts.turns; t++) {
    budget();
    const q = QUESTIONS[Math.floor(Math.random() * QUESTIONS.length)];
    const prompt = `${inventoryContext(20)}\n\nConsulta: ${q}`;
    const r = await timed(() => chat.sendMessage(prompt).then((x) => x.response));
    turns.push({ turn: t + 1, ...r });
    if (!r.ok) break;
    await sleep(opts.pause);
  }
  return turns;
}

async function recipeCall(m) {
  budget();
  const prompt = `Crea una receta colombiana casera y sencilla usando prioritariamente estos ingredientes disponibles en el hogar:\n${inventoryContext(20)}`;
  return timed(() => m.recipe.generateContent(prompt).then((x) => x.response));
}

function photos() {
  const dir = new URL('./photos/', import.meta.url);
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((f) => /\.jpe?g$/i.test(f)).map((f) => readFileSync(new URL(f, dir)).toString('base64'));
}

async function visionCall(m, b64) {
  budget();
  return timed(() => m.vision.generateContent([
    'Identifica este producto de supermercado.',
    { inlineData: { mimeType: 'image/jpeg', data: b64 } },
  ]).then((x) => x.response));
}

function aggregate(results) {
  const ok = results.filter((r) => r.ok);
  const pick = (k) => ok.map((r) => r.usage[k]);
  const errors = {};
  for (const r of results.filter((x) => !x.ok)) errors[r.error] = (errors[r.error] ?? 0) + 1;
  return {
    requests: results.length,
    ok: ok.length,
    errorRate: results.length ? Math.round(((results.length - ok.length) / results.length) * 1000) / 10 : 0,
    errors,
    latencyMs: summarize(ok.map((r) => r.ms)),
    tokens: {
      prompt: summarize(pick('prompt')),
      promptImage: summarize(pick('promptImage')),
      output: summarize(pick('output')),
      thoughts: summarize(pick('thoughts')),
      total: summarize(pick('total')),
    },
  };
}

async function runWithConcurrency(count, concurrency, task) {
  const results = [];
  let next = 0;
  await Promise.all(Array.from({ length: concurrency }, async () => {
    while (next < count) {
      next++;
      const r = await task();
      if (Array.isArray(r)) results.push(...r); else results.push(r);
      await sleep(opts.pause);
    }
  }));
  return results;
}

async function main() {
  const account = testAccounts()[0];
  const app = initApp('ai-load');
  await signInWithEmailAndPassword(getAuth(app), account.email, account.password);
  const ai = getAI(app, { backend: opts.location ? new AgentPlatformBackend(opts.location) : new AgentPlatformBackend() });
  const m = models(ai);
  const imgs = photos();
  const fns = opts.fn === 'all' ? ['chat', 'recipe', 'vision'] : String(opts.fn).split(',');
  const levels = String(opts.concurrency).split(',').map(Number);
  const out = { started: new Date().toISOString(), options: opts, photos: imgs.length, runs: [] };

  for (const fn of fns) {
    if (fn === 'vision' && imgs.length === 0) {
      console.log('Sin fotos en load-tests/photos/: se omite el reconocimiento por foto.');
      continue;
    }
    for (const c of levels) {
      let results;
      try {
        if (fn === 'chat') {
          results = await runWithConcurrency(opts.n, c, () => chatConversation(m));
        } else if (fn === 'recipe') {
          results = await runWithConcurrency(opts.n, c, () => recipeCall(m));
        } else {
          let i = 0;
          results = await runWithConcurrency(opts.n, c, () => visionCall(m, imgs[i++ % imgs.length]));
        }
      } catch (e) {
        if (e.code !== 'budget') throw e;
        results = [];
      }
      const run = { fn, concurrency: c, ...aggregate(results) };
      if (fn === 'chat') {
        run.byTurn = {};
        for (let t = 1; t <= opts.turns; t++) {
          run.byTurn[t] = summarize(results.filter((r) => r.ok && r.turn === t).map((r) => r.usage.total));
        }
      }
      out.runs.push(run);
      console.log(`${fn} concurrencia=${c} solicitudes=${run.requests} error=${run.errorRate}% tokens totales medios=${run.tokens.total.mean} p95 latencia=${run.latencyMs.p95} ms`);
      if (requestsSent >= opts.maxRequests) break;
    }
  }
  out.finished = new Date().toISOString();
  out.requestsSent = requestsSent;
  mkdirSync(new URL('./results/', import.meta.url), { recursive: true });
  const file = new URL(`./results/ai-${out.started.replace(/[:.]/g, '-')}.json`, import.meta.url);
  writeFileSync(file, JSON.stringify(out, null, 2));
  console.log(`Resultados: ${file.pathname}`);
  process.exit(0);
}

main().catch((e) => { console.error(e); process.exit(1); });
