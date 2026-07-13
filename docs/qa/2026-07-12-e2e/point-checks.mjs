/* Точечные проверки фиксов Kulibin (#6/#7/#8), которые e2e-run.mjs не покрывает полностью.
 * P1 watchdog-таймаут без DISCONNECT (жёсткий обрыв), P2 реальный дефолтный watchdog ≤10с,
 * P3 повторное открытие вкладки снова поднимает бейдж, P4 очистка метки свежести на сброс,
 * P5 плейсхолдер «ждём код по задаче <ID>» при пустом зеркале.
 * Запуск из корня репо: node docs/qa/2026-07-12-e2e/point-checks.mjs (сервер :8000 поднят). */
import { createRequire } from 'module';
const req = createRequire('/Users/nikolaykoreshkov/.nvm/versions/node/v22.22.2/lib/node_modules/@playwright/cli/node_modules/x');
const { chromium } = req('playwright');

const BASE = 'http://localhost:8000/platform';
const sleep = ms => new Promise(r => setTimeout(r, ms));
const results = [];
async function check(name, fn) {
  try { const note = await fn(); results.push({ name, pass: true, note: note || '' }); }
  catch (e) { results.push({ name, pass: false, note: String(e && e.message || e).slice(0, 300) }); }
}

const browser = await chromium.launch({ headless: true });

// ---- P1: watchdog-таймаут без DISCONNECT (симуляция жёсткого обрыва) ----
// Ускоряем контракт через window.HRI_* (heartbeat 300мс, watchdog 900мс), затем
// глушим heartbeat у кандидата, не давая ему послать DISCONNECT — бейдж должен
// погаснуть по сторожевому таймеру, а не остаться залипшим.
await check('P1 watchdog: молчание heartbeat гасит бейдж (без DISCONNECT)', async () => {
  const ctx = await browser.newContext();
  const iv = await ctx.newPage(); iv.on('dialog', d => d.accept());
  await iv.addInitScript(() => { window.HRI_LIVENESS_MS = 900; });
  const cd = await ctx.newPage();
  await cd.addInitScript(() => { window.HRI_HEARTBEAT_MS = 300; });
  await iv.goto(BASE + '/interviewer.html', { waitUntil: 'networkidle' });
  await iv.waitForSelector('#task-list .task-item');
  await cd.goto(BASE + '/candidate.html', { waitUntil: 'networkidle' });
  await sleep(500);
  const on = (await iv.locator('#conn-badge').textContent()).trim();
  if (on !== 'кандидат подключён') throw new Error('бейдж не поднялся: ' + on);
  // Глушим heartbeat И перехватываем DISCONNECT, имитируя жёсткий обрыв (сообщения не уходят).
  await cd.evaluate(() => {
    const bc = new BroadcastChannel('x5-fde-interview-v1');
    // забиваем канал? нельзя. Просто останавливаем таймеры страницы:
    let id = setInterval(() => {}, 100000);
    for (let i = 0; i < id; i++) clearInterval(i); // глушим все интервалы (включая heartbeat)
    // блокируем исходящие сообщения кандидата
    BroadcastChannel.prototype.postMessage = function () {};
  });
  await sleep(1400); // > watchdog 900мс
  const off = (await iv.locator('#conn-badge').textContent()).trim();
  await ctx.close();
  if (off !== 'кандидат не подключён') throw new Error('бейдж залип после молчания: ' + off);
  return 'бейдж погас по watchdog за ~1.4с (ускоренный контракт)';
});

// ---- P2: реальный дефолтный таймаут гасит бейдж в пределах ≤10с ----
await check('P2 реальный watchdog ≤10с при жёстком обрыве (дефолтные 8с)', async () => {
  const ctx = await browser.newContext();
  const iv = await ctx.newPage(); iv.on('dialog', d => d.accept());
  const cd = await ctx.newPage();
  await iv.goto(BASE + '/interviewer.html', { waitUntil: 'networkidle' });
  await iv.waitForSelector('#task-list .task-item');
  await cd.goto(BASE + '/candidate.html', { waitUntil: 'networkidle' });
  await sleep(500);
  // Жёсткий обрыв: глушим heartbeat и блокируем postMessage — DISCONNECT не уйдёт.
  await cd.evaluate(() => {
    for (let i = 0; i < 100000; i++) clearInterval(i);
    BroadcastChannel.prototype.postMessage = function () {};
  });
  const t0 = Date.now();
  let off = false;
  while (Date.now() - t0 < 10500) {
    const t = (await iv.locator('#conn-badge').textContent()).trim();
    if (t === 'кандидат не подключён') { off = true; break; }
    await sleep(300);
  }
  const dt = ((Date.now() - t0) / 1000).toFixed(1);
  await ctx.close();
  if (!off) throw new Error('бейдж не погас за 10.5с');
  return 'бейдж погас за ' + dt + 'с (≤10с)';
});

