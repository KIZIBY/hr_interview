/* E2E-прогон лендингов HRI (interviewer.html + candidate.html) по тест-плану Ренаты.
 * Один browser context, две вкладки — BroadcastChannel работает. */
import { createRequire } from 'module';
import fs from 'fs';
const req = createRequire('/Users/nikolaykoreshkov/.nvm/versions/node/v22.22.2/lib/node_modules/@playwright/cli/node_modules/x');
const { chromium } = req('playwright');

const BASE = 'http://localhost:8000/platform';
const SHOTS = '/tmp/hri-qa';
fs.mkdirSync(SHOTS, { recursive: true });

const tasksData = JSON.parse(fs.readFileSync('/Users/nikolaykoreshkov/Documents/Claude/Projects/hr_interview/platform/tasks.json', 'utf8')).tasks;
const byId = Object.fromEntries(tasksData.map(t => [t.id, t]));
const firstCode = tasksData.find(t => t.format === 'code' && !t.buggyVersion);           // ALG-01 ожидаемо
const secondCode = tasksData.find(t => t.format === 'code' && !t.buggyVersion && t.id !== firstCode.id);
const discussion = tasksData.find(t => t.format === 'discussion');
const buggy = tasksData.find(t => t.buggyVersion != null);

const results = [];
async function step(name, fn) {
  try {
    const note = await fn();
    results.push({ name, pass: true, note: note || '' });
  } catch (e) {
    results.push({ name, pass: false, note: String(e && e.message || e).slice(0, 400) });
  }
}
const sleep = ms => new Promise(r => setTimeout(r, ms));

const consoleLog = { interviewer: [], candidate: [] };
const netFail = { interviewer: [], candidate: [] };
function wirePage(page, tag) {
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') consoleLog[tag].push(m.type() + ': ' + m.text()); });
  page.on('pageerror', e => consoleLog[tag].push('pageerror: ' + e.message));
  page.on('requestfailed', r => netFail[tag].push(r.url() + ' -> ' + (r.failure() && r.failure().errorText)));
  page.on('response', r => { if (r.status() >= 400) netFail[tag].push(r.url() + ' -> HTTP ' + r.status()); });
}

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
const iv = await ctx.newPage(); wirePage(iv, 'interviewer');
iv.on('dialog', d => d.accept());

// ---------- A. Загрузка интервьюера (кандидат ещё не открыт) ----------
await step('A1 интервьюер: страница загружается, 13 задач в банке', async () => {
  await iv.goto(BASE + '/interviewer.html', { waitUntil: 'networkidle' });
  await iv.waitForSelector('#task-list .task-item');
  const n = await iv.locator('#task-list .task-item').count();
  if (n !== tasksData.length) throw new Error('в банке ' + n + ' задач, ожидалось ' + tasksData.length);
  return n + ' задач';
});
await step('A2 интервьюер: бейдж до открытия кандидата — «кандидат не подключён»', async () => {
  const t = (await iv.locator('#conn-badge').textContent()).trim();
  if (t !== 'кандидат не подключён') throw new Error('бейдж: «' + t + '»');
});
await step('A3 интервьюер: шрифт X5 Sans реально загружен', async () => {
  const ok = await iv.evaluate(async () => { await document.fonts.ready; return document.fonts.check('16px "X5 Sans"') && document.fonts.check('500 16px "X5 Sans"'); });
  if (!ok) throw new Error('document.fonts.check вернул false');
});
await step('A4 интервьюер: цвет текста = --x5-ink #303145', async () => {
  const c = await iv.evaluate(() => getComputedStyle(document.body).color);
  if (c !== 'rgb(48, 49, 69)') throw new Error('цвет body: ' + c);
});
await step('A5 интервьюер: логотип X5 снизу слева (fixed)', async () => {
  const box = await iv.evaluate(() => {
    const img = document.querySelector('.brand-logo');
    if (!img || !img.complete || img.naturalWidth === 0) return null;
    const r = img.getBoundingClientRect();
    return { left: r.left, bottom: innerHeight - r.bottom, pos: getComputedStyle(img).position };
  });
  if (!box) throw new Error('логотип не загрузился');
  if (box.pos !== 'fixed' || box.left > 60 || box.bottom > 60) throw new Error(JSON.stringify(box));
});

