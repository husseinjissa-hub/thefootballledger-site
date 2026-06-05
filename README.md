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

## Maintaining the publication

**The golden rule: a published URL is permanent.** Never rename, renumber, or move a live article's file. Inbound links, social shares, and search indexing all depend on the URL never changing. Slugs like `macro-01-...` are stable *identifiers*, not a sort order — ordering is driven by each article's published date, never by its filename.

### Discovery is data-driven

`search-index.json` is the single source of truth for the homepage **Latest** rail and the **/search.html** archive. Both read it at runtime (so they require the site to be served over HTTP — they won't populate from a raw `file://` open). Regenerate it whenever content changes:

```bash
bash scripts/build-search-index.sh
```

### Adding an article

1. Create `posts/<slug>.html` with a **permanent, descriptive slug** (keep the `macro-`/`l<n>-` taxonomy prefix if it maps to the strategic map).
2. In its `<head>`, set the publish date: `<meta property="article:published_time" content="YYYY-MM-DD">`. This date — not the filename — controls ordering everywhere.
3. Add a line to the `ARTICLES` block in `scripts/build-search-index.sh` (`slug|order|tag`); `order` is only a same-date tie-break.
4. Run the generator, add the article's homepage card (switch it from "In production" to live), and add a `<url>` entry to `sitemap.xml`.

### Adding a briefing

Name it `briefing/YYYY-MM-DD.html` and add its row to `briefing/index.html` **at the top** (newest first). The generator picks up dated briefing files automatically.

## Copyright

© The Football Ledger. All rights reserved.
