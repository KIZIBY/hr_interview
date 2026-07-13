/* Смоук-тест guide.html — интервьюерский гайд HRI.
 * Запускается оркестратором после сборки guide.html при живом http-сервере на :8000.
 * НЕ запускать вручную до появления страницы. */
import { createRequire } from 'module';
import fs from 'fs';

const req = createRequire('/Users/nikolaykoreshkov/.nvm/versions/node/v22.22.2/lib/node_modules/@playwright/cli/node_modules/x');
const { chromium } = req('playwright');

const BASE = 'http://localhost:8000/platform';
const TASKS_PATH = '/Users/nikolaykoreshkov/Documents/Claude/Projects/hr_interview/platform/tasks.json';

const tasksData = JSON.parse(fs.readFileSync(TASKS_PATH, 'utf8')).tasks;

const results = [];
async function step(name, fn) {
  try {
    const note = await fn();
    results.push({ name, pass: true, note: note || '' });
  } catch (e) {
    results.push({ name, pass: false, note: String(e && e.message || e).slice(0, 500) });
  }
}

// Накопители ошибок за весь прогон (проверяются в шаге GS-01 в конце)
const consoleErrors = [];
const netFails = [];

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
const page = await ctx.newPage();

page.on('console', m => {
  if (m.type() === 'error') consoleErrors.push('console.error: ' + m.text());
});
page.on('pageerror', e => consoleErrors.push('pageerror: ' + e.message));
page.on('requestfailed', r => netFails.push(r.url() + ' -> ' + (r.failure() && r.failure().errorText)));
page.on('response', r => {
  if (r.status() >= 400) netFails.push(r.url() + ' -> HTTP ' + r.status());
});

// ---------- GS-02: загрузка и рендер карточек (таймер) ----------
// Делаем goto с замером времени — раньше остальных шагов, чтобы консольные события успели накопиться.
let gotoStart, renderMs;
await step('GS-02 количество .task-card совпадает с tasks.json', async () => {
  gotoStart = Date.now();
  await page.goto(BASE + '/guide.html', { waitUntil: 'domcontentloaded' });

  // Ждём снятия aria-busy с памятки (шаг GS-02 включает ожидание рендера)
  await page.waitForSelector('#tasks-ref:not([aria-busy="true"])', { timeout: 2000 });
  renderMs = Date.now() - gotoStart;

  const count = await page.locator('.task-card').count();
  if (count !== tasksData.length)
    throw new Error('карточек ' + count + ', ожидалось ' + tasksData.length + ' (по tasks.json)');
  return count + ' карточек; рендер ' + renderMs + ' мс (NFR бюджет ≤200 мс, FAIL только > 2000)';
});

// ---------- GS-04: время рендера (NFR, FAIL только > 2000) ----------
await step('GS-04 время рендера ≤ 2000 мс (NFR ≤200 мс — только лог)', async () => {
  if (renderMs === undefined) throw new Error('goto не выполнен — GS-02 упал раньше');
  if (renderMs > 2000) throw new Error('рендер ' + renderMs + ' мс > 2000 мс (жёсткий лимит)');
  const nfr = renderMs <= 200 ? 'в рамках NFR' : 'ПРЕВЫШЕН NFR-бюджет 200 мс (не FAIL)';
  return renderMs + ' мс — ' + nfr;
});

// ---------- GS-03: id каждой карточки совпадает с tasks.json ----------
await step('GS-03 каждая карточка имеет id="task-{id}" по tasks.json', async () => {
  const missing = [];
  for (const t of tasksData) {
    const exists = await page.locator('#task-' + t.id).count();
    if (exists === 0) missing.push(t.id);
  }
  if (missing.length) throw new Error('нет карточек: ' + missing.join(', '));
  return tasksData.length + ' id проверено';
});

// ---------- GS-05: нет эмодзи 🟢/🔴 в body ----------
await step('GS-05 нет эмодзи 🟢/🔴 в document.body.innerHTML', async () => {
  const found = await page.evaluate(() => {
    const html = document.body.innerHTML;
    const hits = [];
    if (html.includes('🟢')) hits.push('🟢');
    if (html.includes('🔴')) hits.push('🔴');
    return hits;
  });
  if (found.length) throw new Error('найдены эмодзи: ' + found.join(' '));
  return 'эмодзи отсутствуют';
});

