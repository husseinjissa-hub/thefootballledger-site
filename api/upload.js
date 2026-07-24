// Protected image upload — hosts a briefing image on Vercel Blob at a public URL
// so the weekly broadcast can embed it in email. Called server-to-server by the
// broadcast task (which holds BROADCAST_SECRET); not linked from the public site.
//
// Env vars (set in Vercel):
//   BROADCAST_SECRET       required — shared secret; must match x-broadcast-secret header
//   BLOB_READ_WRITE_TOKEN  required — set automatically when Vercel Blob is connected
//
// POST JSON body: { filename, contentBase64, contentType? }
//   -> { ok:true, url }   (public Blob URL)

const { put } = require('@vercel/blob');
const crypto = require('crypto');

function safeEqual(a, b) {
  const A = Buffer.from(String(a || ''));
  const B = Buffer.from(String(b || ''));
  if (A.length !== B.length) { try { crypto.timingSafeEqual(A, A); } catch (e) {} return false; }
  try { return crypto.timingSafeEqual(A, B); } catch (e) { return false; }
}

const EXT_TYPE = { png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', webp: 'image/webp', svg: 'image/svg+xml', avif: 'image/avif' };
const MAX_BYTES = 8 * 1024 * 1024; // ~8MB

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

  const TOKEN = process.env.BLOB_READ_WRITE_TOKEN;
  if (!TOKEN) return res.status(500).json({ ok: false, error: 'blob_not_configured' });

  let body = req.body;
  if (typeof body === 'string') { try { body = JSON.parse(body); } catch (e) { body = {}; } }
  body = body || {};
  const rawName = (body.filename || '').toString().trim();
  const b64 = (body.contentBase64 || '').toString().trim();
  if (!rawName || !b64) return res.status(400).json({ ok: false, error: 'missing_filename_or_content' });

  // Sanitize filename -> keep the basename, lowercase, safe characters only.
  let name = rawName.split(/[\\/]/).pop().toLowerCase().replace(/[^a-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '');
  if (!name) name = 'image';
  let ext = (name.match(/\.([a-z0-9]+)$/) || [null, ''])[1];

  // Content type — from the body, else inferred from the extension; must be image/*.
  let contentType = (body.contentType || '').toString().trim().toLowerCase();
  if (!contentType) contentType = EXT_TYPE[ext] || '';
  if (!/^image\//.test(contentType)) return res.status(400).json({ ok: false, error: 'unsupported_content_type' });
  if (!ext) { ext = (contentType.split('/')[1] || 'png').replace('+xml', ''); name += '.' + ext; }

  // Decode + size guard.
  let buf;
  try { buf = Buffer.from(b64.replace(/^data:[^;]+;base64,/, ''), 'base64'); } catch (e) { return res.status(400).json({ ok: false, error: 'bad_base64' }); }
  if (!buf || buf.length === 0) return res.status(400).json({ ok: false, error: 'empty_image' });
  if (buf.length > MAX_BYTES) return res.status(413).json({ ok: false, error: 'too_large' });

  const now = new Date();
  const ym = now.getUTCFullYear() + '-' + String(now.getUTCMonth() + 1).padStart(2, '0');
  const pathname = 'briefing/' + ym + '/' + name;

  try {
    const blob = await put(pathname, buf, {
      access: 'public',
      token: TOKEN,
      contentType: contentType,
      addRandomSuffix: true, // avoid silently overwriting a same-named image
    });
    return res.status(200).json({ ok: true, url: blob.url });
  } catch (e) {
    return res.status(502).json({ ok: false, error: 'upload_failed', detail: (e && e.message ? String(e.message).slice(0, 300) : '') });
  }
};
