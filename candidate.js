/* candidate.js — экран кандидата, FDE-интервью, X5 Tech
 * Контракт: PRD §5 (candidate-visible поля), §6 (sync), §7 (state machine), US-05.
 * Классический скрипт (no ES-modules). Зависимость: sync.js → window.HRISync.
 */
'use strict';

(function () {

  /* ============================================================
     file:// guard — синк не работает без http
     ============================================================ */
  if (location.protocol === 'file:') {
    const notice = document.getElementById('file-notice');
    if (notice) notice.style.display = 'flex';
    return;
  }

  /* ============================================================
     Sync bus
     ============================================================ */
  const bus = HRISync.create({ source: 'candidate' });
  const T   = HRISync.TYPES;

  /* ============================================================
     Constants
     ============================================================ */
  const MAX_CODE_LEN = 50000;
  const DRAFTS_KEY   = 'x5-hri-candidate-drafts-v1';

  /* ============================================================
     Candidate-visible field allowlist
     NEVER read: referenceSolutions, followUps, greenSignals,
                 redSignals, evaluationNotes, weight, scoringDimension
     ============================================================ */
  const CANDIDATE_FIELDS = [
    'id', 'title', 'format', 'prompt',
    'examples', 'starterCode', 'buggyVersion', 'language'
  ];

  function toCandidateTask(raw) {
    const t = {};
    CANDIDATE_FIELDS.forEach(function (f) {
      if (Object.prototype.hasOwnProperty.call(raw, f)) {
        t[f] = raw[f];
      }
    });
    return t;
  }

  /* ============================================================
     App state
     ============================================================ */
  const st = {
    phase:         'setup',
    task:          null,   // CandidateVisibleTask | null
    tasksMap:      null,   // id -> CandidateVisibleTask, populated after fetch
    pendingTaskId: null,   // taskId received before tasks loaded
    syncPaused:    false,
    tabEscArmed:   false,
    drafts:        loadDrafts(),
  };

  /* ============================================================
     DOM references
     ============================================================ */
  const el = {
    stateWaiting:  document.getElementById('state-waiting'),
    stateLoading:  document.getElementById('state-loading'),
    stateContent:  document.getElementById('state-content'),
    stateFinished: document.getElementById('state-finished'),
    stateError:    document.getElementById('state-error'),
    taskTitle:     document.getElementById('task-title'),
    taskPrompt:    document.getElementById('task-prompt'),
    taskExamples:  document.getElementById('task-examples'),
    editorSection: document.getElementById('editor-section'),
    codeEditor:    document.getElementById('code-editor'),
    editorLang:    document.getElementById('editor-language'),
    syncWarning:   document.getElementById('sync-warning'),
    announce:      document.getElementById('announce'),
    retryBtn:      document.getElementById('retry-btn'),
  };

  /* ============================================================
     Session storage — drafts per taskId
     ============================================================ */
  function loadDrafts() {
    try {
      const raw = sessionStorage.getItem(DRAFTS_KEY);
      return raw ? JSON.parse(raw) : {};
    } catch (_) { return {}; }
  }

  function saveDrafts() {
    try { sessionStorage.setItem(DRAFTS_KEY, JSON.stringify(st.drafts)); } catch (_) {}
  }

  /* ============================================================
     Announce (aria-live)
     ============================================================ */
  function announce(msg) {
    if (!el.announce) return;
    el.announce.textContent = '';
    setTimeout(function () { el.announce.textContent = msg; }, 50);
  }

  /* ============================================================
     Show state
     JS sets inline display — overrides .state-section { display:none }
     ============================================================ */
  const STATE_DISPLAY = {
    waiting:  'flex',
    loading:  'flex',
    content:  'grid',
    finished: 'flex',
    error:    'flex',
  };

  function showState(name) {
    Object.keys(STATE_DISPLAY).forEach(function (n) {
      const section = document.getElementById('state-' + n);
      if (section) section.style.display = (n === name) ? STATE_DISPLAY[n] : 'none';
    });
  }

  /* ============================================================
     Simple Markdown renderer
     Supported: paragraphs, unordered lists, ordered lists,
                `inline code`, fenced code blocks.
     No arbitrary HTML — all user content is escaped.
     ============================================================ */
  function escHtml(s) {
    if (typeof s !== 'string') return '';
    return s
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function inlineFmt(s) {
    return escHtml(s).replace(/`([^`\n]+)`/g, '<code>$1</code>');
  }

  function renderMarkdown(md) {
    if (!md) return '';
    const lines = md.split('\n');
    let html = '';
    let i = 0;

    while (i < lines.length) {
      const line = lines[i];

      // Fenced code block
      if (/^```/.test(line)) {
        const codeLines = [];
        i++;
        while (i < lines.length && !/^```/.test(lines[i])) {
          codeLines.push(lines[i]);
          i++;
        }
        i++; // skip closing ```
        html += '<pre><code>' + escHtml(codeLines.join('\n')) + '</code></pre>\n';
        continue;
      }

      // Unordered list
      if (/^[-*]\s+/.test(line)) {
        html += '<ul>\n';
        while (i < lines.length && /^[-*]\s+/.test(lines[i])) {
          const item = lines[i].replace(/^[-*]\s+/, '');
          html += '<li>' + inlineFmt(item) + '</li>\n';
          i++;
        }
        html += '</ul>\n';
        continue;
      }

      // Ordered list
      if (/^\d+\.\s+/.test(line)) {
        html += '<ol>\n';
        while (i < lines.length && /^\d+\.\s+/.test(lines[i])) {
          const item = lines[i].replace(/^\d+\.\s+/, '');
          html += '<li>' + inlineFmt(item) + '</li>\n';
          i++;
        }
        html += '</ol>\n';
        continue;
      }

      // Empty line
      if (line.trim() === '') {
        i++;
        continue;
      }

      // Paragraph: collect consecutive non-special lines
      const paraLines = [];
      while (
        i < lines.length &&
        lines[i].trim() !== '' &&
        !/^[-*]\s+/.test(lines[i]) &&
        !/^\d+\.\s+/.test(lines[i]) &&
        !/^```/.test(lines[i])
      ) {
        paraLines.push(lines[i]);
        i++;
      }
      if (paraLines.length) {
        html += '<p>' + inlineFmt(paraLines.join(' ')) + '</p>\n';
      }
    }

    return html;
  }

  /* ============================================================
     Examples renderer
     ============================================================ */
  function renderExamples(examples) {
    if (!examples || examples.length === 0) return '';
    return examples.map(function (ex, idx) {
      const inputStr  = ex.input  != null ? String(ex.input)  : '';
      const outputStr = ex.output != null ? String(ex.output) : '';
      let html = '<div class="example-block">'
        + '<div class="example-header">Пример ' + (idx + 1) + '</div>'
        + '<div class="example-row">'
        +   '<span class="example-label">Вход:</span>'
        +   '<code class="example-value">' + escHtml(inputStr) + '</code>'
        + '</div>'
        + '<div class="example-row">'
        +   '<span class="example-label">Выход:</span>'
        +   '<code class="example-value">' + escHtml(outputStr) + '</code>'
        + '</div>';
      if (ex.explanation) {
        html += '<div class="example-explanation">' + escHtml(String(ex.explanation)) + '</div>';
      }
      html += '</div>';
      return html;
    }).join('');
  }

  /* ============================================================
     Debounce
     ============================================================ */
  function debounce(fn, ms) {
    let timer = null;
    return function () {
      const args = arguments;
      const ctx  = this;
      clearTimeout(timer);
      timer = setTimeout(function () { fn.apply(ctx, args); }, ms);
    };
  }

  /* ============================================================
     Post code update — debounced, ≤1 per 300ms
     ============================================================ */
  const postCodeUpdate = debounce(function () {
    if (!st.task) return;
    const code = el.codeEditor.value;
    if (code.length > MAX_CODE_LEN) {
      st.syncPaused = true;
      el.syncWarning.hidden = false;
      return;
    }
    if (st.syncPaused) {
      st.syncPaused = false;
      el.syncWarning.hidden = true;
    }
    bus.post(T.CANDIDATE_CODE_UPDATE, { taskId: st.task.id, code: code });
  }, 300);

  /* ============================================================
     Editor: input handler
     ============================================================ */
  el.codeEditor.addEventListener('input', function () {
    postCodeUpdate();
  });

  /* ============================================================
     Editor: Tab — insert 4 spaces; Escape arms focus-out escape hatch
     AC-6: Escape → Tab moves focus out of editor
     ============================================================ */
  el.codeEditor.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      st.tabEscArmed = true;
      return;
    }
    if (e.key !== 'Tab') {
      if (e.key !== 'Shift') st.tabEscArmed = false;
      return;
    }
    // Tab key
    if (st.tabEscArmed) {
      // Allow natural tab navigation (focus exits editor)
      st.tabEscArmed = false;
      return;
    }
    e.preventDefault();
    const start = this.selectionStart;
    const end   = this.selectionEnd;
    this.value  = this.value.substring(0, start) + '    ' + this.value.substring(end);
    this.selectionStart = this.selectionEnd = start + 4;
    postCodeUpdate();
  });

  /* ============================================================
     Render task
     ============================================================ */
  function renderTask(task) {
    // Save draft of outgoing task
    if (st.task && st.task.id !== task.id) {
      st.drafts[st.task.id] = el.codeEditor.value;
      saveDrafts();
    }

    st.task = task;

    // Title
    el.taskTitle.textContent = task.title;

    // Prompt (markdown)
    el.taskPrompt.innerHTML = renderMarkdown(task.prompt || '');

    // Examples
    el.taskExamples.innerHTML = renderExamples(task.examples);

    // Format-specific layout
    if (task.format === 'discussion') {
      // No editor, full-width condition
      el.stateContent.classList.add('format-discussion');
      el.editorSection.style.display = 'none';
    } else {
      el.stateContent.classList.remove('format-discussion');
      el.editorSection.style.display = 'flex';

      // Restore draft, or use buggyVersion, or starterCode, or empty
      const draft = st.drafts[task.id];
      let editorValue;
      if (draft !== undefined) {
        editorValue = draft;
      } else if (task.buggyVersion != null) {
        editorValue = task.buggyVersion;        // no label — AC-2, §5
      } else if (task.starterCode != null) {
        editorValue = task.starterCode;
      } else {
        editorValue = '';
      }

      el.codeEditor.value = editorValue;

      // Placeholder for design (free-text notepad)
      el.codeEditor.placeholder = (task.format === 'design')
        ? 'набросайте здесь API, схему данных или заметки'
        : '';

      // Language label (informational only)
      el.editorLang.textContent = task.language || '';

      // Reset sync state
      el.syncWarning.hidden = true;
      st.syncPaused = false;
    }

    // Show content, trigger fade-in
    showState('content');

    // Announce and focus title (a11y)
    announce('Новая задача — ' + task.title);
    requestAnimationFrame(function () { el.taskTitle.focus(); });

    // Fade-in animation (both columns simultaneously)
    el.stateContent.classList.remove('fade-in');
    void el.stateContent.offsetWidth; // force reflow
    el.stateContent.classList.add('fade-in');
  }

  /* ============================================================
     Sync message handlers
     ============================================================ */

  // SELECT_TASK: resolve from own tasks.json copy, render candidate-visible fields only
  bus.on(T.SELECT_TASK, function (payload) {
    if (st.phase === 'scoring' || st.phase === 'done') return;
    const taskId = payload.taskId;
    if (!st.tasksMap) {
      // Tasks not loaded yet — park pending, show skeleton
      st.pendingTaskId = taskId;
      showState('loading');
      return;
    }
    const task = st.tasksMap[taskId];
    if (task) renderTask(task);
  });

  // SESSION_STATE: drive phase transitions
  bus.on(T.SESSION_STATE, function (payload) {
    const phase         = payload.phase;
    const currentTaskId = payload.currentTaskId;
    st.phase = phase;

    if (phase === 'scoring' || phase === 'done') {
      showState('finished');
      return;
    }

    if (currentTaskId && (phase === 'running' || phase === 'setup')) {
      if (st.tasksMap) {
        const task = st.tasksMap[currentTaskId];
        if (task) renderTask(task);
      } else {
        st.pendingTaskId = currentTaskId;
      }
    }
  });

  // SYNC_REQUEST: respond with current code if available
  bus.on(T.SYNC_REQUEST, function () {
    if (st.task && el.codeEditor.value) {
      bus.post(T.CANDIDATE_CODE_UPDATE, {
        taskId: st.task.id,
        code: el.codeEditor.value,
      });
    }
  });

  // RESET: clear everything, return to waiting
  bus.on(T.RESET, function () {
    st.task          = null;
    st.phase         = 'setup';
    st.pendingTaskId = null;
    st.syncPaused    = false;
    st.drafts        = {};
    saveDrafts();
    el.codeEditor.value       = '';
    el.syncWarning.hidden     = true;
    el.stateContent.classList.remove('format-discussion');
    showState('waiting');
    announce('Сессия сброшена');
  });

  // TIMER_STATE: no-op in v1 (reserved)
  bus.on(T.TIMER_STATE, function () { /* no-op */ });

  /* ============================================================
     Fetch tasks.json — builds candidate-only task map
     ============================================================ */
  function fetchTasks() {
    fetch('tasks.json')
      .then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.json();
      })
      .then(function (data) {
        const map = {};
        const tasks = data.tasks || [];
        tasks.forEach(function (raw) {
          const t = toCandidateTask(raw);
          if (t.id) map[t.id] = t;
        });
        st.tasksMap = map;

        // Render any task that arrived before load completed
        if (st.pendingTaskId) {
          const task = map[st.pendingTaskId];
          const id   = st.pendingTaskId;
          st.pendingTaskId = null;
          if (task && st.phase !== 'scoring' && st.phase !== 'done') {
            renderTask(task);
          } else if (!task && id) {
            // Unknown taskId — stay in current visible state
            console.warn('[candidate] Unknown taskId from pending:', id);
          }
        }
      })
      .catch(function (err) {
        console.error('[candidate] tasks.json fetch error:', err);
        // Show error only if no task is currently on screen
        if (!st.task) {
          showState('error');
        }
      });
  }

  /* ============================================================
     Retry button
     ============================================================ */
  if (el.retryBtn) {
    el.retryBtn.addEventListener('click', function () {
      showState('waiting');
      fetchTasks();
    });
  }

  /* ============================================================
     Init
     ============================================================ */
  function init() {
    // Default: waiting screen
    showState('waiting');

    // Quick restore from snapshot (before SYNC_REQUEST response)
    const snap = bus.loadSnapshot();
    if (snap) {
      st.phase = snap.phase;
      if (snap.phase === 'scoring' || snap.phase === 'done') {
        showState('finished');
      } else if (snap.currentTaskId) {
        // Will render after tasks.json loads
        st.pendingTaskId = snap.currentTaskId;
      }
    }

    // Signal readiness — interviewer responds with SESSION_STATE
    bus.post(T.SYNC_REQUEST, {});

    // Load task bank
    fetchTasks();
  }

  init();

}());