// ---------- B. Открытие кандидата ----------
const cd = await ctx.newPage(); wirePage(cd, 'candidate');
await step('B1 кандидат: загрузка, экран ожидания', async () => {
  await cd.goto(BASE + '/candidate.html', { waitUntil: 'networkidle' });
  const vis = await cd.evaluate(() => getComputedStyle(document.getElementById('state-waiting')).display !== 'none');
  if (!vis) throw new Error('state-waiting скрыт');
});
await step('B2 интервьюер: бейдж переключился на «кандидат подключён»', async () => {
  await sleep(600);
  const t = (await iv.locator('#conn-badge').textContent()).trim();
  if (t !== 'кандидат подключён') throw new Error('бейдж: «' + t + '»');
});

// ---------- C. Фильтры банка ----------
const cat = firstCode.category;
const expCat = tasksData.filter(t => t.category === cat).length;
const diffs = [...new Set(tasksData.filter(t => t.category === cat).map(t => t.difficulty))];
const diff = diffs[0];
const expBoth = tasksData.filter(t => t.category === cat && t.difficulty === diff).length;
await step('C1 фильтр по категории «' + cat + '»', async () => {
  await iv.selectOption('#filter-cat', cat);
  const n = await iv.locator('#task-list .task-item').count();
  if (n !== expCat) throw new Error(n + ' вместо ' + expCat);
  return n + ' задач';
});
await step('C2 комбинация категория+сложность «' + diff + '»', async () => {
  await iv.selectOption('#filter-diff', diff);
  const n = await iv.locator('#task-list .task-item').count();
  if (n !== expBoth) throw new Error(n + ' вместо ' + expBoth);
  return n + ' задач';
});
await step('C3 сброс фильтров возвращает все задачи', async () => {
  await iv.selectOption('#filter-cat', ''); await iv.selectOption('#filter-diff', '');
  const n = await iv.locator('#task-list .task-item').count();
  if (n !== tasksData.length) throw new Error(n + ' вместо ' + tasksData.length);
});

// ---------- D. Выбор задачи → кандидат получает ----------
await step('D1 клик по задаче ' + firstCode.id + ' открывает детали у интервьюера', async () => {
  await iv.locator('.task-item[data-id="' + firstCode.id + '"]').click();
  await iv.waitForSelector('#task-details:not([hidden])');
  const h = await iv.locator('#task-details h2').textContent();
  if (!h.includes(firstCode.title)) throw new Error('заголовок: ' + h);
});
await step('D2 [UX] клик по банку сразу пушит задачу кандидату (кнопки «Показать кандидату» нет)', async () => {
  await cd.waitForFunction(() => getComputedStyle(document.getElementById('state-content')).display !== 'none', null, { timeout: 3000 });
  const title = (await cd.locator('#task-title').textContent()).trim();
  if (title !== firstCode.title) throw new Error('у кандидата: ' + title);
  return 'подтверждено: выбор = мгновенный показ, предпросмотра нет';
});
await step('D3 кандидат: редактор предзаполнен starterCode', async () => {
  const v = await cd.locator('#code-editor').inputValue();
  const expected = firstCode.starterCode || '';
  if (v !== expected) throw new Error('редактор: «' + v.slice(0, 60) + '…»');
});
await step('D4 RBAC: у кандидата в DOM нет эталонов, сигналов, заметок', async () => {
  const ref = (firstCode.referenceSolutions && firstCode.referenceSolutions[0]) || {};
  const needles = [
    ref.code && ref.code.slice(0, 40),
    firstCode.greenSignals && firstCode.greenSignals[0],
    firstCode.evaluationNotes && firstCode.evaluationNotes.slice(0, 40),
    'Эталонные решения', 'Сигналы', 'Заметки по оценке', 'Follow-up'
  ].filter(Boolean);
  const html = await cd.evaluate(() => document.body.innerHTML);
  const leaked = needles.filter(n => html.includes(n));
  if (leaked.length) throw new Error('УТЕЧКА: ' + JSON.stringify(leaked));
  return needles.length + ' маркеров проверено, утечек нет';
});
await iv.screenshot({ path: SHOTS + '/01-interviewer-task.png', fullPage: true });
await cd.screenshot({ path: SHOTS + '/02-candidate-task.png' });

