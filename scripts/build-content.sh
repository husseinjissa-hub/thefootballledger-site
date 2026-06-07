#!/usr/bin/env bash
#
# Builds content.json — the single source of truth for the restructured site
# (Overview samples, Ledger feed/filters, Entities directory, entity "Appears in"
# backlinks, Briefing list). Regenerate after adding/editing content.
#
#   bash scripts/build-content.sh
#
# Requires bash, grep, sed. No build toolchain. Output: ./content.json
# Article dek/title and entity name/summary are read from the HTML files;
# editorial fields (type/layer/theme/date/featured/mentions, entity mono/
# layer/type/region) live in the tables below — edit them here.

cd "$(dirname "$0")/.." || exit 1
OUT="content.json"

get_title() { grep -aoE '<title>[^<]*</title>' "$1" | head -1 | sed -E 's/<\/?title>//g; s/ — The Football Ledger.*//; s/ — Entity profile.*//'; }
get_desc()  { grep -aoE '<meta name="description" content="[^"]*"' "$1" | head -1 | sed -E 's/.*content="//; s/"$//'; }
get_dek()   { grep -aoE '<p class="article-deck">[^<]*</p>' "$1" | head -1 | sed -E 's/<[^>]*>//g'; }
get_read()  { grep -aoE '<strong>[0-9]+ min</strong>' "$1" | head -1 | grep -aoE '[0-9]+'; }
arr() { local out=""; for x in $1; do out="$out\"$x\","; done; echo "[${out%,}]"; }

tmp="$(mktemp)"

# ============ ARTICLES ============
# slug | type | layer(0=none) | theme | date | featured(0/1) | mentions(space-sep)
echo '{' > "$OUT"
echo '  "articles": [' >> "$OUT"
while IFS='|' read -r slug type layer theme date feat mentions; do
  [ -z "$slug" ] && continue
  f="posts/$slug.html"; [ -f "$f" ] || continue
  lyr="$layer"; [ "$layer" = "0" ] && lyr="null"
  fb="false"; [ "$feat" = "1" ] && fb="true"
  printf '    {"slug":"%s","title":"%s","type":"%s","layer":%s,"theme":"%s","readMinutes":%s,"date":"%s","status":"live","featured":%s,"url":"/posts/%s.html","mentions":%s,"dek":"%s"},\n' \
    "$slug" "$(get_title "$f")" "$type" "$lyr" "$theme" "$(get_read "$f")" "$date" "$fb" "$slug" "$(arr "$mentions")" "$(get_dek "$f")" >> "$tmp"
done <<'ARTICLES'
macro-01-trophy-to-operating|Macro|0|Capital · Governance|2026-04-02|1|pif apollo kingdom-holding fsg
macro-02-mco-consolidation|Macro|0|Ownership · MCO|2026-04-10|0|city-football-group fsg redbird blueco ineos-sport uefa
macro-03-usa-mega-cycle|Macro|0|Geography · Cycles|2026-04-18|0|mls fifa apple
macro-08-streaming-native-limits|Macro|0|Media · Rights|2026-06-05|1|apple amazon dazn sky bein-sports mls
l3-barcelona-crisis-recovery|Case study|3|Clubs/MCO|2026-05-20|1|la-liga cvc
l4-pif-phase-2|Case study|4|Capital|2026-05-12|0|pif kingdom-holding spl qsi mubadala saff
l6-apple-mls-case-study|Case study|6|Media|2026-04-26|0|apple mls
l6-bein-mena-fragmentation|Case study|6|Media|2026-05-04|0|bein-sports dazn ssc-shahid
l8-data-led-underdogs|Trend|8|Football-tech|2026-05-28|1|jamestown-analytics statsbomb hudl catapult two-circles
ARTICLES
sed '$ s/,$//' "$tmp" >> "$OUT"
echo '  ],' >> "$OUT"

