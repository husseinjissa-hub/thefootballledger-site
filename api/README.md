# API — newsletter (Resend)

Two serverless functions power the newsletter. All secrets are read from
`process.env` (set in Vercel → Project → Settings → Environment Variables) —
nothing is hard-coded.

## Environment variables

| Var | Required | Purpose |
|-----|----------|---------|
| `RESEND_API_KEY` | yes | Resend API key — **Full access** (needed to write contacts + create/send broadcasts). |
| `RESEND_AUDIENCE_ID` | yes | The Resend Audience subscribers are added to and the Briefing is broadcast to. |
| `BROADCAST_SECRET` | yes (for broadcast) | Shared secret guarding `/api/broadcast`; sent as the `x-broadcast-secret` header. |
| `SUBSCRIBE_FROM` | optional | Verified sender. Default `The Football Ledger <briefing@thefootballledger.co>`. |
| `SUBSCRIBE_OWNER` | optional | Subscriber-notification recipient. Default `husseinjissa@gmail.com`. |

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
