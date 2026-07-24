# API — newsletter (Resend) + image upload (Vercel Blob)

Three serverless functions. All secrets are read from `process.env` (set in
Vercel → Project → Settings → Environment Variables) — nothing is hard-coded.

## Environment variables

| Var | Required | Purpose |
|-----|----------|---------|
| `RESEND_API_KEY` | yes | Resend API key — **Full access** (needed to write contacts + create/send broadcasts). |
| `RESEND_AUDIENCE_ID` | yes | The Resend Audience subscribers are added to and the Briefing is broadcast to. |
| `BROADCAST_SECRET` | yes (for broadcast) | Shared secret guarding `/api/broadcast`; sent as the `x-broadcast-secret` header. |
| `SUBSCRIBE_FROM` | optional | Verified sender. Default `The Football Ledger <briefing@thefootballledger.co>`. |
| `SUBSCRIBE_OWNER` | optional | Subscriber-notification recipient. Default `husseinjissa@gmail.com`. |
| `BLOB_READ_WRITE_TOKEN` | yes (for upload) | Set automatically when **Vercel Blob** is connected (Storage → Blob). Lets `/api/upload` write public images. |

If `RESEND_API_KEY` is missing, `/api/subscribe` returns `503 not_configured`
and the site's forms show a friendly "not live yet" message instead of erroring.

## `POST /api/subscribe`
Body `{ "email": "..." }`. Sends the welcome email, notifies the owner, and adds
the contact to the audience (duplicates are treated as success; an audience
failure never breaks the subscribe). Returns `{ ok, audience }`.

## `POST /api/broadcast`
Header `x-broadcast-secret: <BROADCAST_SECRET>` (constant-time checked; 401 on
mismatch or if the secret is unset). Body:

```json
{ "subject": "…", "html": "…", "test": false, "testEmail": "…", "dedupeKey": "2026-07-20" }
```

- `test: true` + `testEmail` → sends one test email only (no audience, no broadcast).
- `dedupeKey` → refuses to resend the same issue (`409 already_sent`); the key
  is stored as the Resend broadcast name and checked before creating.
- Appends a compliant `{{{RESEND_UNSUBSCRIBE_URL}}}` footer if the html lacks one.

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
