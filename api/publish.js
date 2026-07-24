// Protected publish endpoint — commits a new Briefing page + a manifest entry to
// the repo via the GitHub Contents API, which triggers a Vercel deploy. Called by
// the Monday task after the email broadcast. CommonJS, zero extra dependency.
//
// Env vars (set in Vercel):
//   BROADCAST_SECRET  required — shared secret; must match x-broadcast-secret header
//   GITHUB_TOKEN      required — fine-grained PAT, Contents: read & write on the site repo
//   GITHUB_REPO       required — "owner/repo" (e.g. husseinjissa/thefootballledger-site)
//   GITHUB_BRANCH     optional — default "main"
//
// POST JSON body: { issue, date, title, slug, deck, html }
//   -> { ok:true, url, alreadyPublished? }

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

  const TOKEN = process.env.GITHUB_TOKEN;
  const REPO = process.env.GITHUB_REPO;
  const BRANCH = process.env.GITHUB_BRANCH || 'main';
  if (!TOKEN || !REPO) return res.status(500).json({ ok: false, error: 'not_configured' });

  let body = req.body;
  if (typeof body === 'string') { try { body = JSON.parse(body); } catch (e) { body = {}; } }
  body = body || {};
  const issue = (body.issue || '').toString().trim();
  const date = (body.date || '').toString().trim();
  const title = (body.title || '').toString().trim();
  const slug = (body.slug || '').toString().trim().toLowerCase().replace(/[^a-z0-9._-]/g, '');
  const deck = (body.deck || '').toString().trim();
  const html = (body.html || '').toString();
  if (!issue || !date || !title || !slug || !html) return res.status(400).json({ ok: false, error: 'missing_fields' });

  const gh = (path, opts) => fetch('https://api.github.com' + path, Object.assign({
    headers: Object.assign({
      Authorization: 'Bearer ' + TOKEN,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'thefootballledger-publish',
    }, (opts && opts.headers) || {}),
  }, opts || {}));

  const b64 = (s) => Buffer.from(s, 'utf8').toString('base64');
  const url = 'https://thefootballledger.co/briefing/' + slug;
  const MANIFEST = 'content/briefings.json';

  async function getFile(path) {
    const r = await gh('/repos/' + REPO + '/contents/' + encodeURI(path) + '?ref=' + encodeURIComponent(BRANCH));
    if (r.status === 404) return { exists: false };
    if (!r.ok) { const t = await r.text().catch(function () { return ''; }); throw new Error('get ' + path + ' ' + r.status + ' ' + t.slice(0, 180)); }
    const d = await r.json();
    return { exists: true, sha: d.sha, content: Buffer.from(d.content || '', 'base64').toString('utf8') };
  }
  async function putFile(path, content, message, sha) {
    const payload = { message: message, content: b64(content), branch: BRANCH };
    if (sha) payload.sha = sha;
    const r = await gh('/repos/' + REPO + '/contents/' + encodeURI(path), { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
    if (!r.ok) { const t = await r.text().catch(function () { return ''; }); throw new Error('put ' + path + ' ' + r.status + ' ' + t.slice(0, 180)); }
    return r.json();
  }

  try {
    // 1) Load the manifest and enforce idempotency on the slug.
    let manifest = [];
    let manifestSha;
    const mf = await getFile(MANIFEST);
    if (mf.exists) { manifestSha = mf.sha; try { manifest = JSON.parse(mf.content) || []; } catch (e) { manifest = []; } }
    if (!Array.isArray(manifest)) manifest = [];
    if (manifest.some(function (b) { return b && b.slug === slug; })) {
      return res.status(200).json({ ok: true, alreadyPublished: true, url: url });
    }

    // 2) Write the page (create, or update if it somehow already exists).
    const page = await getFile('briefing/' + slug + '.html');
    await putFile('briefing/' + slug + '.html', html, 'Publish Briefing ' + slug, page.exists ? page.sha : undefined);

    // 3) Prepend the manifest entry, keep newest-first, commit it.
    manifest.unshift({ issue: issue, date: date, title: title, slug: slug, deck: deck });
    manifest.sort(function (a, b) { return String(b.date || '').localeCompare(String(a.date || '')); });
    await putFile(MANIFEST, JSON.stringify(manifest, null, 2) + '\n', 'Add Briefing ' + slug + ' to manifest', manifestSha);

    return res.status(200).json({ ok: true, url: url });
  } catch (e) {
    return res.status(502).json({ ok: false, error: 'publish_failed', detail: (e && e.message ? String(e.message).slice(0, 300) : '') });
  }
};
