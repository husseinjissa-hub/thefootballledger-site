// One-click / footer unsubscribe — Vercel serverless function (CommonJS, zero-dependency).
//
// Accepts the signed link carried in the List-Unsubscribe header and the email
// footer. Gmail/Yahoo one-click sends a POST (RFC 8058); a human clicking the
// footer link sends a GET. Both verify an HMAC of the address so nobody can
// unsubscribe someone else by guessing URLs, then flip the contact to
// unsubscribed:true in the Resend audience (never hard-deleted — history stays).
//
// Env vars (set in Vercel):
//   RESEND_API_KEY      required — Resend API key (write contacts)
//   RESEND_AUDIENCE_ID  required — audience the contact lives in
//   BROADCAST_SECRET    required — HMAC key; must match the key used to sign links
//
//   GET  /api/unsubscribe?e=<email>&k=<sig>  -> branded confirmation page (human)
//   POST /api/unsubscribe?e=<email>&k=<sig>  -> 200 empty body (mail-client one-click)

const crypto = require('crypto');

function sign(email, secret) {
  return crypto.createHmac('sha256', String(secret || ''))
    .update(String(email || '').trim().toLowerCase())
    .digest('hex');
}

function safeEqualHex(a, b) {
  const A = Buffer.from(String(a || ''), 'utf8');
  const B = Buffer.from(String(b || ''), 'utf8');
  if (A.length !== B.length) return false;
  try { return crypto.timingSafeEqual(A, B); } catch (e) { return false; }
}

function page(title, body) {
  return '<!doctype html><html lang="en"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<meta name="robots" content="noindex">' +
    '<title>' + title + ' — The Football Ledger</title></head>' +
    '<body style="margin:0;background:#F4F1EA;color:#1A1A1A;font-family:Georgia,\'Times New Roman\',serif">' +
    '<div style="max-width:520px;margin:0 auto;padding:64px 24px">' +
    '<div style="font-size:22px;color:#0E2B22;letter-spacing:0.02em">The Football Ledger</div>' +
    '<div style="font-family:Helvetica,Arial,sans-serif;font-size:11px;letter-spacing:0.14em;text-transform:uppercase;color:#8A857B;margin:6px 0 32px">The Business of Football</div>' +
    body +
    '</div></body></html>';
}

module.exports = async function handler(req, res) {
  if (req.method !== 'GET' && req.method !== 'POST') {
    res.setHeader('Allow', 'GET, POST');
    return res.status(405).json({ ok: false, error: 'method_not_allowed' });
  }

  const SECRET = process.env.BROADCAST_SECRET;
  const KEY = process.env.RESEND_API_KEY;
  const AUDIENCE = process.env.RESEND_AUDIENCE_ID;
  if (!SECRET || !KEY || !AUDIENCE) {
    return res.status(500).json({ ok: false, error: 'not_configured' });
  }

  // Query params come from req.query on Vercel; fall back to parsing the URL.
  let email = '', k = '';
  if (req.query && (req.query.e || req.query.k)) {
    email = (req.query.e || '').toString();
    k = (req.query.k || '').toString();
  } else {
    try {
      const u = new URL(req.url, 'https://thefootballledger.co');
      email = (u.searchParams.get('e') || '').toString();
      k = (u.searchParams.get('k') || '').toString();
    } catch (e) {}
  }
  email = email.trim().toLowerCase();
  k = k.trim();

  const valid = email && k && safeEqualHex(k, sign(email, SECRET));
  if (!valid) {
    if (req.method === 'POST') return res.status(400).end();
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.status(400).send(page('Link not valid',
      '<h1 style="font-size:26px;font-weight:normal;line-height:1.25;margin:0 0 16px">This unsubscribe link isn&rsquo;t valid.</h1>' +
      '<p style="font-family:Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;color:#57524A;margin:0 0 24px">The address or signature didn&rsquo;t match. If you meant to unsubscribe, use the link in the most recent Briefing, or reply to any issue and we&rsquo;ll remove you.</p>' +
      '<a href="https://thefootballledger.co" style="font-family:Helvetica,Arial,sans-serif;font-size:14px;color:#0E2B22">Return to thefootballledger.co &rarr;</a>'));
  }

  // Best-effort: flip the contact to unsubscribed in the Resend audience.
  // Resend supports updating a contact by email in the path; if that route
  // 404s on this account, fall back to looking the id up and patching by id.
  const api = (path, opts) => fetch('https://api.resend.com' + path, Object.assign(
    { headers: { Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' } }, opts || {}));
  try {
    let r = await api('/audiences/' + AUDIENCE + '/contacts/' + encodeURIComponent(email),
      { method: 'PATCH', body: JSON.stringify({ unsubscribed: true }) });
    if (!r.ok) {
      const lr = await api('/audiences/' + AUDIENCE + '/contacts', { method: 'GET' });
      if (lr.ok) {
        const ld = await lr.json().catch(function () { return { data: [] }; });
        const c = (ld.data || []).find(function (x) {
          return x && (x.email || '').toString().trim().toLowerCase() === email;
        });
        if (c && c.id) {
          await api('/audiences/' + AUDIENCE + '/contacts/' + c.id,
            { method: 'PATCH', body: JSON.stringify({ unsubscribed: true }) });
        }
      }
    }
  } catch (e) { /* best-effort; a valid signature is still treated as unsubscribed */ }

  if (req.method === 'POST') return res.status(200).end();

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  return res.status(200).send(page('Unsubscribed',
    '<h1 style="font-size:26px;font-weight:normal;line-height:1.25;margin:0 0 16px">You&rsquo;ve been unsubscribed.</h1>' +
    '<p style="font-family:Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;color:#57524A;margin:0 0 16px">You won&rsquo;t receive further Briefings. Thanks for having read us.</p>' +
    '<p style="font-family:Helvetica,Arial,sans-serif;font-size:13px;line-height:1.6;color:#8A857B;margin:0 0 28px">Changed your mind? You can re-subscribe any time at thefootballledger.co.</p>' +
    '<a href="https://thefootballledger.co" style="font-family:Helvetica,Arial,sans-serif;font-size:14px;color:#0E2B22">Return to thefootballledger.co &rarr;</a>'));
};
