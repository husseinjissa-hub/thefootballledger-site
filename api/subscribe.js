// Newsletter subscribe — Vercel serverless function (CommonJS, zero-dependency).
// Sends a branded welcome email to the subscriber AND notifies the owner so they
// can add the address to the mailing list. Uses Resend (https://resend.com).
//
// Required env var:  RESEND_API_KEY
// Optional env vars: SUBSCRIBE_FROM   (verified sender, e.g. "The Football Ledger <briefing@thefootballledger.co>")
//                    SUBSCRIBE_OWNER  (defaults to husseinjissa@gmail.com)

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
  if (!KEY) {
    // Not configured yet — accept the address so the UI still works, but flag it.
    return res.status(503).json({ ok: false, error: 'not_configured' });
  }

  const send = (to, subject, html, replyTo) => fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify(Object.assign(
      { from: FROM, to: [to], subject: subject, html: html },
      replyTo ? { reply_to: replyTo } : {}
    )),
  });

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

  const notifyHtml =
    '<div style="font-family:Arial,Helvetica,sans-serif;color:#1A1A1A">' +
      '<p style="font-size:14px;color:#57524A;margin:0 0 8px">New Briefing subscriber:</p>' +
      '<p style="font-size:20px;margin:0 0 16px"><strong>' + email + '</strong></p>' +
      '<p style="font-size:13px;color:#8A8578;margin:0">Add them to the mailing list.</p>' +
    '</div>';

  try {
    const results = await Promise.all([
      send(email, 'Welcome to The Football Ledger', welcomeHtml),
      send(OWNER, 'New subscriber: ' + email, notifyHtml, email),
    ]);
    const okAll = results.every(function (r) { return r && r.ok; });
    if (!okAll) {
      const detail = await results[0].text().catch(function () { return ''; });
      return res.status(502).json({ ok: false, error: 'send_failed', detail: detail.slice(0, 300) });
    }
    return res.status(200).json({ ok: true });
  } catch (e) {
    return res.status(500).json({ ok: false, error: 'exception' });
  }
};
