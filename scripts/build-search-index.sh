#!/usr/bin/env bash
#
# Regenerates search-index.json from the live HTML files.
# The index is the single source of truth for the homepage "Latest" rail
# and the /search.html keyword search. Run this whenever you add or change
# an article, briefing, or entity profile.
#
#   bash scripts/build-search-index.sh
#
# Requires: bash, grep, sed (any macOS / Linux / Git-Bash shell).
# No build toolchain, no network. Output: ./search-index.json
#
# To add a NEW article: give it a permanent /posts/<slug>.html, then add one
# line to the ARTICLES block below (slug|order|tag). Order is only a tie-break
# for items sharing a date; real ordering comes from the published date in the
# article's <meta property="article:published_time">.

cd "$(dirname "$0")/.." || exit 1
OUT="search-index.json"
GEN_DATE="$(date +%Y-%m-%d 2>/dev/null || echo 2026-06-05)"

strip_title() { sed -E 's/ — The Football Ledger.*//; s/ — Entity profile.*//; s/ · The Football Ledger.*//'; }
get_title() { grep -aoE '<title>[^<]*</title>' "$1" | head -1 | sed -E 's/<\/?title>//g' | strip_title; }
get_desc()  { grep -aoE '<meta name="description" content="[^"]*"' "$1" | head -1 | sed -E 's/.*content="//; s/"$//'; }
get_date()  { grep -aoE '<meta property="article:published_time" content="[^"]*"' "$1" | head -1 | sed -E 's/.*content="//; s/T.*//; s/"$//'; }

tmp="$(mktemp)"

# --- Articles (publication order is the same-date tie-break) ---
while IFS='|' read -r slug order tag; do
  [ -z "$slug" ] && continue
  f="posts/$slug.html"
  [ -f "$f" ] || continue
  d="$(get_date "$f")"; [ -z "$d" ] && d="$GEN_DATE"
  printf '    {"type":"article","title":"%s","url":"posts/%s.html","date":"%s","order":%s,"tag":"%s","summary":"%s"},\n' \
    "$(get_title "$f")" "$slug" "$d" "$order" "$tag" "$(get_desc "$f")" >> "$tmp"
done <<'ARTICLES'
macro-01-trophy-to-operating|1|Macro · Capital & Governance
macro-02-mco-consolidation|2|Macro · Multi-club ownership
macro-03-usa-mega-cycle|3|Macro · Geography & Cycles
macro-08-streaming-native-limits|4|Macro · Media & Rights
l3-barcelona-crisis-recovery|5|Layer 3 · Club case study
l4-pif-phase-2|6|Layer 4 · Capital
l6-apple-mls-case-study|7|Layer 6 · Media case study
l6-bein-mena-fragmentation|8|Layer 6 · Media case study
l8-data-led-underdogs|9|Layer 8 · Operating capability
ARTICLES

# --- Briefings (filename is the date; newest first) ---
for f in $(ls briefing/[0-9]*.html 2>/dev/null | sort -r); do
  base="$(basename "$f" .html)"
  printf '    {"type":"briefing","title":"%s","url":"%s","date":"%s","tag":"Briefing","summary":"%s"},\n' \
    "$(get_title "$f")" "$f" "$base" "$(get_desc "$f")" >> "$tmp"
done

# --- Entities (alphabetical, excluding the directory index) ---
for f in $(ls entities/*.html | grep -v 'entities/index.html' | sort); do
  printf '    {"type":"entity","title":"%s","url":"%s","tag":"Entity","summary":"%s"},\n' \
    "$(get_title "$f")" "$f" "$(get_desc "$f")" >> "$tmp"
done

# --- Assemble valid JSON (strip the trailing comma from the last entry) ---
{
  echo '{'
  printf '  "generated": "%s",\n' "$GEN_DATE"
  echo '  "docs": ['
  sed '$ s/,$//' "$tmp"
  echo '  ]'
  echo '}'
} > "$OUT"
rm -f "$tmp"

echo "Wrote $OUT ($(grep -c '"url":' "$OUT") documents)."
