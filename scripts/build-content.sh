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

# ---- IN-PRODUCTION stubs (drafts live in thefootballledger-editorial; metadata
# only — no body, no working link. title/dek hard-coded here because the draft
# HTML is not present in this repo. Rendered as greyed, un-linked feed rows.)
# slug | type | layer(0=none) | theme | title | dek
while IFS='|' read -r slug type layer theme title dek; do
  [ -z "$slug" ] && continue
  lyr="$layer"; [ "$layer" = "0" ] && lyr="null"
  printf '    {"slug":"%s","title":"%s","type":"%s","layer":%s,"theme":"%s","readMinutes":null,"date":null,"status":"prod","featured":false,"url":"/posts/%s.html","mentions":[],"dek":"%s"},\n' \
    "$slug" "$title" "$type" "$lyr" "$theme" "$slug" "$dek" >> "$tmp"
done <<'PROD'
l1-afc-saff-professionalising|Trend|1|Governance|AFC and SAFF, professionalising on the clock|The 2027 Asian Cup and 2034 World Cup have compressed a generation of federation-building into roughly 24 months. AFC and SAFF are rebuilding their operating organisations in real time.
l1-fifa-mega-events|Trend|1|Governance|FIFA's continuous calendar|FIFA's tournament pipeline now fires roughly every twelve months from 2025 to 2034. The federation is being remade from a quadrennial sanctioning body into a continuous global event-and-rights platform.
l1-national-regulators|Trend|1|Governance|National regulators arrive|The UK's Independent Football Regulator is operational. France and Germany are watching. Where federation self-regulation breaks, the state arrives.
l1-uefa-legal-pressure|Trend|1|Governance|UEFA under legal pressure|Three legal fronts — competition law, the transfer system, and financial sustainability — are reshaping UEFA's regulatory posture. The federation's room for manoeuvre is narrower than it has been in a generation.
l2-dtc-or-die|Trend|2|Leagues|DTC or die|The Ligue 1 broadcast-deal collapse forced the LFP to launch its own DTC platform. The pattern is now visible across leagues that fail to attract a premium broadcaster.
l2-league-pe-infrastructure|Trend|2|Leagues|League-level PE infrastructure|CVC's LaLiga and Ligue 1 commercial vehicles built the league-level PE template. Bundesliga, Serie A, SPL each studying or borrowing the structure.
l2-pl-exports-model|Trend|2|Leagues|Premier League exports the model|The Premier League's broadcast and operating template is being studied and licensed by leagues from Saudi Arabia to MLS to the Bundesliga.
l2-spl-privatisation|Trend|2|Leagues|SPL privatisation|Saudi Pro League's privatisation programme — staggered transfer of PIF anchor stakes in flagship clubs.
l10-format-convergence|Trend|2|Leagues|Sportainment, institutionalising|Mainstream capital has arrived. Top clubs joining established formats. MENA edition expected. By 2028 expect 2-3 dominant global formats and a regional tail.
l3-group-hq-arms-race|Trend|3|Clubs/MCO|Group-HQ talent arms race|CFG, FSG, RedBird, BlueCo, INEOS Sport are each building 30-to-80 person group-HQ teams that did not exist three years ago. The recruiting pattern is unusual for football: hires from outside the industry.
l3-mco-blowup-risk|Trend|3|Clubs/MCO|Mid-tier MCO blow-up risk|777 Partners has collapsed. Eagle Football is under cash-flow stress. Several smaller MCOs have shown the model can fail when leveraged acquisitions outpace operating capability. Expect 2-3 more public failures by 2028.
l3-womens-clubs-systematic|Trend|3|Clubs/MCO|Women's clubs added systematically|MCO groups now add women's clubs as a portfolio default rather than a CSR add-on. CFG, FSG, BlueCo, Mercury13. NWSL franchise valuations have crossed $100m. The economics still don't quite stand alone — but they may not need to.
l4-control-deals-normal|Trend|4|Capital|Control deals become normal|Apollo's 55% Atlético deal at €2.9bn breaks the minority-only convention in big-five Europe. The asset class re-prices.
l4-family-offices-organised|Trend|4|Capital|Family offices get organised|Family offices and HNW capital are building institutional underwriting capability around football. Eldridge, Kingdom Holding, Reuben Brothers, the Benetton-adjacent vehicles.
l4-permanent-capital|Trend|4|Capital|Permanent capital structures|Football capital moves toward evergreen and permanent-capital vehicles that match the long-cycle reality of club ownership. Arctos, RedBird Capital, holding-company structures.
l4-sports-tech-vc-matures|Trend|4|Capital|Sports-tech VC matures|The sports-tech VC category has crossed €1bn in dedicated capital. Verance, Gamma Waves, Courtside Ventures, a16z Sports Fund, Causeway Media. Specialist GPs win deal access; generalists overpay.
l5-coach-staff-talent-ip|Trend|5|Agencies|Coach-and-staff talent IP|Top managers now move with their backroom staff as a unit. Manager hires increasingly look like M&A.
l6-2027-pl-cycle-reset|Trend|6|Media|2027 PL cycle reset|The 2027-30 Premier League rights cycle is the inflection point for English football's broadcast economics.
l6-club-as-media-company|Trend|6|Media|Club-as-media-company matures|Real Madrid TV, LFCTV, City+, Inter+. Every top club now operates a content team and increasingly a DTC subscriber product.
l7-fanatics-vertical|Trend|7|Commercial|Category power-shifts|Fanatics has consolidated the licensed merchandise vertical end-to-end. Saudi state-aligned tourism brands have moved upstream into front-of-shirt and sleeve.
l7-front-of-shirt-multitier|Trend|7|Commercial|Commercial architecture, re-priced|Front-of-shirt multi-tier inventory + Two Circles-style data-led sponsorship pricing. The commercial discipline imported from digital advertising.
l8-llm-native-scouting|Trend|8|Football-tech|The AI-native football-tech stack|Foundation models are rebuilding the four dominant football-tech workflows in parallel: LLM scouting, CV auto-tagging, injury-risk prediction, psychological profiling.
l9-premium-hospitality-boom|Trend|9|Stadium/Fan|Stadium revenue engineering|Premium hospitality drives 10-18% of matchday revenue at top clubs and is growing 15%+ annually. Dynamic pricing reshaping the rest of the bowl.
l9-stadium-as-365-venue|Trend|9|Stadium/Fan|Stadium as 365-day venue|Top clubs run their stadia as 365-day entertainment venues. Concerts and other sports drive 20-30% of incremental revenue.
macro-04-mena-second-wave|Macro|0|Geography · MENA|MENA's second wave|Phase 2 of MENA football is operations, not signings. PIF reclassification, 2027 Asian Cup, 2034 World Cup, Mubadala, QSI.
macro-05-sportainment-genz|Macro|0|Sportainment · Audience|Sportainment and the Gen Z attention war|Kings League, Baller League, TST, World Sevens. Why traditional football's youth-attention problem is now a structural threat.
macro-06-womens-football|Macro|0|Women's · Capital|The institutional decade for women's football|NWSL valuations, the WSL spin-out, Mercury13, Boston Unity SC. Why women's football is now an institutional asset class.
macro-07-ai-native-ops|Macro|0|AI · Operations|AI-native football operations|From bolt-on tooling to operating substrate: a small set of clubs is rebuilding recruiting, medical, and content around foundation models. The durable edge is whether the org chart changes shape.
PROD
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
ligue-1|L1|2|league|Paris
icon-league|IC|2|league|Berlin
the-soccer-tournament|TST|2|league|Cary
world-sevens-football|W7|2|league|New York
red-bull|RBF|3|MCO|Fuschl
silver-lake|SL|4|PE|Menlo Park
verance-capital|VC|4|PE|New York
gamma-waves|GW|4|PE|Amsterdam
riyadh-air-alula-neom|RA|7|commercial|Riyadh
stats-perform|OP|8|football-tech|London
transferroom|TR|8|football-tech|London
ifr|IFR|1|regulator|Manchester
conmebol|CMB|1|confederation|Luque
concacaf|CCF|1|confederation|Miami
eredivisie|ER|2|league|Zeist
efl-championship|EFL|2|league|Preston
liga-mx|MX|2|league|Mexico City
eagle-football|EF|3|MCO|London
777-partners|777|3|MCO|Miami
v-sports|VS|3|MCO|Birmingham
oaktree|OT|4|credit|Los Angeles
clearlake|CL|4|PE|Santa Monica
ares|ARE|4|credit|Los Angeles
sixth-street|6S|4|structured|San Francisco
caa-base|CB|5|agency|London
you-first|YF|5|agency|Madrid
pimenta|RP|5|agency|Monaco
tnt-sports|TNT|6|broadcaster|London
netflix|NF|6|broadcaster|Los Gatos
canal-plus|C+|6|broadcaster|Paris
puma|PU|7|commercial|Herzogenaurach
new-balance|NB|7|commercial|Boston
ea-sports|EA|7|commercial|Redwood City
qatar-airways|QR|7|commercial|Doha
sportradar|SR|8|football-tech|St. Gallen
genius-sports|GS|8|football-tech|London
skillcorner|SC|8|football-tech|Paris
oak-view-group|OVG|9|stadium|Denver
aeg|AEG|9|stadium|Los Angeles
socios-chiliz|CHZ|9|fan-platform|Malta
ENTITIES
echo '  "entities": [' >> "$OUT"
sed '$ s/,$//' "$tmp" >> "$OUT"
echo '  ],' >> "$OUT"

# ============ BRIEFINGS ============
echo '  "briefings": [' >> "$OUT"
: > "$tmp"
for f in $(ls briefing/[0-9]*.html 2>/dev/null | sort -r); do
  base="$(basename "$f" .html)"
  dek="$(get_desc "$f" | sed -E 's/^The Briefing,? *Issue [0-9]+:? *//')"
  printf '    {"title":"%s","date":"%s","status":"live","url":"/%s","mentions":[],"link":null,"dek":"%s"},\n' \
    "$(get_title "$f")" "$base" "$f" "$dek" >> "$tmp"
done
sed '$ s/,$//' "$tmp" >> "$OUT"
echo '  ]' >> "$OUT"
echo '}' >> "$OUT"
rm -f "$tmp"

# JS wrapper so surfaces can load content when opened from file:// (fetch blocked)
{ printf 'window.FL_CONTENT = '; cat "$OUT"; printf ';\n'; } > content.js

echo "Wrote $OUT + content.js: $(grep -c '"slug":"[^"]*","title"' "$OUT" 2>/dev/null || true) records"
echo "  articles: $(grep -oc '"type":"' "$OUT")  entities: $(grep -oc '"entityType":"' "$OUT")  briefings: $(grep -oc '"link":' "$OUT")"