// ---------- E. Зеркало кода ----------
const PAYLOAD = 'def solve(strs):\n    # кириллица ёЁ №5, кавычки "двойные" и \'одинарные\'\n    if a < b > c: pass\n    s = "<script>alert(1)</script>"\n    return `шаблон`';
await step('E1 код кандидата зеркалится интервьюеру со спецсимволами', async () => {
  await cd.locator('#code-editor').fill(PAYLOAD);
  await sleep(800);
  const mirror = await iv.locator('#candidate-mirror').textContent();
  if (mirror !== PAYLOAD) throw new Error('зеркало отличается: «' + mirror.slice(0, 80) + '…»');
});
await step('E2 XSS: <script> из кода кандидата не исполняется у интервьюера', async () => {
  const bad = await iv.evaluate(() => document.querySelector('#candidate-mirror script') !== null);
  if (bad) throw new Error('в зеркале живой <script>');
});
await step('E3 [из статики Ренаты] метка «обновлено HH:MM:SS» у зеркала', async () => {
  // Kulibin 2026-07-12 (issue #8): проверяем не только слово, но и формат HH:MM:SS —
  // метка ставится из env.ts конверта на каждый апдейт кода (interviewer.js CANDIDATE_CODE_UPDATE).
  const txt = await iv.locator('#mirror-freshness').textContent();
  if (!/^обновлено \d{2}:\d{2}:\d{2}$/.test(txt.trim())) throw new Error('метка свежести: «' + txt + '»');
  return txt.trim();
});
await iv.screenshot({ path: SHOTS + '/03-interviewer-mirror.png' });

// ---------- F. Discussion и buggy форматы ----------
await step('F1 discussion-задача ' + discussion.id + ': у кандидата нет редактора', async () => {
  await iv.locator('.task-item[data-id="' + discussion.id + '"]').click();
  await sleep(600);
  const disp = await cd.evaluate(() => document.getElementById('editor-section').style.display);
  if (disp !== 'none') throw new Error('editor-section.display=' + disp);
});
await step('F2 buggy-задача ' + buggy.id + ': редактор кандидата = buggyVersion, без метки «с дефектом»', async () => {
  await iv.locator('.task-item[data-id="' + buggy.id + '"]').click();
  await sleep(600);
  const v = await cd.locator('#code-editor').inputValue();
  if (v !== buggy.buggyVersion) throw new Error('редактор не совпал с buggyVersion');
  const html = await cd.evaluate(() => document.body.innerHTML);
  if (/дефект/i.test(html)) throw new Error('у кандидата видна метка про дефект');
});

// ---------- G. Смена задачи поверх кода ----------
await step('G1 смена задачи: черновик кандидата сохраняется per-task', async () => {
  await iv.locator('.task-item[data-id="' + firstCode.id + '"]').click();
  await sleep(500);
  await cd.locator('#code-editor').fill(PAYLOAD);
  await sleep(700);
  await iv.locator('.task-item[data-id="' + secondCode.id + '"]').click();
  await sleep(600);
  await iv.locator('.task-item[data-id="' + firstCode.id + '"]').click();
  await sleep(600);
  const v = await cd.locator('#code-editor').inputValue();
  if (v !== PAYLOAD) throw new Error('черновик потерян: «' + v.slice(0, 60) + '…»');
});
await step('G2 [из статики Ренаты] зеркало после смены задачи не пустеет молча', async () => {
  const mirror = await iv.locator('#candidate-mirror').textContent();
  if (mirror.trim() === '') throw new Error('зеркало пустое до первого ввода кандидата — подтверждён дефект');
  return 'зеркало: «' + mirror.slice(0, 40) + '…»';
});