// ---------- GS-06: нет горизонтального скролла на трёх вьюпортах ----------
const viewports = [
  { width: 1440, height: 900 },
  { width: 1024, height: 768 },
  { width: 768, height: 1024 },
];
for (const vp of viewports) {
  await step('GS-06 нет горизонтального скролла ' + vp.width + 'x' + vp.height, async () => {
    await page.setViewportSize(vp);
    // небольшая пауза для перерасчёта layout
    await page.evaluate(() => new Promise(r => requestAnimationFrame(r)));
    const overflow = await page.evaluate(() =>
      document.documentElement.scrollWidth - document.documentElement.clientWidth
    );
    if (overflow > 1) throw new Error('горизонтальное переполнение ' + overflow + 'px');
    return 'scrollWidth - clientWidth = ' + overflow + 'px';
  });
}
// Вернуть вьюпорт к 1440x900 для остальных шагов
await page.setViewportSize({ width: 1440, height: 900 });

// ---------- GS-07: якорь #task-ALG-01 — карточка видима, не перекрыта шапкой ----------
await step('GS-07 якорь guide.html#task-ALG-01 — карточка в зоне видимости', async () => {
  await page.goto(BASE + '/guide.html#task-ALG-01', { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#task-ALG-01', { timeout: 2000 });

  const top = await page.evaluate(() => {
    const el = document.getElementById('task-ALG-01');
    if (!el) return null;
    return el.getBoundingClientRect().top;
  });
  if (top === null) throw new Error('карточка #task-ALG-01 не найдена');
  if (top < 0) throw new Error('верх карточки перекрыт sticky-шапкой: top=' + top + 'px');
  return 'getBoundingClientRect().top = ' + Math.round(top) + 'px (≥ 0)';
});

// ---------- GS-08: XSS-guard — нет живых <script> в карточках ----------
await step('GS-08 XSS-guard: нет живых <script> в .task-card, нет литерального <script в pre', async () => {
  await page.goto(BASE + '/guide.html', { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#tasks-ref:not([aria-busy="true"])', { timeout: 2000 });

  const result = await page.evaluate(() => {
    // Проверяем живые <script> внутри карточек
    const liveScripts = document.querySelectorAll('.task-card script');
    if (liveScripts.length > 0) return { ok: false, reason: 'найдены живые <script>: ' + liveScripts.length };

    // Проверяем, что innerHTML первой pre-карточки не содержит литеральный тег
    const pre = document.querySelector('.task-card pre');
    if (pre) {
      if (pre.innerHTML.includes('<script')) {
        return { ok: false, reason: 'в .task-card pre найден литеральный <script (не экранирован)' };
      }
    }
    return { ok: true };
  });

  if (!result.ok) throw new Error(result.reason);
  return 'живых <script> нет, pre экранирован';
});

// ---------- GS-09: шрифт X5 Sans и цвет body ----------
await step('GS-09 шрифт X5 Sans загружен, цвет body = rgb(48, 49, 69)', async () => {
  const fontOk = await page.evaluate(async () => {
    await document.fonts.ready;
    return document.fonts.check('16px "X5 Sans"') && document.fonts.check('500 16px "X5 Sans"');
  });
  if (!fontOk) throw new Error('document.fonts.check("X5 Sans") вернул false');

  const color = await page.evaluate(() => getComputedStyle(document.body).color);
  if (color !== 'rgb(48, 49, 69)') throw new Error('цвет body: ' + color + ', ожидался rgb(48, 49, 69)');
  return 'X5 Sans загружен, color = ' + color;
});

// ---------- GS-10: баннер .guard-banner — первый секционный элемент ----------
await step('GS-10 .guard-banner существует и имеет минимальный offsetTop среди секций', async () => {
  const result = await page.evaluate(() => {
    const banner = document.querySelector('.guard-banner');
    if (!banner) return { ok: false, reason: '.guard-banner не найден' };

    const bannerTop = banner.offsetTop;

    // Секционные элементы — section, article, header, aside, div с id из контракта
    const sectionIds = ['flow', 'zones', 'tasks-ref', 'scoring'];
    let minSectionTop = Infinity;
    for (const id of sectionIds) {
      const el = document.getElementById(id);
      if (el) minSectionTop = Math.min(minSectionTop, el.offsetTop);
    }

    // Баннер должен быть выше или на том же уровне, что первая секция
    if (bannerTop > minSectionTop) {
      return {
        ok: false,
        reason: '.guard-banner offsetTop=' + bannerTop + ' > первая секция offsetTop=' + minSectionTop
      };
    }
    return { ok: true, bannerTop, minSectionTop };
  });

  if (!result.ok) throw new Error(result.reason);
  return '.guard-banner offsetTop=' + result.bannerTop + ', первая секция offsetTop=' + result.minSectionTop;
});

// ---------- GS-11: интеграция пульта (interviewer.html) ----------
const ivPage = await ctx.newPage();
ivPage.on('console', m => {
  if (m.type() === 'error') consoleErrors.push('[interviewer] console.error: ' + m.text());
});
ivPage.on('pageerror', e => consoleErrors.push('[interviewer] pageerror: ' + e.message));
ivPage.on('requestfailed', r => netFails.push('[iv] ' + r.url() + ' -> ' + (r.failure() && r.failure().errorText)));
ivPage.on('response', r => {
  if (r.status() >= 400) netFails.push('[iv] ' + r.url() + ' -> HTTP ' + r.status());
});
ivPage.on('dialog', d => d.accept());

await step('GS-11a interviewer.html имеет ссылку a[href="guide.html"] в шапке', async () => {
  await ivPage.goto(BASE + '/interviewer.html', { waitUntil: 'networkidle' });
  const link = await ivPage.locator('header a[href="guide.html"], nav a[href="guide.html"]').count();
  if (link === 0) throw new Error('ссылка a[href="guide.html"] не найдена в header/nav');
  return 'ссылка найдена';
});

await step('GS-11b выбор ALG-01 в пульте → появляется a[href="guide.html#task-ALG-01"] в деталях', async () => {
  await ivPage.locator('.task-item[data-id="ALG-01"]').click();
  await ivPage.waitForSelector('#task-details:not([hidden])', { timeout: 3000 });

  const deepLink = await ivPage.locator('a[href="guide.html#task-ALG-01"]').count();
  if (deepLink === 0) throw new Error('ссылка a[href="guide.html#task-ALG-01"] не найдена в #task-details');

  // Очищаем localStorage, чтобы не мешать другим тестам
  await ivPage.evaluate(() => localStorage.clear());
  return 'ссылка-якорь найдена, localStorage очищен';
});

await ivPage.close();

// ---------- GS-12: Print-CSS — наличие @media print ----------
await step('GS-12 @media print существует в styleSheets страницы', async () => {
  const found = await page.evaluate(() => {
    for (const sheet of Array.from(document.styleSheets)) {
      try {
        const rules = Array.from(sheet.cssRules || []);
        for (const rule of rules) {
          if (rule.type === CSSRule.MEDIA_RULE && rule.conditionText &&
              rule.conditionText.includes('print')) {
            return true;
          }
        }
      } catch (e) {
        // SecurityError при cross-origin stylesheet — пропускаем
        if (!(e instanceof DOMException)) throw e;
      }
    }
    return false;
  });
  if (!found) throw new Error('@media print не найден ни в одном доступном stylesheet');
  return '@media print найден';
});

// ---------- GS-01: консоль и сеть (последний шаг — накопленные за весь прогон) ----------
await step('GS-01 нет console.error / pageerror / 4xx-5xx за весь прогон', async () => {
  const allErrors = [...consoleErrors];
  const allNetFails = [...netFails];
  const issues = [...allErrors, ...allNetFails];
  if (issues.length) throw new Error(issues.slice(0, 6).join(' | '));
  return 'ошибок нет';
});

await browser.close();

// ---------- итог ----------
const pass = results.filter(r => r.pass).length;
console.log('\n===== GUIDE-SMOKE ИТОГ: ' + pass + '/' + results.length + ' =====');
for (const r of results) {
  console.log((r.pass ? 'PASS' : 'FAIL') + '  ' + r.name + (r.note ? '  — ' + r.note : ''));
}
