# Entity logos — usage and conventions

This directory holds logo files used on the entity directory page (`/entities/index.html`) and individual entity profile pages.

## Filename convention

`<entity-slug>.svg` (preferred) or `<entity-slug>.png` (fallback for non-vector marks).

The `entity-slug` matches the HTML filename in `/entities/`. Examples:

- `fifa.svg` → used on `/entities/fifa.html` and in the entity-index card for FIFA
- `bein-sports.svg` → BeIN Sports
- `city-football-group.svg` → City Football Group
- `kingdom-holding.svg` → Kingdom Holding
- `apple.svg` → Apple (for Apple TV / MLS context — see note on Apple below)

## How to swap in a real logo

Each entity card in `/entities/index.html` currently looks like this:

```html
<a href="apollo.html" class="e-link live">
  <div class="e-logo"><span>Apollo</span></div>
  <div class="e-tag">L4 · PE</div>
  <div class="e-name">Apollo</div>
</a>
```

When a logo file is dropped into this directory, replace the `<span>Apollo</span>` with an `<img>` tag pointing at it:

```html
<a href="apollo.html" class="e-link live">
  <div class="e-logo"><img src="../assets/logos/apollo.svg" alt=""></div>
  <div class="e-tag">L4 · PE</div>
  <div class="e-name">Apollo</div>
</a>
```

The `alt=""` is intentional — the entity name in the `<div class="e-name">` already provides the accessible label; the logo is decorative-adjacent.

## Sourcing — best practices

1. **Pull from the entity's official press / brand-resource page where possible.** Most large entities maintain one (e.g. `apollo.com/about-apollo/media`, `uefa.com/insideuefa/mediaservices/media-relations/news-services/`, `apple.com/legal/intellectual-property/`).
2. **Prefer SVG over PNG.** Scales cleanly on retina displays, smaller file size.
3. **Use the version designed for light backgrounds.** The card has a `var(--bone)` (#f5f1e8) background, so the logo's "primary" or "for light backgrounds" version typically reads cleanest.
4. **Do not recolor or manipulate the mark.** Use it as the brand owner uses it. The single exception is when the brand provides a sanctioned monochrome version that would read better in this context — and even then, prefer the sanctioned colour version.
5. **Keep file sizes under 50 KB each.** Logos this small should compress well.

## Entities requiring extra care

Some brands have unusually strict usage guidelines. For these, default to the typographic fallback (the `<span>` mark) rather than risk an off-spec logo use.

- **Apple** — strict size minimums, clearance rules, no manipulation. If you need to reference Apple TV in the entity profile, prefer the "Apple TV" wordmark in your own typography over the bitten-apple logo.
- **Premier League, UEFA, FIFA** — all have brand-use guidelines that require specific contexts and prohibit certain manipulations. Editorial use is widely accepted but worth reading the guideline page first.
- **PIF, sovereign entities** — official logos may exist but rarely with usage guidance. Default to wordmark.
- **Family offices (Kingdom Holding, BlueCo)** — wordmark is often safer than a logo.

## Editorial attribution

The footer of `/entities/index.html` carries the attribution line:

> *Logos and trademarks shown above are the property of their respective owners and are used here for editorial identification of the entities profiled. No endorsement, affiliation, or sponsorship is implied.*

This line should remain on the page as long as any third-party logo appears. If individual entity profile pages display a logo at the top, they should also carry a similar inline attribution in the page footer.

## Workflow for adding logos in bulk

When sourcing multiple logos in one pass:

1. Drop the SVG / PNG files into this directory using the slug convention.
2. Open `/entities/index.html`.
3. For each card whose logo file is now present, replace the `<span>...</span>` inside the `<div class="e-logo">` with `<img src="../assets/logos/<slug>.<ext>" alt="">`.
4. Verify visually in browser — the bone-coloured card background should give all logos consistent contrast.
5. If any logo reads poorly against the bone background, switch to the brand's inverse / monochrome version, or revert that card to the typographic fallback.

## When a card has no logo available

Leave the `<span>` fallback in place. The page is designed to look complete with a mix of logo-cards and text-mark-cards. Empty logo boxes are not acceptable; the fallback is always rendered.