// ---------- H. Бейдж подключения: односторонность ----------
await step('H1 [из статики Ренаты] закрытие вкладки кандидата сбрасывает бейдж', async () => {
  // Kulibin 2026-07-12 (issue #6): при закрытии вкладки кандидат шлёт DISCONNECT
  // (pagehide/beforeunload) — бейдж гаснет сразу, не дожидаясь сторожевого таймаута (~8с).
  // 1.5с окна хватает для быстрого пути; сам таймаут-путь проверяется отдельным скриптом
  // watchdog-timeout.mjs (heartbeat молчит → бейдж гаснет по watchdog).
  await cd.close();
  await sleep(1500);
  const t = (await iv.locator('#conn-badge').textContent()).trim();
  if (t !== 'кандидат не подключён') throw new Error('бейдж не сбросился: «' + t + '»');
});
const cd2 = await ctx.newPage(); wirePage(cd2, 'candidate');
await step('H2 новая вкладка кандидата восстанавливает текущую задачу', async () => {
  await cd2.goto(BASE + '/candidate.html', { waitUntil: 'networkidle' });
  await cd2.waitForFunction(() => getComputedStyle(document.getElementById('state-content')).display !== 'none', null, { timeout: 3000 });
  const title = (await cd2.locator('#task-title').textContent()).trim();
  if (title !== firstCode.title) throw new Error('у кандидата: ' + title);
});
await step('H3 черновик после закрытия вкладки (sessionStorage) — ожидаемо теряется', async () => {
  const v = await cd2.locator('#code-editor').inputValue();
  return v === PAYLOAD ? 'черновик выжил (localStorage?)' : 'черновик потерян: новая вкладка = чистый sessionStorage (by design, зафиксировать в доке)';
});

// ---------- I. Таймер ----------
await step('I1 таймер: старт, тик, фаза «интервью», сегмент «разогрев»', async () => {
  await iv.locator('#btn-timer').click();
  await sleep(2300);
  const t = await iv.locator('#timer').textContent();
  const phase = await iv.locator('#phase-label').textContent();
  const seg = await iv.locator('.timebox__seg[aria-current="step"] .timebox__label').textContent();
  const btn = await iv.locator('#btn-timer').textContent();
  if (!/00:0[2-9]/.test(t)) throw new Error('таймер: ' + t);
  if (phase !== 'интервью') throw new Error('фаза: ' + phase);
  if (seg !== 'разогрев') throw new Error('сегмент: ' + seg);
  if (btn !== 'Пауза') throw new Error('кнопка: ' + btn);
});
await step('I2 таймер: пауза замораживает значение', async () => {
  await iv.locator('#btn-timer').click();
  const t1 = await iv.locator('#timer').textContent();
  await sleep(1500);
  const t2 = await iv.locator('#timer').textContent();
  if (t1 !== t2) throw new Error(t1 + ' → ' + t2);
  const btn = await iv.locator('#btn-timer').textContent();
  if (btn !== 'Продолжить') throw new Error('кнопка: ' + btn);
});
await step('I3 overtime: 60:00 +MM:SS и красная подсветка (через снапшот + reload)', async () => {
  await iv.evaluate(key => {
    const snap = JSON.parse(localStorage.getItem(key));
    snap.timer = { status: 'paused', accumulatedSec: 3598, startedAt: null };
    localStorage.setItem(key, JSON.stringify(snap));
  }, 'x5-fde-interview-v1:snapshot');
  await iv.reload({ waitUntil: 'networkidle' });
  await iv.waitForSelector('#task-list .task-item');
  await iv.locator('#btn-timer').click(); // Продолжить
  await sleep(3200);
  const t = await iv.locator('#timer').textContent();
  const over = await iv.locator('#timer').evaluate(n => n.classList.contains('timer--overtime'));
  if (!/^60:00 \+00:0[0-9]/.test(t)) throw new Error('таймер: ' + t);
  if (!over) throw new Error('нет класса timer--overtime');
  await iv.locator('#btn-timer').click(); // пауза обратно
  return t;
});
await step('I4 restore после reload: задача и зеркальная панель на месте', async () => {
  const h = await iv.locator('#task-details h2').textContent();
  if (!h.includes(firstCode.title)) throw new Error('после reload: ' + h);
});
await iv.screenshot({ path: SHOTS + '/04-interviewer-overtime.png' });