# ============ ENTITIES ============
# slug | mono | layer | entityType | region   (name + summary read from file)
: > "$tmp"
while IFS='|' read -r slug mono layer etype region; do
  [ -z "$slug" ] && continue
  f="entities/$slug.html"; [ -f "$f" ] || continue
  printf '    {"slug":"%s","name":"%s","mono":"%s","layer":%s,"entityType":"%s","region":"%s","summary":"%s"},\n' \
    "$slug" "$(get_title "$f")" "$mono" "$layer" "$etype" "$region" "$(get_desc "$f")" >> "$tmp"
done <<'ENTITIES'
adidas|AD|7|commercial|Herzogenaurach
afc|AFC|1|federation|Kuala Lumpur
amazon|AM|6|broadcaster|Seattle
apollo|AO|4|PE|New York
apple|AP|6|broadcaster|Cupertino
arctos|AR|4|PE|Dallas
asm-global|AS|9|stadium|Los Angeles
baller-league|BL|2|league|Cologne
bein-sports|BN|6|broadcaster|Doha
blueco|BC|3|MCO|London
bundesliga|BU|2|league|Frankfurt
caa-stellar|CA|5|agency|London
catapult|CT|8|football-tech|Melbourne
city-football-group|CFG|3|MCO|Abu Dhabi
cvc|CV|4|PE|Luxembourg
dazn|DZ|6|broadcaster|London
emirates|EM|7|commercial|Dubai
etihad|ET|7|commercial|Abu Dhabi
fa|FA|1|federation|London
fanatics|FN|7|commercial|New York
fifa|FI|1|federation|Zürich
fsg|FSG|3|MCO|Boston
gestifute|GE|5|agency|Porto
hudl|HU|8|football-tech|Lincoln
img|IM|5|agency|New York
ineos-sport|IN|3|MCO|London
jamestown-analytics|JA|8|football-tech|Camden
kingdom-holding|KH|4|sovereign|Riyadh
kings-league|KL|2|league|Barcelona
la-liga|LL|2|league|Madrid
legends|LG|9|stadium|New York
mls|MLS|2|league|New York
mubadala|MB|4|sovereign|Abu Dhabi
nike|NK|7|commercial|Oregon
pif|PIF|4|sovereign|Riyadh
populous|PO|9|stadium|Kansas City
premier-league|PL|2|league|London
qsi|QSI|4|sovereign|Doha
redbird|RB|4|PE|New York
roc-nation-sports|RN|5|agency|New York
saff|SAF|1|federation|Riyadh
serie-a|SA|2|league|Milan
sky|SK|6|broadcaster|London
spl|SPL|2|league|Riyadh
ssc-shahid|SSC|6|broadcaster|Riyadh
statsbomb|SB|8|football-tech|London
two-circles|TC|7|commercial|London
uefa|UE|1|federation|Nyon
wasserman|WA|5|agency|Los Angeles
ENTITIES
echo '  "entities": [' >> "$OUT"
sed '$ s/,$//' "$tmp" >> "$OUT"
echo '  ],' >> "$OUT"

# ============ BRIEFINGS ============
echo '  "briefings": [' >> "$OUT"
: > "$tmp"
for f in $(ls briefing/[0-9]*.html 2>/dev/null | sort -r); do
  base="$(basename "$f" .html)"
  printf '    {"title":"%s","date":"%s","status":"live","url":"/%s","mentions":[],"link":null},\n' \
    "$(get_title "$f")" "$base" "$f" >> "$tmp"
done
sed '$ s/,$//' "$tmp" >> "$OUT"
echo '  ]' >> "$OUT"
echo '}' >> "$OUT"
rm -f "$tmp"

echo "Wrote $OUT: $(grep -c '"slug":"[^"]*","title"' "$OUT" 2>/dev/null || true) records"
echo "  articles: $(grep -oc '"type":"' "$OUT")  entities: $(grep -oc '"entityType":"' "$OUT")  briefings: $(grep -oc '"link":' "$OUT")"
