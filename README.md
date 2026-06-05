# The Football Ledger

A neutral analytical publication on the business, governance, and capital flows of football — ownership and multi-club groups, media rights, sovereign and institutional capital, and the operating models reshaping the game's next decade.

**Live:** [thefootballledger.co](https://thefootballledger.co)

## About this repository

This is the production source for the live site. It is a **static HTML publication** — no build step, no framework, no server-side dependencies. Every page is hand-authored HTML with inline CSS and inline SVG figures; the only external dependency is Google Fonts.

## Structure

```
.
├── index.html            # Homepage — the strategic map (macro trends + 10 layers)
├── about.html            # About the publication
├── posts/                # Long-form articles (macro theses + layer deep-dives)
├── entities/             # Reference profiles of clubs, owners, leagues, platforms
│   └── index.html        # Entity directory
├── briefing/             # Dated briefings
├── assets/               # Static assets
├── sitemap.xml           # Search-engine sitemap
├── robots.txt
├── 404.html              # Branded not-found page
└── vercel.json           # Deploy config (URL behaviour + security headers)
```

Articles still in production are listed on the homepage with an **"In production"** marker and are not yet published.

## Local preview

No build is required. Serve the directory with any static file server, e.g.:

```bash
npx serve .
# or
python -m http.server 8000
```

Then open the served URL in a browser.

## Deployment

Deployed on [Vercel](https://vercel.com) as a static site. Pushes to the default branch deploy automatically. URLs preserve the `/posts/<slug>.html` structure (`cleanUrls` is disabled in `vercel.json`).

## Copyright

© The Football Ledger. All rights reserved.