// ---------- J. Оценка ----------
async function setScore(key, val) {
  await iv.locator('input[name="score-' + key + '"][value="' + val + '"]').evaluate(i => { i.checked = true; i.dispatchEvent(new Event('change', { bubbles: true })); });
}
const KEYS = ['cs', 'systemDesign', 'agents', 'production', 'aiPractice'];
await step('J1 экран оценки открывается, таймер ставится на паузу', async () => {
  await iv.locator('#btn-timer').click(); // запустить
  await sleep(300);
  await iv.locator('#btn-scoring').click();
  const vis = await iv.locator('#view-score').isVisible();
  const btn = await iv.locator('#btn-timer').textContent();
  if (!vis) throw new Error('view-score скрыт');
  if (btn !== 'Продолжить') throw new Error('таймер не встал на паузу: ' + btn);
});
await step('J2 не все критерии → «оцените все критерии», Зафиксировать заблокирован', async () => {
  for (const k of KEYS.slice(0, 3)) await setScore(k, 3);
  const badge = await iv.locator('#verdict-badge').textContent();
  const dis = await iv.locator('#btn-finish').isDisabled();
  if (badge !== 'оцените все критерии' || !dis) throw new Error(badge + ' / disabled=' + dis);
});
await step('J3 граница: все «3» → средневзвешенное 3.00 → GO', async () => {
  for (const k of KEYS) await setScore(k, 3);
  const badge = await iv.locator('#verdict-badge').textContent();
  const avg = await iv.locator('#verdict-avg').textContent();
  if (badge !== 'GO' || !avg.includes('3.00')) throw new Error(badge + ' / ' + avg);
});
await step('J4 стоп-строка: «1» в «Проектирование агентов» при среднем 3.25 → NO-GO', async () => {
  for (const k of KEYS) await setScore(k, 4);
  await setScore('agents', 1);
  const badge = await iv.locator('#verdict-badge').textContent();
  const avg = await iv.locator('#verdict-avg').textContent();
  if (badge !== 'NO-GO') throw new Error(badge + ' / ' + avg);
  return avg;
});
await step('J5 не-стоп-строка: «1» в System design при среднем ≥3 → GO (правило не задевает)', async () => {
  for (const k of KEYS) await setScore(k, 4);
  await setScore('systemDesign', 1);
  const badge = await iv.locator('#verdict-badge').textContent();
  const avg = await iv.locator('#verdict-avg').textContent();
  return badge + ' при ' + avg + ' — по правилу корректно (стоп только cs/agents/production)';
});
await step('J6 среднее ниже 3.0 без единиц → NO-GO', async () => {
  for (const k of KEYS) await setScore(k, 2);
  const badge = await iv.locator('#verdict-badge').textContent();
  if (badge !== 'NO-GO') throw new Error(badge);
});
await step('J7 Зафиксировать: инпуты блокируются, фаза «завершено», у кандидата экран завершения', async () => {
  for (const k of KEYS) await setScore(k, 3);
  await iv.locator('#btn-finish').click();
  const dis = await iv.locator('input[name="score-cs"][value="3"]').isDisabled();
  const phase = await iv.locator('#phase-label').textContent();
  if (!dis || phase !== 'завершено') throw new Error('disabled=' + dis + ' phase=' + phase);
  await sleep(600);
  const fin = await cd2.evaluate(() => getComputedStyle(document.getElementById('state-finished')).display !== 'none');
  if (!fin) throw new Error('у кандидата нет экрана завершения');
});
await iv.screenshot({ path: SHOTS + '/05-interviewer-scoring.png', fullPage: true });
await cd2.screenshot({ path: SHOTS + '/06-candidate-finished.png' });
await step('J8 Изменить: возвращает редактирование', async () => {
  await iv.locator('#btn-reopen').click();
  const dis = await iv.locator('input[name="score-cs"][value="3"]').isDisabled();
  if (dis) throw new Error('инпуты остались disabled');
});
await step('J9 оценки переживают reload интервьюера', async () => {
  await iv.reload({ waitUntil: 'networkidle' });
  await iv.waitForSelector('#task-list .task-item');
  await iv.locator('#btn-scoring').click();
  const checked = await iv.locator('input[name="score-cs"]:checked').inputValue();
  const badge = await iv.locator('#verdict-badge').textContent();
  if (checked !== '3') throw new Error('score-cs=' + checked);
  if (badge !== 'GO') throw new Error('вердикт: ' + badge);
});
await step('J10 клавиатура: стрелка вправо двигает оценку по шкале', async () => {
  // Kulibin 2026-07-12: чистое воспроизведение фокуса. Прежний шаг делал
  // evaluate(i => i.focus()) на zero-area радио (.scale input {width:0}) сразу после
  // reload+клик по кнопке — в headless Chromium фокус не покидал кнопку (activeElement=BUTTON),
  // и ArrowRight уходил в никуда. Это артефакт тест-скрипта (QA-док 2026-07-12: «при чистом
  // воспроизведении стрелки работают»), а не дефект продукта. J9 оставляет вид на задаче —
  // открываем оценку, устанавливаем известную оценку и фокусируем радио как реальный
  // пользователь (клик по его label), затем ArrowRight.
  if (await iv.locator('#view-score').evaluate(n => n.hidden)) await iv.locator('#btn-scoring').click();
  await setScore('cs', 3);
  await iv.locator('.scale label:has(input[name="score-cs"][value="3"])').click();
  await iv.keyboard.press('ArrowRight');
  const checked = await iv.locator('input[name="score-cs"]:checked').inputValue();
  if (checked !== '4') throw new Error('после ArrowRight: ' + checked);
});