// ---- P3: повторное открытие вкладки снова поднимает бейдж ----
await check('P3 повторное открытие вкладки кандидата снова поднимает бейдж', async () => {
  const ctx = await browser.newContext();
  const iv = await ctx.newPage(); iv.on('dialog', d => d.accept());
  await iv.goto(BASE + '/interviewer.html', { waitUntil: 'networkidle' });
  await iv.waitForSelector('#task-list .task-item');
  let cd = await ctx.newPage();
  await cd.goto(BASE + '/candidate.html', { waitUntil: 'networkidle' });
  await sleep(500);
  if ((await iv.locator('#conn-badge').textContent()).trim() !== 'кандидат подключён') throw new Error('не поднялся при 1-м открытии');
  await cd.close();
  await sleep(1200); // DISCONNECT гасит
  if ((await iv.locator('#conn-badge').textContent()).trim() !== 'кандидат не подключён') throw new Error('не погас после закрытия');
  cd = await ctx.newPage();
  await cd.goto(BASE + '/candidate.html', { waitUntil: 'networkidle' });
  await sleep(500);
  const t = (await iv.locator('#conn-badge').textContent()).trim();
  await ctx.close();
  if (t !== 'кандидат подключён') throw new Error('не поднялся при повторном открытии: ' + t);
  return 'бейдж: поднят → погас → снова поднят';
});

// ---- P4: метка свежести очищается после сброса сессии (#8) ----
await check('P4 метка свежести очищается после сброса сессии', async () => {
  const ctx = await browser.newContext();
  const iv = await ctx.newPage(); iv.on('dialog', d => d.accept());
  const cd = await ctx.newPage();
  await iv.goto(BASE + '/interviewer.html', { waitUntil: 'networkidle' });
  await iv.waitForSelector('#task-list .task-item');
  await cd.goto(BASE + '/candidate.html', { waitUntil: 'networkidle' });
  await sleep(400);
  const tasks = JSON.parse(await (await fetch(BASE + '/tasks.json')).text()).tasks;
  const code = tasks.find(t => t.format === 'code' && !t.buggyVersion);
  await iv.locator('.task-item[data-id="' + code.id + '"]').click();
  await sleep(400);
  await cd.locator('#code-editor').fill('print(1)');
  await sleep(700);
  const before = await iv.locator('#mirror-freshness').textContent();
  if (!/обновлено/.test(before)) throw new Error('метки не было до сброса: ' + before);
  const hiddenBefore = await iv.locator('#mirror-freshness').evaluate(n => n.hidden);
  if (hiddenBefore) throw new Error('метка скрыта, хотя код пришёл');
  await iv.locator('#btn-reset').click();
  await sleep(600);
  const hiddenAfter = await iv.locator('#mirror-freshness').evaluate(n => n.hidden);
  const txtAfter = (await iv.locator('#mirror-freshness').textContent()).trim();
  await ctx.close();
  if (!hiddenAfter || txtAfter !== '') throw new Error('метка не очищена после сброса: hidden=' + hiddenAfter + ' txt=«' + txtAfter + '»');
  return 'до сброса: «' + before.trim() + '», после: скрыта и пуста';
});

// ---- P5: плейсхолдер «ждём код по задаче <ID>» при пустом зеркале по задаче (#7) ----
await check('P5 плейсхолдер «ждём код по задаче <ID>» при пустом зеркале', async () => {
  const ctx = await browser.newContext();
  const iv = await ctx.newPage(); iv.on('dialog', d => d.accept());
  const cd = await ctx.newPage();
  await iv.goto(BASE + '/interviewer.html', { waitUntil: 'networkidle' });
  await iv.waitForSelector('#task-list .task-item');
  await cd.goto(BASE + '/candidate.html', { waitUntil: 'networkidle' });
  await sleep(400);
  const tasks = JSON.parse(await (await fetch(BASE + '/tasks.json')).text()).tasks;
  // discussion-задача не шлёт код → зеркало пустое → плейсхолдер должен содержать ID
  const disc = tasks.find(t => t.format === 'discussion');
  await iv.locator('.task-item[data-id="' + disc.id + '"]').click();
  await sleep(500);
  const ph = await iv.locator('#candidate-mirror').getAttribute('data-placeholder');
  const mirrorText = (await iv.locator('#candidate-mirror').textContent()).trim();
  await ctx.close();
  if (mirrorText !== '') throw new Error('зеркало не пустое: ' + mirrorText);
  if (ph !== 'ждём код по задаче ' + disc.id) throw new Error('плейсхолдер: «' + ph + '»');
  return 'плейсхолдер: «' + ph + '»';
});

await browser.close();

const pass = results.filter(r => r.pass).length;
console.log('\n===== POINT-CHECKS ИТОГ: ' + pass + '/' + results.length + ' =====');
for (const r of results) console.log((r.pass ? 'PASS' : 'FAIL') + '  ' + r.name + (r.note ? '  — ' + r.note : ''));
process.exit(pass === results.length ? 0 : 1);
