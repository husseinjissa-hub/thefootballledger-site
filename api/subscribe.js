// Newsletter subscribe — Vercel serverless function (CommonJS, zero-dependency).
// Sends a branded welcome email to the subscriber, notifies the owner, and adds
// the subscriber to a Resend Audience. Reads all secrets from process.env.
//
// Env vars (set in Vercel):
//   RESEND_API_KEY      required — Resend API key (Full access, to write contacts)
//   RESEND_AUDIENCE_ID  optional — audience the subscriber is added to
//   SUBSCRIBE_FROM      optional — verified sender (default briefing@thefootballledger.co)
//   SUBSCRIBE_OWNER     optional — notification recipient (default husseinjissa@gmail.com)

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ ok: false, error: 'method_not_allowed' });
  }

  let body = req.body;
  if (typeof body === 'string') { try { body = JSON.parse(body); } catch (e) { body = {}; } }
  const email = ((body && body.email) || '').toString().trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return res.status(400).json({ ok: false, error: 'invalid_email' });
  }

  const KEY = process.env.RESEND_API_KEY;
  const FROM = process.env.SUBSCRIBE_FROM || 'The Football Ledger <briefing@thefootballledger.co>';
  const OWNER = process.env.SUBSCRIBE_OWNER || 'husseinjissa@gmail.com';
  const AUDIENCE = process.env.RESEND_AUDIENCE_ID;
  if (!KEY) return res.status(503).json({ ok: false, error: 'not_configured' });

  const api = (path, opts) => fetch('https://api.resend.com' + path, Object.assign(
    { headers: { Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' } }, opts));
  const send = (to, subject, html, replyTo) => api('/emails', {
    method: 'POST',
    body: JSON.stringify(Object.assign({ from: FROM, to: [to], subject: subject, html: html }, replyTo ? { reply_to: replyTo } : {})),
  });

  // 1) Add to the Resend Audience (best-effort; duplicates count as success).
  let audienceStatus = 'skipped';
  if (AUDIENCE) {
    try {
      const r = await api('/audiences/' + AUDIENCE + '/contacts', {
        method: 'POST',
        body: JSON.stringify({ email: email, unsubscribed: false }),
      });
      if (r.ok) {
        audienceStatus = 'added';
      } else {
        const t = await r.text().catch(function () { return ''; });
        audienceStatus = (r.status === 409 || /already|exists|duplicate/i.test(t)) ? 'exists' : 'failed';
      }
    } catch (e) { audienceStatus = 'failed'; }
  }

  const welcomeHtml =
    '<div style="background:#F5F2EA;padding:40px 0;font-family:Arial,Helvetica,sans-serif;color:#1A1A1A">' +
      '<div style="max-width:520px;margin:0 auto;background:#FCFBF6;border:1px solid #D9D3C6;border-radius:2px;padding:40px">' +
        '<div style="font-family:Georgia,serif;font-size:22px;color:#0E2B22;letter-spacing:0.02em">The Football Ledger</div>' +
        '<div style="font-size:11px;letter-spacing:0.14em;text-transform:uppercase;color:#8A8578;margin:6px 0 28px">The Business of Football</div>' +
        '<h1 style="font-family:Georgia,serif;font-size:26px;font-weight:normal;line-height:1.2;margin:0 0 16px">You&rsquo;re on the list.</h1>' +
        '<p style="font-size:15px;line-height:1.6;color:#57524A;margin:0 0 16px">Thanks for subscribing to <strong>The Briefing</strong> &mdash; our weekly read on what&rsquo;s moving in the business of football: ownership, capital, media rights, and the operators shaping the game.</p>' +
        '<p style="font-size:15px;line-height:1.6;color:#57524A;margin:0 0 24px">It lands every Monday morning. Before everyone else.</p>' +
        '<a href="https://thefootballledger.co/briefing" style="display:inline-block;background:#0E2B22;color:#F5F2EA;font-size:14px;text-decoration:none;padding:12px 22px;border-radius:2px">Read the latest issue &rarr;</a>' +
        '<p style="font-size:12px;line-height:1.5;color:#8A8578;margin:32px 0 0;border-top:1px solid #E7E1D4;padding-top:20px">You received this because you subscribed at thefootballledger.co. If this wasn&rsquo;t you, you can ignore this email.</p>' +
      '</div>' +
    '</div>';

  const audienceNote = audienceStatus === 'failed'
    ? '<p style="font-size:13px;color:#9a3b3b;margin:0 0 12px">&#9888; Could not add this contact to the Resend audience automatically — please add them manually.</p>'
    : '';
  const notifyHtml =
    '<div style="font-family:Arial,Helvetica,sans-serif;color:#1A1A1A">' +
      audienceNote +
      '<p style="font-size:14px;color:#57524A;margin:0 0 8px">New Briefing subscriber:</p>' +
      '<p style="font-size:20px;margin:0 0 16px"><strong>' + email + '</strong></p>' +
      '<p style="font-size:13px;color:#8A8578;margin:0">Audience: ' + audienceStatus + '.</p>' +
    '</div>';

  try {
    const [welcome, notify] = await Promise.all([
      send(email, 'Welcome to The Football Ledger', welcomeHtml),
      send(OWNER, 'New subscriber: ' + email, notifyHtml, email),
    ]);
    if (!(welcome && welcome.ok)) {
      const detail = await welcome.text().catch(function () { return ''; });
      return res.status(502).json({ ok: false, error: 'send_failed', detail: detail.slice(0, 300) });
    }
    // Subscriber experience must not break on owner/audience issues.
    return res.status(200).json({ ok: true, audience: audienceStatus });
  } catch (e) {
    return res.status(500).json({ ok: false, error: 'exception' });
  }
};
