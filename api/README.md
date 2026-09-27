# API — newsletter (Resend) + image upload (Vercel Blob)

Serverless functions. All secrets are read from `process.env` (set in
Vercel → Project → Settings → Environment Variables) — nothing is hard-coded.

## Environment variables

| Var | Required | Purpose |
|-----|----------|---------|
| `RESEND_API_KEY` | yes | Resend API key — **Full access** (needed to write contacts + create/send broadcasts). |
| `RESEND_AUDIENCE_ID` | yes | The Resend Audience subscribers are added to and the Briefing is broadcast to. |
| `BROADCAST_SECRET` | yes (for broadcast) | Shared secret guarding `/api/broadcast` (sent as the `x-broadcast-secret` header) **and** the HMAC key that signs one-click unsubscribe links verified by `/api/unsubscribe`. |
| `SUBSCRIBE_FROM` | optional | Verified sender. Default `The Football Ledger <briefing@thefootballledger.co>`. |
| `SUBSCRIBE_OWNER` | optional | Subscriber-notification recipient. Default `husseinjissa@gmail.com`. |
| `BLOB_READ_WRITE_TOKEN` | yes (for upload) | Set automatically when **Vercel Blob** is connected (Storage → Blob). Lets `/api/upload` write public images. |
| `GITHUB_TOKEN` | yes (for publish) | Fine-grained PAT — **Contents: read & write** on the site repo only. Lets `/api/publish` commit briefing pages. |
| `GITHUB_REPO` | yes (for publish) | `owner/repo`, e.g. `husseinjissa/thefootballledger-site`. |
| `GITHUB_BRANCH` | optional | Branch to commit to. Default `main`. |

If `RESEND_API_KEY` is missing, `/api/subscribe` returns `503 not_configured`
and the site's forms show a friendly "not live yet" message instead of erroring.

## `POST /api/subscribe`
Body `{ "email": "..." }`. Sends the welcome email, notifies the owner, and adds
the contact to the audience (duplicates are treated as success; an audience
failure never breaks the subscribe). Returns `{ ok, audience }`.

The welcome email carries a `List-Unsubscribe` / `List-Unsubscribe-Post`
one-click header, a plain-text alternative, and a signed unsubscribe link in the
footer (all skipped only if `BROADCAST_SECRET` is unset). Sender is unchanged —
it stays whatever `SUBSCRIBE_FROM` is set to in Vercel; this work does not touch
the From address.

## `GET`/`POST /api/unsubscribe`
Handles one-click and footer unsubscribes. Query `?e=<email>&k=<sig>` where `sig`
= `HMAC-SHA256(lowercased-email, BROADCAST_SECRET)` hex. Invalid signature → 400,
no action.

- `POST` (Gmail/Yahoo one-click, RFC 8058) → `200` empty body.
- `GET` (human clicks the footer link) → a branded confirmation page.
- On a valid signature the contact is set `unsubscribed: true` in the Resend
  audience (looked up by email, id fallback) — **never hard-deleted**, so history
  stays. Resend's audience send skips unsubscribed contacts automatically.

## `POST /api/broadcast`
Header `x-broadcast-secret: <BROADCAST_SECRET>` (constant-time checked; 401 on
mismatch or if the secret is unset). Body:

```json
{ "subject": "…", "html": "…", "test": false, "testEmail": "…", "dedupeKey": "2026-07-20" }
```

- `test: true` + `testEmail` → sends one test email only (no audience, no
  broadcast). Because a plain `/emails` send gets neither Resend's broadcast
  unsubscribe token nor its headers, the test is given a **signed** one-click
  `List-Unsubscribe` header + footer for the test address, so the test proves the
  exact header Gmail will see.
- `dedupeKey` → refuses to resend the same issue (`409 already_sent`); the key
  is stored as the Resend broadcast name and checked before creating.
- Appends a compliant `{{{RESEND_UNSUBSCRIBE_URL}}}` footer if the html lacks one
  (Resend replaces the token per recipient and adds the one-click
  `List-Unsubscribe` headers to broadcasts automatically).
- Sends a `text/plain` alternative alongside the HTML (supplied via `text`, else
  derived from the HTML).