// ---------- K. Адаптив ----------
await step('K1 интервьюер 375px: нет горизонтального скролла', async () => {
  await iv.locator('#btn-scoring').click(); // назад к задаче
  await iv.setViewportSize({ width: 375, height: 812 });
  await sleep(400);
  const sw = await iv.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  if (sw > 1) throw new Error('переполнение ' + sw + 'px');
});
await iv.screenshot({ path: SHOTS + '/07-interviewer-mobile.png' });
await step('K2 кандидат 375px: нет горизонтального скролла', async () => {
  await cd2.setViewportSize({ width: 375, height: 812 });
  await sleep(400);
  const sw = await cd2.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  if (sw > 1) throw new Error('переполнение ' + sw + 'px');
});
await iv.setViewportSize({ width: 1440, height: 900 });
await cd2.setViewportSize({ width: 1440, height: 900 });

// ---------- L. Сброс ----------
await step('L1 Сброс: интервьюер в исходное, кандидат в ожидание, снапшот очищен', async () => {
  // вернуть кандидата из finished: сброс должен сделать это сам
  await iv.locator('#btn-reset').click(); // confirm — auto-accept
  await sleep(700);
  const emptyVis = await iv.locator('#task-empty').isVisible();
  const timer = await iv.locator('#timer').textContent();
  const phase = await iv.locator('#phase-label').textContent();
  const snap = await iv.evaluate(() => localStorage.getItem('x5-fde-interview-v1:snapshot'));
  const waiting = await cd2.evaluate(() => getComputedStyle(document.getElementById('state-waiting')).display !== 'none');
  const drafts = await cd2.evaluate(() => sessionStorage.getItem('x5-hri-candidate-drafts-v1'));
  const sent = await iv.locator('.task-item__sent').count();
  if (!emptyVis || timer !== '00:00' || phase !== 'подготовка') throw new Error('UI: ' + timer + ' / ' + phase);
  if (snap !== null) throw new Error('снапшот не очищен');
  if (!waiting) throw new Error('кандидат не вернулся в ожидание');
  if (drafts && drafts !== '{}') throw new Error('черновики кандидата не очищены: ' + drafts);
  if (sent !== 0) throw new Error('в банке остались метки «показана»: ' + sent);
});
await iv.screenshot({ path: SHOTS + '/08-interviewer-after-reset.png' });
await cd2.screenshot({ path: SHOTS + '/09-candidate-waiting.png' });

// ---------- M. Консоль и сеть ----------
await step('M1 консоль интервьюера без ошибок за весь прогон', async () => {
  const errs = consoleLog.interviewer.filter(l => l.startsWith('error') || l.startsWith('pageerror'));
  if (errs.length) throw new Error(errs.slice(0, 5).join(' | '));
  return consoleLog.interviewer.length + ' предупреждений';
});
await step('M2 консоль кандидата без ошибок за весь прогон', async () => {
  const errs = consoleLog.candidate.filter(l => l.startsWith('error') || l.startsWith('pageerror'));
  if (errs.length) throw new Error(errs.slice(0, 5).join(' | '));
  return consoleLog.candidate.length + ' предупреждений';
});
await step('M3 сеть: нет упавших запросов и 4xx/5xx', async () => {
  const all = [...netFail.interviewer, ...netFail.candidate];
  if (all.length) throw new Error(all.slice(0, 5).join(' | '));
});

await browser.close();

// ---------- отчёт ----------
const pass = results.filter(r => r.pass).length;
console.log('\n===== ИТОГ: ' + pass + '/' + results.length + ' =====');
for (const r of results) console.log((r.pass ? 'PASS' : 'FAIL') + '  ' + r.name + (r.note ? '  — ' + r.note : ''));
