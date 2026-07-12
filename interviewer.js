/* interviewer.js — панель интервьюера, MVP платформы интервью FDE (этап 2).
 * Реализация US-01..US-04 (PRD §8). Держит состояние сессии; кандидат — проекция.
 * Контракт синка — sync.js (window.HRISync). Данные — tasks.json.
 */
(function () {
  'use strict';

  var T = HRISync.TYPES;
  var bus = HRISync.create({ source: 'interviewer' });

  // ---------- constants ----------
  var SEGMENTS = [
    { from: 0, to: 5, label: 'разогрев' },
    { from: 5, to: 18, label: 'фундамент' },
    { from: 18, to: 34, label: 'агентские системы' },
    { from: 34, to: 48, label: 'код или design' },
    { from: 48, to: 55, label: 'добор' },
    { from: 55, to: 60, label: 'вопросы' }
  ];
  var TOTAL_SEC = 60 * 60;

  var CRITERIA = [
    { key: 'cs', label: 'CS-фундамент', weight: 2, stop: true },
    { key: 'systemDesign', label: 'System design', weight: 2, stop: false },
    { key: 'agents', label: 'Проектирование агентов', weight: 3, stop: true },
    { key: 'production', label: 'Прод-зрелость', weight: 3, stop: true },
    { key: 'aiPractice', label: 'AI-augmented практика', weight: 2, stop: false }
  ];

  var CAT_LABEL = {
    algorithms: 'алгоритмы', 'python-swe': 'Python / SWE',
    debugging: 'отладка', 'system-design': 'system design',
    agents: 'агенты', 'ai-practice': 'AI-практика'
  };
  var DIM_LABEL = {
    cs: 'CS', 'system-design': 'System design', agents: 'Агенты',
    production: 'Прод', 'ai-practice': 'AI-практика'
  };
  var PHASE_LABEL = { setup: 'подготовка', running: 'интервью', scoring: 'оценка', done: 'завершено' };

  // ---------- state ----------
  var state = {
    phase: 'setup',
    currentTaskId: null,
    timer: { status: 'idle', accumulatedSec: 0, startedAt: null },
    sentTaskIds: [],
    scores: { cs: 0, systemDesign: 0, agents: 0, production: 0, aiPractice: 0 },
    frozen: false
  };
  var tasksById = {};
  var candidateConnected = false;
  var lastSegIdx = -1;
  var tick = null;

  // ---------- dom ----------
  var $ = function (id) { return document.getElementById(id); };
  var el = {
    conn: $('conn-badge'), timer: $('timer'), phase: $('phase-label'),
    btnTimer: $('btn-timer'), btnReset: $('btn-reset'), btnScoring: $('btn-scoring'),
    timebox: $('timebox'), segLive: $('seg-live'),
    filterCat: $('filter-cat'), filterDiff: $('filter-diff'), list: $('task-list'),
    viewTask: $('view-task'), viewScore: $('view-score'),
    taskEmpty: $('task-empty'), taskDetails: $('task-details'),
    mirrorPanel: $('mirror-panel'), mirror: $('candidate-mirror'),
    scoreBody: $('score-body'), verdictBadge: $('verdict-badge'), verdictAvg: $('verdict-avg'),
    btnFinish: $('btn-finish'), btnReopen: $('btn-reopen')
  };

  // ---------- helpers ----------
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function inlineMd(s) { return esc(s).replace(/`([^`]+)`/g, '<code>$1</code>'); }
  function mdLite(src) {
    var lines = String(src || '').split('\n'), html = '', list = null;
    function flush() { if (list) { html += '<ul>' + list.map(function (li) { return '<li>' + li + '</li>'; }).join('') + '</ul>'; list = null; } }
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].replace(/\s+$/, '');
      if (/^\s*[-•*]\s+/.test(line)) { if (!list) list = []; list.push(inlineMd(line.replace(/^\s*[-•*]\s+/, ''))); continue; }
      flush();
      if (line.trim() === '') continue;
      html += '<p>' + inlineMd(line) + '</p>';
    }
    flush();
    return html;
  }
  function pad(n) { return String(n).padStart(2, '0'); }
  function fmt(sec) {
    var total = Math.floor(sec);
    if (total < TOTAL_SEC) return pad(Math.floor(total / 60)) + ':' + pad(total % 60);
    var over = total - TOTAL_SEC;
    return '60:00 +' + pad(Math.floor(over / 60)) + ':' + pad(over % 60);
  }
  function elapsedSec() {
    var t = state.timer;
    return t.accumulatedSec + (t.status === 'running' && t.startedAt ? (Date.now() - t.startedAt) / 1000 : 0);
  }

  // ---------- sync out ----------
  function postSession() {
    bus.post(T.SESSION_STATE, { phase: state.phase, currentTaskId: state.currentTaskId, timer: state.timer });
  }
  function postTimer() { bus.post(T.TIMER_STATE, state.timer); }
  function saveSnapshot() {
    bus.saveSnapshot({
      phase: state.phase, currentTaskId: state.currentTaskId, timer: state.timer,
      sentTaskIds: state.sentTaskIds, scores: state.scores, frozen: state.frozen,
      updatedAt: Date.now()
    });
  }
  function persist() { saveSnapshot(); postSession(); }

  // ---------- timer ----------
  function startTick() { if (!tick) tick = setInterval(renderTimer, 1000); }
  function stopTick() { if (tick) { clearInterval(tick); tick = null; } }

  function startTimer() {
    if (state.phase === 'setup') state.phase = 'running';
    state.timer = { status: 'running', accumulatedSec: state.timer.accumulatedSec, startedAt: Date.now() };
    startTick(); renderTimer(); renderPhase(); postTimer(); persist();
  }
  function pauseTimer() {
    if (state.timer.status !== 'running') return;
    state.timer.accumulatedSec = elapsedSec();
    state.timer.status = 'paused'; state.timer.startedAt = null;
    stopTick(); renderTimer(); postTimer(); saveSnapshot();
  }
  function resumeTimer() {
    if (state.timer.status !== 'paused') return;
    state.timer.status = 'running'; state.timer.startedAt = Date.now();
    startTick(); renderTimer(); postTimer(); saveSnapshot();
  }
  function onTimerButton() {
    if (state.timer.status === 'running') pauseTimer();
    else if (state.timer.status === 'paused') resumeTimer();
    else startTimer();
  }

  function renderTimer() {
    var sec = elapsedSec();
    el.timer.textContent = fmt(sec);
    el.timer.classList.toggle('timer--overtime', sec >= TOTAL_SEC);
    // button label
    el.btnTimer.textContent = state.timer.status === 'running' ? 'Пауза'
      : state.timer.status === 'paused' ? 'Продолжить' : 'Старт';
    renderSegments(sec);
  }
  function renderSegments(sec) {
    var minutes = sec / 60;
    var active = SEGMENTS.length - 1;
    for (var i = 0; i < SEGMENTS.length; i++) {
      if (minutes < SEGMENTS[i].to) { active = i; break; }
    }
    if (sec < 0.5 && state.timer.status === 'idle') active = -1; // setup: ничего не подсвечено
    var nodes = el.timebox.children;
    for (var j = 0; j < nodes.length; j++) {
      var seg = nodes[j];
      seg.removeAttribute('aria-current');
      seg.setAttribute('data-state', j < active ? 'past' : 'upcoming');
      if (j === active) seg.setAttribute('aria-current', 'step');
    }
    if (active !== lastSegIdx && active >= 0) {
      lastSegIdx = active;
      el.segLive.textContent = 'сегмент — ' + SEGMENTS[active].label;
    }
  }
  function buildTimebox() {
    el.timebox.innerHTML = SEGMENTS.map(function (s) {
      var span = s.to - s.from;
      return '<li class="timebox__seg" style="flex-grow:' + span + '" data-state="upcoming">' +
        '<div class="timebox__range">' + s.from + '–' + s.to + '</div>' +
        '<div class="timebox__label">' + esc(s.label) + '</div></li>';
    }).join('');
  }
  function renderPhase() { el.phase.textContent = PHASE_LABEL[state.phase] || state.phase; }

  // ---------- connection ----------
  function setConnected(on) {
    if (candidateConnected === on) return;
    candidateConnected = on;
    el.conn.textContent = on ? 'кандидат подключён' : 'кандидат не подключён';
    el.conn.classList.toggle('badge--on', on);
  }

  // ---------- bank ----------
  function buildFilters(tasks) {
    var cats = {}, diffs = {};
    tasks.forEach(function (t) { cats[t.category] = 1; diffs[t.difficulty] = 1; });
    el.filterCat.innerHTML = '<option value="">все категории</option>' +
      Object.keys(cats).map(function (c) { return '<option value="' + esc(c) + '">' + esc(CAT_LABEL[c] || c) + '</option>'; }).join('');
    el.filterDiff.innerHTML = '<option value="">все сложности</option>' +
      Object.keys(diffs).map(function (d) { return '<option value="' + esc(d) + '">' + esc(d) + '</option>'; }).join('');
    el.filterCat.onchange = renderBank;
    el.filterDiff.onchange = renderBank;
  }
  function renderBank() {
    var cat = el.filterCat.value, diff = el.filterDiff.value;
    var tasks = Object.keys(tasksById).map(function (k) { return tasksById[k]; })
      .filter(function (t) { return (!cat || t.category === cat) && (!diff || t.difficulty === diff); });
    el.list.innerHTML = tasks.map(function (t) {
      var sent = state.sentTaskIds.indexOf(t.id) >= 0;
      var selected = t.id === state.currentTaskId;
      return '<li class="task-item" role="button" tabindex="0" data-id="' + esc(t.id) + '" aria-selected="' + selected + '">' +
        '<div class="task-item__top">' +
          '<span class="task-item__id">' + esc(t.id) + '</span>' +
          (t.mlSpecific ? '<span class="badge badge--ml">ML</span>' : '') +
          (sent ? '<span class="task-item__sent">✓ показана</span>' : '') +
        '</div>' +
        '<div class="task-item__title">' + esc(t.title) + '</div>' +
        '<div class="task-item__meta">' +
          '<span class="chip">' + esc(CAT_LABEL[t.category] || t.category) + '</span>' +
          '<span class="chip">' + esc(t.difficulty) + '</span>' +
          '<span class="chip">' + esc(DIM_LABEL[t.scoringDimension] || t.scoringDimension) + ' ×' + t.weight + '</span>' +
          '<span class="chip">' + t.timeBudgetMin + ' мин</span>' +
        '</div></li>';
    }).join('');
    Array.prototype.forEach.call(el.list.querySelectorAll('.task-item'), function (node) {
      node.addEventListener('click', function () { selectTask(node.getAttribute('data-id')); });
      node.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); selectTask(node.getAttribute('data-id')); }
      });
    });
  }

  // ---------- task details ----------
  function selectTask(id) {
    var task = tasksById[id];
    if (!task) return;
    state.currentTaskId = id;
    if (state.sentTaskIds.indexOf(id) < 0) state.sentTaskIds.push(id);
    if (state.phase === 'scoring' || state.phase === 'done') { state.phase = 'running'; }
    showTaskView();
    renderDetails(task);
    renderBank();
    el.mirror.textContent = '';
    bus.post(T.SELECT_TASK, { taskId: id });
    renderPhase(); persist();
  }
  function renderDetails(t) {
    el.taskEmpty.hidden = true;
    el.taskDetails.hidden = false;
    el.mirrorPanel.hidden = false;

    var html = '';
    html += '<div class="meta-row">' +
      '<span class="task-item__id">' + esc(t.id) + '</span>' +
      '<span class="chip">' + esc(CAT_LABEL[t.category] || t.category) + '</span>' +
      '<span class="chip">' + esc(t.difficulty) + '</span>' +
      '<span class="chip">' + esc(DIM_LABEL[t.scoringDimension] || t.scoringDimension) + ' ×' + t.weight + '</span>' +
      '<span class="chip">' + t.timeBudgetMin + ' мин</span>' +
      (t.mlSpecific ? '<span class="badge badge--ml">ML-специфична</span>' : '') +
    '</div>';
    html += '<h2 class="stage__title">' + esc(t.title) + '</h2>';
    html += '<div class="prompt">' + mdLite(t.prompt) + '</div>';

    if (t.examples && t.examples.length) {
      html += '<div class="section-h">Примеры</div><table class="examples"><thead><tr><th>Вход</th><th>Выход</th><th>Пояснение</th></tr></thead><tbody>';
      t.examples.forEach(function (ex) {
        html += '<tr><td><code>' + esc(ex.input) + '</code></td><td><code>' + esc(ex.output) + '</code></td><td>' + esc(ex.explanation || '') + '</td></tr>';
      });
      html += '</tbody></table>';
    }

    var code = t.buggyVersion != null ? t.buggyVersion : t.starterCode;
    if (code) {
      html += '<div class="section-h">' + (t.buggyVersion != null ? 'Код в редакторе кандидата (с дефектом)' : 'Стартовый код') + '</div>';
      html += '<pre class="code"><code>' + esc(code) + '</code></pre>';
    }

    if (t.referenceSolutions && t.referenceSolutions.length) {
      html += '<div class="section-h">Эталонные решения — только для интервьюера</div>';
      t.referenceSolutions.forEach(function (r) {
        html += '<div class="ref"><div class="ref__h">' + esc(r.label) + (r.complexity ? ' · <span class="muted">' + esc(r.complexity) + '</span>' : '') + '</div>';
        if (r.code) html += '<pre class="code"><code>' + esc(r.code) + '</code></pre>';
        if (r.notes) html += '<p class="muted">' + esc(r.notes) + '</p>';
        html += '</div>';
      });
    }

    if ((t.greenSignals && t.greenSignals.length) || (t.redSignals && t.redSignals.length)) {
      html += '<div class="section-h">Сигналы</div><div class="signals">';
      html += '<div><div class="muted">Берём</div><ul>' +
        (t.greenSignals || []).map(function (s) { return '<li class="sig-green"><span class="sr-only">берём: </span>' + esc(s) + '</li>'; }).join('') + '</ul></div>';
      html += '<div><div class="muted">Стоп</div><ul>' +
        (t.redSignals || []).map(function (s) { return '<li class="sig-red"><span class="sr-only">стоп: </span>' + esc(s) + '</li>'; }).join('') + '</ul></div>';
      html += '</div>';
    }

    if (t.followUps && t.followUps.length) {
      html += '<div class="section-h">Follow-up вопросы</div><ul>' +
        t.followUps.map(function (f) { return '<li>' + inlineMd(f) + '</li>'; }).join('') + '</ul>';
    }
    if (t.evaluationNotes) {
      html += '<div class="section-h">Заметки по оценке</div><div class="prompt">' + mdLite(t.evaluationNotes) + '</div>';
    }
    el.taskDetails.innerHTML = html;
  }

  // ---------- scoring ----------
  function buildScoreTable() {
    el.scoreBody.innerHTML = CRITERIA.map(function (c) {
      var scale = [1, 2, 3, 4].map(function (v) {
        return '<label><input type="radio" name="score-' + c.key + '" value="' + v + '"><span>' + v + '</span></label>';
      }).join('');
      return '<tr><td>' + esc(c.label) + (c.stop ? ' <span class="muted">(стоп-строка)</span>' : '') + '</td>' +
        '<td>×' + c.weight + '</td>' +
        '<td><div class="scale" role="radiogroup" aria-label="' + esc(c.label) + '">' + scale + '</div></td></tr>';
    }).join('');
    el.scoreBody.addEventListener('change', function (e) {
      if (e.target && e.target.name && e.target.name.indexOf('score-') === 0) {
        var key = e.target.name.slice(6);
        state.scores[key] = parseInt(e.target.value, 10);
        renderVerdict(); saveSnapshot();
      }
    });
  }
  function restoreScoreInputs() {
    CRITERIA.forEach(function (c) {
      var v = state.scores[c.key];
      if (v) {
        var input = el.scoreBody.querySelector('input[name="score-' + c.key + '"][value="' + v + '"]');
        if (input) input.checked = true;
      }
    });
  }
  function computeVerdict() {
    var scored = CRITERIA.filter(function (c) { return state.scores[c.key]; });
    var all = scored.length === CRITERIA.length;
    var wsum = 0, wtot = 0;
    scored.forEach(function (c) { wsum += state.scores[c.key] * c.weight; wtot += c.weight; });
    var avg = wtot ? wsum / wtot : 0;
    var stopOne = CRITERIA.some(function (c) { return c.stop && state.scores[c.key] === 1; });
    return { avg: avg, all: all, go: all && avg >= 3.0 && !stopOne, stopOne: stopOne };
  }
  function renderVerdict() {
    var v = computeVerdict();
    el.verdictAvg.textContent = v.all ? ('средневзвешенное ' + v.avg.toFixed(2)) : '';
    if (!v.all) {
      el.verdictBadge.textContent = 'оцените все критерии';
      el.verdictBadge.setAttribute('data-v', '');
      el.btnFinish.disabled = true;
      return;
    }
    el.verdictBadge.textContent = v.go ? 'GO' : 'NO-GO';
    el.verdictBadge.setAttribute('data-v', v.go ? 'GO' : 'NO-GO');
    el.btnFinish.disabled = state.frozen;
  }

  function openScoring() {
    if (state.timer.status === 'running') pauseTimer();
    state.phase = 'scoring';
    el.viewTask.hidden = true; el.viewScore.hidden = false;
    el.btnScoring.textContent = 'К задаче';
    renderPhase(); persist();
  }
  function backToSession() {
    state.phase = 'running';
    showTaskView();
    renderPhase(); persist();
  }
  function showTaskView() {
    el.viewScore.hidden = true; el.viewTask.hidden = false;
    el.btnScoring.textContent = 'Оценка';
  }
  function onScoringToggle() {
    if (el.viewScore.hidden) openScoring(); else backToSession();
  }
  function finishScoring() {
    var v = computeVerdict();
    if (!v.all) return;
    state.phase = 'done'; state.frozen = true;
    setInputsDisabled(true);
    el.btnFinish.disabled = true; el.btnReopen.hidden = false;
    renderPhase(); persist();
  }
  function reopenScoring() {
    state.frozen = false; state.phase = 'scoring';
    setInputsDisabled(false);
    el.btnReopen.hidden = true;
    renderVerdict(); renderPhase(); persist();
  }
  function setInputsDisabled(dis) {
    Array.prototype.forEach.call(el.scoreBody.querySelectorAll('input'), function (i) { i.disabled = dis; });
  }

  // ---------- reset ----------
  function resetSession() {
    if (!window.confirm('Сбросить сессию — таймер, задачи и черновик оценки будут очищены.')) return;
    stopTick();
    state = {
      phase: 'setup', currentTaskId: null,
      timer: { status: 'idle', accumulatedSec: 0, startedAt: null },
      sentTaskIds: [], scores: { cs: 0, systemDesign: 0, agents: 0, production: 0, aiPractice: 0 }, frozen: false
    };
    lastSegIdx = -1;
    bus.clearSnapshot();
    bus.post(T.RESET, {});
    // reset UI
    el.taskDetails.hidden = true; el.mirrorPanel.hidden = true; el.taskEmpty.hidden = false;
    el.mirror.textContent = '';
    buildScoreTable(); showTaskView();
    setInputsDisabled(false); el.btnReopen.hidden = true;
    renderTimer(); renderPhase(); renderVerdict(); renderBank();
    postSession();
  }

  // ---------- restore ----------
  function restore() {
    var snap = bus.loadSnapshot();
    if (!snap) return false;
    state.phase = snap.phase || 'setup';
    state.currentTaskId = snap.currentTaskId || null;
    state.timer = snap.timer || state.timer;
    state.sentTaskIds = snap.sentTaskIds || [];
    state.scores = snap.scores || state.scores;
    state.frozen = !!snap.frozen;
    return true;
  }

  // ---------- sync in ----------
  bus.onAny(function (env) { if (env.source === 'candidate') setConnected(true); });
  bus.on(T.SYNC_REQUEST, function () { postSession(); });
  bus.on(T.CANDIDATE_CODE_UPDATE, function (p) {
    if (!p) return;
    if (p.taskId && state.currentTaskId && p.taskId !== state.currentTaskId) {
      el.mirror.textContent = '— кандидат на задаче ' + p.taskId + ' —\n\n' + (p.code || '');
    } else {
      el.mirror.textContent = p.code || '';
    }
  });

  // ---------- wire ----------
  el.btnTimer.addEventListener('click', onTimerButton);
  el.btnReset.addEventListener('click', resetSession);
  el.btnScoring.addEventListener('click', onScoringToggle);
  el.btnFinish.addEventListener('click', finishScoring);
  el.btnReopen.addEventListener('click', reopenScoring);

  // ---------- boot ----------
  function boot(tasks) {
    tasks.forEach(function (t) { tasksById[t.id] = t; });
    buildFilters(tasks);
    buildTimebox();
    buildScoreTable();
    var restored = restore();
    renderBank();
    if (restored) {
      restoreScoreInputs();
      if (state.frozen) { setInputsDisabled(true); el.btnReopen.hidden = false; }
      if (state.currentTaskId && tasksById[state.currentTaskId] && state.phase !== 'scoring') {
        renderDetails(tasksById[state.currentTaskId]);
      }
      if (state.phase === 'scoring') { el.viewTask.hidden = true; el.viewScore.hidden = false; el.btnScoring.textContent = 'К задаче'; }
      if (state.timer.status === 'running') startTick();
    }
    renderTimer(); renderPhase(); renderVerdict();
    // announce ourselves + request candidate state
    postSession();
    bus.post(T.SYNC_REQUEST, {});
  }

  function showLoadError() {
    el.taskEmpty.innerHTML = '<div class="notice">Не удалось загрузить <code>tasks.json</code>. ' +
      'Откройте платформу по http, а не как файл: в папке проекта запустите ' +
      '<code>python3 -m http.server 8000</code> и зайдите на <code>http://localhost:8000/interviewer.html</code>.</div>';
  }

  fetch('tasks.json')
    .then(function (r) { if (!r.ok) throw new Error('http ' + r.status); return r.json(); })
    .then(function (data) { boot(data.tasks || []); })
    .catch(function (err) { console.error('tasks.json load failed:', err); showLoadError(); });
})();
