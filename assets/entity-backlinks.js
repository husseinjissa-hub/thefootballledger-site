/* ============================================================
   Entity-detail "Appears in" backlinks.
   Drop into any /entities/{slug}.html page (with content.js).
   Auto-detects the slug from the URL, finds every Ledger piece /
   Briefing note whose mentions[] includes it, and injects a list
   before the footer. Reuses the page's existing CSS tokens.
   ============================================================ */
(function () {
  var slug = (location.pathname.split('/').pop() || '').replace(/\.html$/, '');
  if (!slug || slug === 'index') return;
  var MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  function esc(s) { var e = document.createElement('div'); e.textContent = (s == null ? '' : s); return e.innerHTML; }
  function fmt(s) { if (!s) return ''; var p = String(s).split('-'); return p.length === 3 ? (p[2] + ' ' + MONTHS[parseInt(p[1],10)-1] + ' ' + p[0]) : s; }

  function run(d) {
    var arts = (d.articles || []).filter(function (a) { return (a.mentions || []).indexOf(slug) !== -1; })
      .sort(function (a, b) { return (b.date || '').localeCompare(a.date || ''); });
    var briefs = (d.briefings || []).filter(function (b) { return (b.mentions || []).indexOf(slug) !== -1; });
    if (!arts.length && !briefs.length) return;

    function row(a, isBrief) {
      var tag = isBrief
        ? '<span style="color:var(--gold);font-weight:500">Briefing</span>'
        : '<span style="color:var(--gold);font-weight:500">' + esc(a.type) + '</span>' +
          (a.layer != null ? ' · <span style="border:1px solid var(--line);border-radius:2px;padding:1px 7px">L' + a.layer + '</span>' : '') +
          (a.theme ? ' · <span style="color:var(--bone-mute)">' + esc(a.theme) + '</span>' : '');
      var meta = (a.date ? fmt(a.date) : '') + (a.readMinutes ? ' · ' + a.readMinutes + ' min' : '');
      return '<a href="' + esc(a.url || ('/' + (a.link || ''))) + '" style="display:grid;grid-template-columns:1fr auto;gap:8px 24px;align-items:start;padding:20px 0;border-top:1px solid var(--line-soft);color:inherit;text-decoration:none">' +
        '<div><div style="font-family:\'JetBrains Mono\',monospace;font-size:10px;letter-spacing:0.1em">' + tag + '</div>' +
        '<div style="font-family:\'Fraunces\',serif;font-size:19px;font-weight:500;line-height:1.2;margin-top:7px">' + esc(a.title) + '</div></div>' +
        (meta ? '<div style="font-family:\'JetBrains Mono\',monospace;font-size:10px;color:var(--bone-mute);white-space:nowrap;text-align:right">' + meta + '</div>' : '<div></div>') +
        '</a>';
    }

    var html = arts.map(function (a) { return row(a, false); }).join('') + briefs.map(function (b) { return row(b, true); }).join('');
    var sec = document.createElement('section');
    sec.setAttribute('aria-label', 'Appears in');
    sec.style.cssText = 'max-width:880px;margin:72px auto 40px;padding:0 60px';
    sec.innerHTML =
      '<div style="font-family:\'JetBrains Mono\',monospace;font-size:11px;letter-spacing:0.25em;text-transform:uppercase;color:var(--gold);border-top:1px solid var(--line);padding-top:40px;margin-bottom:8px">Appears in</div>' + html;

    var foot = document.querySelector('footer');
    if (foot && foot.parentNode) foot.parentNode.insertBefore(sec, foot);
    else document.body.appendChild(sec);
  }

  if (window.FL_CONTENT) run(window.FL_CONTENT);
  else fetch('/content.json').then(function (r) { return r.json(); }).then(run).catch(function () {});
})();
