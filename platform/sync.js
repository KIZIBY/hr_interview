/* HRI sync transport — микро-платформа интервью FDE (MVP).
 * Реализация контракта синхронизации из PRD §6.
 * Классический скрипт (без ES-модулей): экспортирует глобал window.HRISync.
 *
 * Транспорт: BroadcastChannel('x5-fde-interview-v1'); при отсутствии —
 * fallback на шину поверх localStorage (ключ ':bus' + событие 'storage').
 * Монотонный seq в конверте гарантирует изменение значения (иначе 'storage' не сработает).
 *
 * ВАЖНО: между вкладками, открытыми как file:// (opaque origin), синк НЕ работает —
 * страницы нужно раздавать по одному origin по http(s) (python3 scripts/serve.py).
 */
(function (global) {
  'use strict';

  var CHANNEL = 'x5-fde-interview-v1';
  var BUS_KEY = CHANNEL + ':bus';
  var SNAPSHOT_KEY = CHANNEL + ':snapshot';
  var PROTOCOL_VERSION = 1;

  // Контракт типов — APPEND-ONLY (PROTOCOL_VERSION не меняем при добавлении типов):
  // старые вкладки просто не подписаны на новый тип и молча его игнорируют (dispatch по env.type),
  // поэтому расширение обратно-совместимо и версию поднимать не требуется (PRD §6).
  var TYPES = {
    SELECT_TASK: 'SELECT_TASK',                     // { taskId }
    CANDIDATE_CODE_UPDATE: 'CANDIDATE_CODE_UPDATE',  // { taskId, code }
    TIMER_STATE: 'TIMER_STATE',                     // TimerState
    SESSION_STATE: 'SESSION_STATE',                 // { phase, currentTaskId, timer }
    SYNC_REQUEST: 'SYNC_REQUEST',                   // {}
    RESET: 'RESET',                                 // {}
    // Наблюдаемость живости кандидата (issue #6). Кандидат шлёт HEARTBEAT периодически
    // (и сразу при старте); интервьюер держит сторожевой таймер и гасит бейдж по таймауту.
    HEARTBEAT: 'HEARTBEAT',                         // {}
    // Явный сигнал ухода кандидата (beforeunload/pagehide) — гасит бейдж быстрее таймаута.
    // Доставка не гарантирована (вкладку могут убить жёстко), поэтому это ускорение,
    // а не замена сторожевому таймеру у интервьюера.
    DISCONNECT: 'DISCONNECT'                        // {}
  };

  function now() { return Date.now(); }

  /**
   * Создать шину сообщений.
   * @param {{ source: 'interviewer'|'candidate' }} opts
   */
  function create(opts) {
    opts = opts || {};
    var source = opts.source || 'unknown';
    var seq = 0;
    var handlers = Object.create(null); // type -> [cb]
    var anyHandlers = [];
    var bc = null;

    if (typeof global.BroadcastChannel === 'function') {
      try { bc = new global.BroadcastChannel(CHANNEL); } catch (e) { bc = null; }
    }

    function dispatch(env) {
      if (!env || env.v !== PROTOCOL_VERSION) return; // игнор чужого/иноверсионного (PRD §6)
      if (env.source === source) return;              // не реагируем на собственное эхо
      var list = handlers[env.type];
      if (list) { for (var i = 0; i < list.length; i++) list[i](env.payload, env); }
      for (var j = 0; j < anyHandlers.length; j++) anyHandlers[j](env);
    }

    if (bc) {
      bc.onmessage = function (ev) { dispatch(ev.data); };
    } else {
      global.addEventListener('storage', function (ev) {
        if (ev.key !== BUS_KEY || ev.newValue == null) return;
        var env; try { env = JSON.parse(ev.newValue); } catch (e) { return; }
        dispatch(env);
      });
    }

    function post(type, payload) {
      var env = {
        v: PROTOCOL_VERSION, type: type,
        payload: (payload == null ? {} : payload),
        ts: now(), seq: ++seq, source: source
      };
      if (bc) {
        bc.postMessage(env);
      } else {
        try { localStorage.setItem(BUS_KEY, JSON.stringify(env)); } catch (e) {}
      }
      return env;
    }

    function on(type, cb) {
      (handlers[type] || (handlers[type] = [])).push(cb);
      return function off() {
        handlers[type] = (handlers[type] || []).filter(function (h) { return h !== cb; });
      };
    }

    function onAny(cb) { anyHandlers.push(cb); }

    function saveSnapshot(obj) {
      try { localStorage.setItem(SNAPSHOT_KEY, JSON.stringify(obj)); } catch (e) {}
    }
    function loadSnapshot() {
      try { var raw = localStorage.getItem(SNAPSHOT_KEY); return raw ? JSON.parse(raw) : null; }
      catch (e) { return null; }
    }
    function clearSnapshot() { try { localStorage.removeItem(SNAPSHOT_KEY); } catch (e) {} }

    return {
      TYPES: TYPES,
      source: source,
      transport: bc ? 'broadcastchannel' : 'localstorage',
      post: post,
      on: on,
      onAny: onAny,
      saveSnapshot: saveSnapshot,
      loadSnapshot: loadSnapshot,
      clearSnapshot: clearSnapshot
    };
  }

  global.HRISync = {
    create: create,
    TYPES: TYPES,
    CHANNEL: CHANNEL,
    SNAPSHOT_KEY: SNAPSHOT_KEY,
    PROTOCOL_VERSION: PROTOCOL_VERSION
  };
})(window);