Returns `{ ok, broadcastId, recipientCount }`.

Dry-run example:

```bash
curl -X POST https://thefootballledger.co/api/broadcast \
  -H "content-type: application/json" \
  -H "x-broadcast-secret: $BROADCAST_SECRET" \
  -d '{"subject":"Test","html":"<p>Hello</p>","test":true,"testEmail":"you@example.com"}'
```

## `POST /api/upload`
Hosts a briefing image on **Vercel Blob** so the broadcast can embed it (email
needs a public URL). Same `x-broadcast-secret` auth as `/api/broadcast` (401 on
mismatch or if the secret is unset). Requires **Vercel Blob connected** (sets
`BLOB_READ_WRITE_TOKEN`) and `@vercel/blob` (see `package.json`). Body:

```json
{ "filename": "spurs-stake.jpg", "contentBase64": "…", "contentType": "image/jpeg" }
```

- `contentType` optional — inferred from the filename extension if omitted; must be `image/*`.
- Rejects non-images and files larger than ~8MB.
- Stores at `briefing/<yyyy-mm>/<sanitized-filename>` (public, random suffix to avoid overwrites).

Returns `{ ok, url }` — the public Blob URL.

```bash
curl -X POST https://thefootballledger.co/api/upload \
  -H "content-type: application/json" \
  -H "x-broadcast-secret: $BROADCAST_SECRET" \
  -d "{\"filename\":\"test.png\",\"contentBase64\":\"$(base64 -w0 test.png)\"}"
```

## `POST /api/publish`
Publishes a Briefing to the website by committing it to the repo (→ Vercel
redeploys). Same `x-broadcast-secret` auth. Requires `GITHUB_TOKEN` (+ `GITHUB_REPO`,
optional `GITHUB_BRANCH`). Body:

```json
{ "issue": "Issue 14", "date": "2026-07-21", "title": "…", "slug": "2026-07-21", "deck": "…", "html": "<!doctype html>…" }
```

- `html` is the full, already-styled briefing page.
- Commits `briefing/<slug>.html`, then prepends `{issue,date,title,slug,deck}` to
  `content/briefings.json` (the manifest the briefing index renders from).
- **Idempotent:** if `slug` is already in the manifest, returns
  `{ ok:true, alreadyPublished:true, url }` and changes nothing.

Returns `{ ok, url, alreadyPublished? }`. The briefing index (`/briefing`) reads
`content/briefings.json` client-side, so the new issue appears after the deploy —
no rebuild of the prebuilt index needed.

## Deliverability

The inbox-placement setup is additive and does **not** touch the sender — every
message still comes from the configured `SUBSCRIBE_FROM` (from_name
`The Football Ledger`), with `reply_to: editor@thefootballledger.co`. DNS auth
(SPF + DKIM + `DMARC p=none`) is configured at the DNS level, separately from
this code.

- **One-click List-Unsubscribe** on every send: the bulk Briefing via Resend
  Broadcasts (Resend adds the headers + `{{{RESEND_UNSUBSCRIBE_URL}}}`
  per recipient); the welcome and test emails via a signed
  `/api/unsubscribe?e=&k=` header that this code sets on the `/emails` call.
- **Visible footer** unsubscribe link in the briefing template and welcome email.
- **`text/plain`** alternative on broadcast, welcome, and test sends.

### Pre-ship checklist (run against a Vercel preview before Monday)
1. `test:true` send to **mail-tester.com** and to a personal Gmail + Outlook —
   confirm score ≥ 8/10 and that Gmail shows the "Unsubscribe" link next to the
   sender (proves the header is valid).
2. Click the footer **Unsubscribe** → confirm the contact flips to
   `unsubscribed: true` in the Resend audience and the branded page renders.
3. Re-run the broadcast and confirm the unsubscribed contact is skipped
   (Resend audience send does this automatically).
4. Verify the received **From** line is unchanged — the configured
   `SUBSCRIBE_FROM` (`The Football Ledger`), not a subdomain. The spec expects
   `editor@thefootballledger.co`; if the received From differs, fix the
   `SUBSCRIBE_FROM` env var rather than the code.
