/* ============================================================
   The Football Ledger — shared shell behaviour + content engine
   ============================================================ */
(function (w, d) {
  var FL = w.FL = w.FL || {};
  var MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  var LAYER_NAMES = { 1:'Governance', 2:'Leagues', 3:'Clubs/MCO', 4:'Capital', 5:'Agencies', 6:'Media', 7:'Commercial', 8:'Football-tech', 9:'Stadium/Fan' };
  FL.LAYER_NAMES = LAYER_NAMES;

  FL.esc = function (s) { var e = d.createElement('div'); e.textContent = (s == null ? '' : s); return e.innerHTML; };
  FL.fmtDate = function (s) { if (!s) return ''; var p = String(s).split('-'); return p.length === 3 ? (p[2] + ' ' + MONTHS[parseInt(p[1],10)-1] + ' ' + p[0]) : s; };

  // Tag block per §9:  <Type> · L<layer> · <Theme>   (layer omitted for Macro)
  FL.tagHTML = function (piece) {
    var out = '<span class="t-type">' + FL.esc(piece.type) + '</span>';
    if (piece.layer != null) out += '<span class="t-layer">L' + piece.layer + '</span>';
    if (piece.theme) out += '<span class="t-theme">' + FL.esc(piece.theme) + '</span>';
    return '<span class="tag">' + out + '</span>';
  };

  // Load content.json (or window.FL_CONTENT when opened from file://)
  FL.loadContent = function (cb) {
    if (w.FL_CONTENT) { cb(w.FL_CONTENT); return; }
    fetch('/content.json').then(function (r) { return r.json(); }).then(cb).catch(function () {
      fetch('content.json').then(function (r) { return r.json(); }).then(cb).catch(function () {
        cb({ articles: [], entities: [], briefings: [] });
      });
    });
  };

  // Shared nav: full-screen overlay (mobile)
  FL.initNav = function () {
    var overlay = d.getElementById('navOverlay');
    var burger = d.querySelector('.nav-burger');
    var closeBtn = d.querySelector('.nav-close');
    if (!overlay || !burger) return;
    function open() { overlay.classList.add('open'); overlay.setAttribute('aria-hidden','false'); burger.setAttribute('aria-expanded','true'); d.body.style.overflow = 'hidden'; }
    function close() { overlay.classList.remove('open'); overlay.setAttribute('aria-hidden','true'); burger.setAttribute('aria-expanded','false'); d.body.style.overflow = ''; }
    burger.addEventListener('click', open);
    if (closeBtn) closeBtn.addEventListener('click', close);
    overlay.addEventListener('click', function (e) { if (e.target === overlay) close(); });
    d.addEventListener('keydown', function (e) { if (e.key === 'Escape') close(); });
  };

  if (d.readyState !== 'loading') FL.initNav();
  else d.addEventListener('DOMContentLoaded', FL.initNav);
})(window, document);
