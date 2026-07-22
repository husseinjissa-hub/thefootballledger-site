// Protected broadcast endpoint — sends the approved Briefing to the whole Resend
// Audience without the Resend key ever leaving Vercel. Called by the Monday
// scheduled task. CommonJS, zero-dependency.
//
// Env vars (set in Vercel):
//   RESEND_API_KEY      required — Full access key (create + send broadcasts)
//   RESEND_AUDIENCE_ID  required — audience to broadcast to
//   BROADCAST_SECRET    required — shared secret; must match x-broadcast-secret header
//   SUBSCRIBE_FROM      optional — sender (default briefing@thefootballledger.co)
//
// POST JSON body: { subject, html, test?, testEmail?, dedupeKey? }
//   test:true + testEmail  -> sends a single test email only (no audience, no broadcast)
//   dedupeKey              -> guards against sending the same issue twice (409 already_sent)

const crypto = require('crypto');

function safeEqual(a, b) {
  const A = Buffer.from(String(a || ''));
  const B = Buffer.from(String(b || ''));
  if (A.length !== B.length) { try { crypto.timingSafeEqual(A, A); } catch (e) {} return false; }
  try { return crypto.timingSafeEqual(A, B); } catch (e) { return false; }
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ ok: false, error: 'method_not_allowed' });
  }

  // Auth — constant-time; 401 whether the secret is missing or mismatched.
  const SECRET = process.env.BROADCAST_SECRET;
  const provided = req.headers['x-broadcast-secret'] || '';
  if (!SECRET || !safeEqual(provided, SECRET)) {
    return res.status(401).json({ ok: false, error: 'unauthorized' });
  }

  const KEY = process.env.RESEND_API_KEY;
  const AUDIENCE = process.env.RESEND_AUDIENCE_ID;
  const FROM = process.env.SUBSCRIBE_FROM || 'The Football Ledger <briefing@thefootballledger.co>';
  const REPLY = 'editor@thefootballledger.co';
  if (!KEY || !AUDIENCE) return res.status(500).json({ ok: false, error: 'not_configured' });

  let body = req.body;
  if (typeof body === 'string') { try { body = JSON.parse(body); } catch (e) { body = {}; } }
  body = body || {};
  const subject = (body.subject || '').toString().trim();
  let html = (body.html || '').toString();
  const isTest = body.test === true;
  const testEmail = (body.testEmail || '').toString().trim();
  const dedupeKey = (body.dedupeKey || '').toString().trim();
  if (!subject || !html) return res.status(400).json({ ok: false, error: 'missing_subject_or_html' });

  const api = (path, opts) => fetch('https://api.resend.com' + path, Object.assign(
    { headers: { Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' } }, opts || {}));

  // Test mode — send a single email, never touch the audience or create a broadcast.
  if (isTest) {
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(testEmail)) return res.status(400).json({ ok: false, error: 'missing_testEmail' });
    try {
      const r = await api('/emails', { method: 'POST', body: JSON.stringify({ from: FROM, to: [testEmail], subject: '[TEST] ' + subject, html: html, reply_to: REPLY }) });
      if (!r.ok) { const t = await r.text().catch(function () { return ''; }); return res.status(502).json({ ok: false, error: 'test_send_failed', detail: t.slice(0, 300) }); }
      const d = await r.json().catch(function () { return {}; });
      return res.status(200).json({ ok: true, broadcastId: d.id || null, recipientCount: 1, test: true });
    } catch (e) { return res.status(500).json({ ok: false, error: 'exception' }); }
  }

  // Ensure a compliant unsubscribe footer (Resend replaces the token for broadcasts).
  if (html.indexOf('RESEND_UNSUBSCRIBE_URL') === -1 && !/unsubscribe/i.test(html)) {
    html += '<p style="font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.5;color:#8A8578;margin-top:28px;text-align:center">' +
            'You are receiving this because you subscribed to The Football Ledger. ' +
            '<a href="{{{RESEND_UNSUBSCRIBE_URL}}}" style="color:#8A8578">Unsubscribe</a>.</p>';
  }

  const name = dedupeKey ? ('Briefing ' + dedupeKey) : ('Briefing ' + subject).slice(0, 190);

  try {
    // Idempotency — refuse if a broadcast with this dedupe name already exists (and isn't a draft).
    if (dedupeKey) {
      const lr = await api('/broadcasts', { method: 'GET' });
      if (lr.ok) {
        const ld = await lr.json().catch(function () { return { data: [] }; });
        const existing = (ld.data || []).find(function (b) { return b && b.name === name && b.status !== 'draft'; });
        if (existing) return res.status(409).json({ ok: false, error: 'already_sent', broadcastId: existing.id });
      }
    }

    // Create the broadcast against the audience.
    const cr = await api('/broadcasts', { method: 'POST', body: JSON.stringify({ audience_id: AUDIENCE, from: FROM, subject: subject, html: html, reply_to: REPLY, name: name }) });
    if (!cr.ok) { const t = await cr.text().catch(function () { return ''; }); return res.status(502).json({ ok: false, error: 'create_failed', detail: t.slice(0, 300) }); }
    const cd = await cr.json();
    const broadcastId = cd.id || (cd.data && cd.data.id);
    if (!broadcastId) return res.status(502).json({ ok: false, error: 'no_broadcast_id' });

    // Trigger the send.
    const sr = await api('/broadcasts/' + broadcastId + '/send', { method: 'POST', body: JSON.stringify({}) });
    if (!sr.ok) { const t = await sr.text().catch(function () { return ''; }); return res.status(502).json({ ok: false, error: 'send_failed', broadcastId: broadcastId, detail: t.slice(0, 300) }); }

    // Best-effort recipient count from the audience contacts.
    let recipientCount = null;
    try {
      const ar = await api('/audiences/' + AUDIENCE + '/contacts', { method: 'GET' });
      if (ar.ok) { const ad = await ar.json().catch(function () { return { data: [] }; }); recipientCount = (ad.data || []).filter(function (c) { return c && !c.unsubscribed; }).length; }
    } catch (e) {}

    return res.status(200).json({ ok: true, broadcastId: broadcastId, recipientCount: recipientCount });
  } catch (e) {
    return res.status(500).json({ ok: false, error: 'exception' });
  }
};
