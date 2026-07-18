use strict; use warnings;
# Static-site generator for the redesign. Run from repo root:  perl redesign/build.pl
# Assembles pages from shared partials (head/header/footer) + page bodies + content.json data.
# No per-page duplication: the design system lives in assets/redesign.css and these partials.

sub slurp { my ($f)=@_; open(my $fh,'<:raw',$f) or die "read $f: $!"; local $/; my $c=<$fh>; close $fh; return $c; }
sub spit  { my ($f,$c)=@_; open(my $fh,'>:raw',$f) or die "write $f: $!"; print $fh $c; close $fh; }

my $head   = slurp("redesign/partials/head.html");
my $header = slurp("redesign/partials/header.html");
my $footer = slurp("redesign/partials/footer.html");

sub render_page {
  my (%o) = @_;   # out,title,desc,canonical,active,body
  my $h = $head;
  $h =~ s/\{\{TITLE\}\}/$o{title}/g;
  $h =~ s/\{\{DESC\}\}/$o{desc}/g;
  $h =~ s/\{\{CANONICAL\}\}/$o{canonical}/g;
  my $hdr = $header;
  for my $k (qw(OVERVIEW ECOSYSTEM LEDGER ENTITIES BRIEFING ABOUT JOIN)) {
    my $val = (lc($k) eq ($o{active}//'')) ? 'class="active"' : '';
    $hdr =~ s/\{\{ACTIVE_$k\}\}/$val/g;
  }
  spit($o{out}, $h . $hdr . $o{body} . $footer);
  print "built  $o{out}\n";
}

# ---------- parse content.json articles ----------
my $cj = slurp("content.json");
my @arts;
if ($cj =~ /"articles":\s*\[(.*?)\],\s*"entities"/s) {
  my $block = $1;
  while ($block =~ /\{([^{}]*)\}/g) {
    my $o = $1; my %a;
    $a{slug}  = $1 if $o =~ /"slug":"([^"]*)"/;
    $a{title} = $1 if $o =~ /"title":"([^"]*)"/;
    $a{type}  = $1 if $o =~ /"type":"([^"]*)"/;
    $a{theme} = ($o =~ /"theme":"([^"]*)"/) ? $1 : '';
    $a{layer} = ($o =~ /"layer":(\d+)/) ? $1 : '';
    $a{date}  = ($o =~ /"date":"([^"]*)"/) ? $1 : '';
    $a{status}= ($o =~ /"status":"([^"]*)"/) ? $1 : '';
    $a{url}   = $1 if $o =~ /"url":"([^"]*)"/;
    $a{read}  = ($o =~ /"readMinutes":(\d+)/) ? $1 : '';
    push @arts, \%a;
  }
}
my @live = sort { $b->{date} cmp $a->{date} } grep { $_->{status} eq 'live' } @arts;

my @mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
sub fmtdate { my ($d)=@_; return '' unless $d =~ /^(\d{4})-(\d{2})-(\d{2})/; return "$3 $mon[$2-1] $1"; }
sub esc { my ($s)=@_; $s//=''; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; return $s; }

# ---------- Top Stories cards ----------
sub story_card {
  my ($a) = @_;
  my $pill = $a->{layer} ne '' ? '<span class="tag-pill">L'.$a->{layer}.'</span>' : '';
  my $theme = $a->{theme} ne '' ? '<span class="acard-cat" style="color:var(--ink-3);font-weight:500">'.esc($a->{theme}).'</span>' : '';
  my $meta = fmtdate($a->{date});
  $meta .= ' · '.$a->{read}.' min' if $a->{read} ne '';
  my $imgp = "assets/img/articles/".$a->{slug}.".jpg";
  my $media = (-e $imgp)
    ? '<div class="acard-media"><img src="/'.$imgp.'" alt="'.esc($a->{title}).'" loading="lazy"></div>'
    : '<div class="acard-media img-ph"><span>Image</span></div>';
  return
  '<a class="acard" href="'.esc($a->{url}).'">'."\n".
  '      <div class="acard-tags"><span class="acard-cat">'.esc(uc $a->{type}).'</span>'.$pill.$theme.'</div>'."\n".
  '      <div class="acard-title">'.esc($a->{title}).'</div>'."\n".
  '      '.$media."\n".
  '      <div class="acard-meta">'.$meta.'</div>'."\n".
  '    </a>';
}
my $top = join("\n    ", map { story_card($_) } @live[0..3]);

# ---------- Overview ----------
my $ov = slurp("redesign/pages/overview.html");
$ov =~ s/\{\{TOP_STORIES\}\}/    $top/;
render_page(
  out=>"index.html", active=>"overview",
  title=>"The Football Ledger — The Business of Football",
  desc=>"Independent editorial analysis of football's business, governance, and capital — ownership, multi-club groups, media rights, and the operators shaping the game's next decade.",
  canonical=>"/",
  body=>$ov,
);

# ---------- entities ----------
my @ents;
if ($cj =~ /"entities":\s*\[(.*?)\],\s*"briefings"/s) {
  my $b=$1;
  while ($b =~ /\{([^{}]*)\}/g) { my $o=$1; my %e;
    $e{slug}=$1 if $o=~/"slug":"([^"]*)"/;
    $e{name}=($o=~/"name":"([^"]*)"/)?$1:'';
    $e{layer}=($o=~/"layer":(\d+)/)?$1:'';
    $e{type}=($o=~/"entityType":"([^"]*)"/)?$1:'';
    $e{region}=($o=~/"region":"([^"]*)"/)?$1:'';
    $e{summary}=($o=~/"summary":"([^"]*)"/)?$1:'';
    push @ents,\%e if $e{slug};
  }
}
my %layerCount; $layerCount{$_->{layer}}++ for @ents;

my %LICO = (
  1=>'<path d="M4 8l8-4 8 4M6 8v8M10 8v8M14 8v8M18 8v8M4 18h16"/>',
  2=>'<path d="M7 4h10v3a5 5 0 01-10 0zM7 5H4v1a3 3 0 003 3M17 5h3v1a3 3 0 01-3 3M10 13v3M14 13v3M8 18h8"/>',
  3=>'<path d="M12 3l7 3v5c0 4-3 7-7 8-4-1-7-4-7-8V6z"/><path d="M9.5 12l1.7 1.7 3.3-3.4"/>',
  4=>'<ellipse cx="12" cy="6" rx="7" ry="2.4"/><path d="M5 6v5c0 1.3 3.1 2.4 7 2.4s7-1.1 7-2.4V6M5 11v5c0 1.3 3.1 2.4 7 2.4s7-1.1 7-2.4v-5"/>',
  5=>'<circle cx="9" cy="8" r="2.6"/><circle cx="16" cy="9" r="2"/><path d="M4.5 18c0-2.5 2-4.5 4.5-4.5s4.5 2 4.5 4.5M14.5 18c0-1.7.8-3.1 2.2-3.7"/>',
  6=>'<rect x="3" y="5" width="18" height="12" rx="1"/><path d="M9 20h6M12 17v3"/>',
  7=>'<path d="M4 9l8-5 8 5v9a1 1 0 01-1 1H5a1 1 0 01-1-1z"/><path d="M9 19v-6h6v6"/>',
  8=>'<path d="M8 8l-4 4 4 4M16 8l4 4-4 4M13 6l-2 12"/>',
  9=>'<ellipse cx="12" cy="9" rx="9" ry="4"/><path d="M3 9v5c0 2.2 4 4 9 4s9-1.8 9-4V9"/>',
  'S'=>'<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M10.5 10l3.5 2-3.5 2z"/><path d="M8 21h8"/>',
);
my @SPORT = qw(kings-league baller-league icon-league the-soccer-tournament world-sevens-football);
my @LAYERS = (
  {disp=>'01',ico=>1,id=>1,title=>'Governing bodies',desc=>'The regulators and federations that set the rules of competition, governance, and national-team football.',feat=>[qw(fifa uefa afc fa saff)]},
  {disp=>'02',ico=>2,id=>2,title=>'Traditional leagues &amp; competitions',desc=>'The leagues and competitions where the game is played, fans are built, and rights are won.',feat=>[qw(premier-league la-liga serie-a bundesliga mls)],exclude=>[@SPORT]},
  {disp=>'02B',ico=>'S',id=>2,title=>'Sportainment leagues',desc=>'A parallel league tier built around non-traditional competition formats — typically 6- or 7-a-side.',feat=>[@SPORT],only=>[@SPORT]},
  {disp=>'03',ico=>3,id=>3,title=>'Clubs &amp; multi-club ownership',desc=>'The clubs at the center of the system and the ownership groups building portfolios.',feat=>[qw(city-football-group fsg blueco ineos-sport red-bull)]},
  {disp=>'04',ico=>4,id=>4,title=>'Capital — sovereign, PE, family, debt',desc=>'The capital providers funding growth, acquisitions, infrastructure, and innovation.',feat=>[qw(pif apollo cvc silver-lake oaktree)]},
  {disp=>'05',ico=>5,id=>5,title=>'Agencies &amp; representation',desc=>'Agents and agencies representing players, managers, and clubs in the global market.',feat=>[qw(caa-stellar img wasserman gestifute roc-nation-sports)]},
  {disp=>'06',ico=>6,id=>6,title=>'Media &amp; broadcasting',desc=>'Broadcasters and streaming platforms distributing football to billions of fans.',feat=>[qw(amazon dazn bein-sports tnt-sports netflix)]},
  {disp=>'07',ico=>7,id=>7,title=>'Commercial — kit, sponsor, retail',desc=>'Brands and platforms powering commercial revenues and fan engagement.',feat=>[qw(nike adidas emirates puma qatar-airways)]},
  {disp=>'08',ico=>8,id=>8,title=>'Football-tech, data &amp; performance',desc=>'Technology and data companies driving performance, operations, and insights.',feat=>[qw(catapult stats-perform statsbomb hudl genius-sports)]},
  {disp=>'09',ico=>9,id=>9,title=>'Stadium, matchday &amp; fan experience',desc=>'Stadium operators, venues, and platforms enhancing the fan and matchday experience.',feat=>[qw(aeg asm-global populous legends oak-view-group)]},
);
my %entName; $entName{$_->{slug}}=$_->{name} for @ents;
my %entByLayer; push @{$entByLayer{$_->{layer}}}, $_ for @ents;
sub mono { my ($n)=@_; my @w = grep {length} split /[^A-Za-z0-9]+/, ($n//''); return @w>=2 ? uc(substr($w[0],0,1).substr($w[1],0,1)) : uc(substr(($w[0]//'?'),0,2)); }
sub ent_chip {
  my ($e)=@_; my $s=$e->{slug}; my $p="assets/img/logos/$s.png";
  my $vis = (-e $p) ? '<span class="ent-chip-logo"><img src="/'.$p.'" alt="" loading="lazy"></span>'
                    : '<span class="ent-chip-mono">'.mono($e->{name}).'</span>';
  return '<a class="ent-chip" href="/entities/'.$s.'.html">'.$vis.'<span class="ent-chip-name">'.esc($e->{name}).'</span></a>';
}
sub layer_row {
  my ($L)=@_;
  my %featSet = map {$_=>1} @{$L->{feat}};
  my $flog = join('', map { my $s=$_; my $p="assets/img/logos/$s.png"; my $nm=esc($entName{$s}//$s);
    (-e $p)?'<a class="layer-logo-lnk" href="/entities/'.$s.'.html" aria-label="'.$nm.'"><img class="layer-logo" src="/'.$p.'" alt="'.$nm.'" loading="lazy"></a>':'' } @{$L->{feat}});
  my @all;
  if ($L->{only}) { my %o=map{$_=>1}@{$L->{only}}; @all = grep { $o{$_->{slug}} } @ents; }
  else { my %x = $L->{exclude} ? (map{$_=>1}@{$L->{exclude}}) : (); @all = grep { $_->{layer} eq $L->{id} && !$x{$_->{slug}} } @ents; }
  @all = grep { !$featSet{$_->{slug}} } @all;   # expand shows only entities NOT already on the front
  @all = sort { lc($a->{name}//'') cmp lc($b->{name}//'') } @all;
  my $more = @all ? '<button class="layer-more" type="button" aria-expanded="false">More <span class="arw">→</span></button>' : '';
  my $expand = @all ? "\n".'      <div class="layer-expand">'."\n".'        '.join("\n        ", map { ent_chip($_) } @all)."\n".'      </div>' : '';
  return
  '<div class="layer-row" data-layer="'.$L->{disp}.'">'."\n".
  '      <div class="layer-main">'."\n".
  '        <span class="layer-badge"><span class="layer-ico"><svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.3">'.$LICO{$L->{ico}}.'</svg></span><b>'.$L->{disp}.'</b></span>'."\n".
  '        <div class="layer-info"><div class="layer-title">'.$L->{title}.'</div><div class="layer-desc">'.$L->{desc}.'</div></div>'."\n".
  '        <div class="layer-logos">'.$flog.'</div>'."\n".
  '        '.$more."\n".
  '      </div>'.$expand."\n".
  '    </div>';
}
my $rows = join("\n    ", map { layer_row($_) } @LAYERS);
my $eco = slurp("redesign/pages/ecosystem.html");
$eco =~ s/\{\{LAYER_ROWS\}\}/    $rows/;
render_page(out=>"ecosystem.html", active=>"ecosystem",
  title=>"Ecosystem — The Football Ledger",
  desc=>"The nine-layer map of football's business — governance, leagues, clubs, capital, agencies, media, commercial, football-tech and stadium — with the key entities in each layer.",
  canonical=>"/ecosystem", body=>$eco);

# ============================================================
#  THE LEDGER — landing
# ============================================================
sub trunc { my ($s,$n)=@_; $s//=''; return $s if length($s)<=$n; my $c=substr($s,0,$n); $c=~s/\s+\S*$//; return $c.'…'; }
# type slug + display
my %TYSLUG = ('Macro'=>'macro','Trend'=>'trend','Case study'=>'case');
my %TYDISP = ('Macro'=>'Macro','Trend'=>'Trend','Case study'=>'Case Study');
# overline: returns ($TYPE, $REST) — REST = "Ln · " (if layer) + THEME, uppercased
sub ov_parts {
  my ($a)=@_;
  my $type = uc($a->{type});
  my $rest = '';
  $rest .= 'L'.$a->{layer}.' · ' if defined $a->{layer} && $a->{layer} ne '';
  $rest .= uc($a->{theme}) if $a->{theme} ne '';
  return ($type, $rest);
}
sub art_meta { my ($a)=@_; my $m=fmtdate($a->{date})||'In production'; $m.=' · '.$a->{read}.' min read' if $a->{read} ne ''; return $m; }
sub art_thumb {
  my ($a,$cls)=@_; my $p="assets/img/articles/".$a->{slug}.".jpg";
  return (-e $p) ? '<div class="'.$cls.'"><img src="/'.$p.'" alt="" loading="lazy"></div>'
                 : '<div class="'.$cls.' img-ph"><span>Image</span></div>';
}
my %bySlug; $bySlug{$_->{slug}}=$_ for @arts;

# --- Editor's Selection ---
my $lead = $bySlug{'macro-01-trophy-to-operating'} // $live[0];
my @featured = grep { $_->{slug} ne $lead->{slug} }
               grep { $bySlug{$_->{slug}} }
               map  { $bySlug{$_} } qw(macro-08-streaming-native-limits l8-data-led-underdogs l3-barcelona-crisis-recovery);
my ($ltype,$lrest) = ov_parts($lead);
my $lead_html =
  '<a class="es-lead" href="'.esc($lead->{url}).'">'."\n".
  '      <div class="es-lead-bg"><img src="/assets/img/articles/macro-01-lead.jpg" alt="" loading="lazy"></div>'."\n".
  '      <div class="overline">'.esc($ltype).($lrest?' '.esc($lrest):'').'</div>'."\n".
  '      <h3 class="es-lead-title">'.esc($lead->{title}).'</h3>'."\n".
  '      <p class="es-lead-dek">'.esc(trunc($lead->{dek},150)).'</p>'."\n".
  '      <div class="es-lead-meta">'.art_meta($lead).'</div>'."\n".
  '      <span class="es-lead-cta">Read article <span class="arw">→</span></span>'."\n".
  '    </a>';
my $stack_html = join("\n      ", map {
  my $a=$_; my ($t,$r)=ov_parts($a);
  '<a class="es-item" href="'.esc($a->{url}).'">'."\n".
  '        <div>'."\n".
  '          <div class="es-item-ol"><b>'.esc($t).'</b>'.($r?' '.esc($r):'').'</div>'."\n".
  '          <div class="es-item-title">'.esc($a->{title}).'</div>'."\n".
  '          <div class="es-item-meta">'.art_meta($a).'</div>'."\n".
  '        </div>'."\n".
  '        '.art_thumb($a,'es-item-thumb')."\n".
  '      </a>'
} @featured);
my $editors = '    '.$lead_html."\n    ".'<div class="es-stack">'."\n      ".$stack_html."\n    ".'</div>';

# --- Type pills (with counts) ---
my %tycount; $tycount{$_->{type}}++ for @arts;
my $type_pills = join("\n          ", map {
  '<button class="fr-pill" type="button" data-type="'.$TYSLUG{$_}.'">'.$TYDISP{$_}.' ('.($tycount{$_}||0).')</button>'
} ('Macro','Trend','Case study'));

# --- Filter layers 01–09 ---
my @FL = ([1,'Governance'],[2,'Leagues'],[3,'Clubs/MCO'],[4,'Capital'],[5,'Agencies'],[6,'Media'],[7,'Commercial'],[8,'Football-tech'],[9,'Stadium/Fan']);
my $filter_layers = join("\n          ", map {
  my ($n,$nm)=@$_;
  '<button class="fr-layer" type="button" data-layer="'.$n.'" aria-pressed="false"><span class="fr-layer-ico"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4">'.$LICO{$n}.'</svg></span><span class="fr-layer-num">'.sprintf('%02d',$n).'</span> '.$nm.'</button>'
} @FL);

# --- Feed rows (all articles, dated desc then in-production) ---
my @feed = sort { ($b->{date}||'') cmp ($a->{date}||'') } @arts;
my $bookmark_svg = '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M6 4h12v16l-6-4-6 4z"/></svg>';
my $feed_rows = join("\n        ", map {
  my $a=$_; my ($t,$r)=ov_parts($a);
  my $prodtag = $a->{status} eq 'prod' ? '<span class="feed-prodtag">In production</span>' : '';
  '<article class="feed-row'.($a->{status} eq 'prod' ? ' is-prod':'').'" data-type="'.($TYSLUG{$a->{type}}||'').'" data-layer="'.($a->{layer}//'').'" data-status="'.esc($a->{status}).'">'."\n".
  '          <a class="feed-thumb-lnk" href="'.esc($a->{url}).'" aria-label="'.esc($a->{title}).'" tabindex="-1">'.art_thumb($a,'feed-thumb').'</a>'."\n".
  '          <div class="feed-body">'."\n".
  '            <div class="feed-ol"><b>'.esc($t).'</b>'.($r?' '.esc($r):'').$prodtag.'</div>'."\n".
  '            <a class="feed-title" href="'.esc($a->{url}).'">'.esc($a->{title}).'</a>'."\n".
  '            <p class="feed-excerpt">'.esc(trunc($a->{dek},180)).'</p>'."\n".
  '          </div>'."\n".
  '          <div class="feed-side">'."\n".
  '            <div class="feed-meta">'.art_meta($a).'</div>'."\n".
  '            <button class="feed-bookmark" type="button" aria-label="Save article" aria-pressed="false">'.$bookmark_svg.'</button>'."\n".
  '          </div>'."\n".
  '        </article>'
} @feed);

my $lg = slurp("redesign/pages/ledger.html");
$lg =~ s/\{\{EDITORS\}\}/$editors/;
$lg =~ s/\{\{TYPE_PILLS\}\}/          $type_pills/;
$lg =~ s/\{\{FILTER_LAYERS\}\}/          $filter_layers/;
$lg =~ s/\{\{FEED_TOTAL\}\}/scalar(@feed)/e;
$lg =~ s/\{\{FEED_ROWS\}\}/        $feed_rows/;
render_page(out=>"ledger.html", active=>"ledger",
  title=>"The Ledger — Analysis · The Football Ledger",
  desc=>"Editorial analysis of the moves redrawing football's business — ownership, capital, media rights, and operating shifts. Filter by type and ecosystem layer.",
  canonical=>"/ledger", body=>$lg);

# ============================================================
#  THE LEDGER — article detail (reskin live posts + stub prod)
# ============================================================
# Key takeaways are editorial. Seeded here per-slug; box renders only when present.
# macro-08 takeaways are taken verbatim from the approved design mockup.
my $TK_BINO = '<path d="M7 4.5h2.5l1 3.5M17 4.5h-2.5l-1 3.5"/><circle cx="6.5" cy="14" r="3.6"/><circle cx="17.5" cy="14" r="3.6"/><path d="M10 13.5h4"/>';
my $TK_SCALE= '<path d="M12 4v16M7.5 20h9M5 8h14"/><path d="M5 8l-2.3 5.4a2.6 2.6 0 005.2 0zM19 8l-2.3 5.4a2.6 2.6 0 005.2 0z"/>';
my $TK_BARS = '<path d="M5.5 19V11M12 19V5.5M18.5 19v-5.5"/>';
my $TK_NODE = '<circle cx="6" cy="6.5" r="2"/><circle cx="18" cy="8.5" r="2"/><circle cx="10.5" cy="17.5" r="2"/><path d="M7.7 7.7l1.5 8M8 6.9l8 1.2M16.6 10.1l-4.6 6"/>';
my @TK_ICONS = ($TK_BINO,$TK_SCALE,$TK_BARS,$TK_NODE);
my %TAKEAWAYS = (
  'macro-08-streaming-native-limits' => [
    ['Streaming-native single-buyer experiments failed to scale','Apple and DAZN could not make standalone single-buyer models viable. Hybrid and tiered structures prevailed.'],
    ['Tier-1 auctions chose hybrid, not streaming-native exclusive','Premier League, Serie A and Champions League retained traditional operators and layered in streamers.'],
    ['Two structural pressures define the market','Unit economics and distribution depth & piracy resistance prevent a single platform from owning it all.'],
    ['Three configurations are now competing','Traditional pay-TV, hybrid streamer partnerships, and multi-rights platform plays — each with advantages and constraints.'],
  ],
  'macro-01-trophy-to-operating' => [
    ['The trophy era of ownership is closing','Two decades of football capital bought soft power and brand. The next decade is deployed for measurable return.'],
    ['Apollo–Atlético marks the arrival of the LBO','It is the first big-five control deal underwritten as a classic leveraged buyout by a generalist alternatives manager.'],
    ['PIF is reclassifying sport, not exiting it','Its 2026 reset moves assets toward privatisation and operating discipline, shifting clubs onto commercial governance and reporting burdens.'],
    ['The binding constraint is leadership, not capital','The scarce resource is executives who can hold financial discipline and football culture at once — not money or governance.'],
  ],
  'macro-02-mco-consolidation' => [
    ['Multi-club ownership has become the default','Just under forty-eight per cent of Big Five clubs now sit inside groups. The acquisition phase is settled.'],
    ['Only two groups have built real integration','City Football Group and Red Bull show audited cross-club synergies; the rest remain portfolios of clubs sharing an owner.'],
    ['The regulator has hardened against the model','UEFA Article 5 tightened in 2025 — blind trusts and strict assessment dates raise the operating cost for every group.'],
    ['Value comes from platforms, not assembly','The open question is whether assembled groups commit to integration capability — and whether the regulator lets them try.'],
  ],
  'macro-03-usa-mega-cycle' => [
    ['The asset class caught up to the audience','US soccer\'s audience grew for two decades; what changed is that private capital now treats it as a primary deployment category.'],
    ['The World Cup upside is already priced in','Valuations re-rated and broadcast deals were signed before the tournament — the post-2026 window rewards operators, not asset buyers.'],
    ['Two Division One models will compete','USL Premier\'s 2028 open-pyramid launch pressure-tests MLS\'s closed-franchise system; the winner sets the decade\'s operating baseline.'],
    ['The open question is a third capital pole','Whether the money entering US soccer builds a rival to Europe and the Gulf, or funds a still-secondary market.'],
  ],
  'l3-barcelona-crisis-recovery' => [
    ['A structural crisis, not an accident','Wages compounded faster than revenue through the 2010s; COVID pushed the wage-to-revenue ratio above 100 per cent and debt near €1.35bn.'],
    ['The Laporta levers registered the squad','Forward-selling broadcast rights, divesting Barça Studios, and structuring stadium debt cleared registration headroom by monetising future revenue.'],
    ['The recovery is genuine but partial','By 2026 the sporting-cost ratio and debt have improved markedly, yet each lever pulled is a future revenue line the club no longer keeps.'],
    ['The heritage tier now has a playbook','Member-owned clubs cannot summon sovereign cheques; rights monetisations and securitised debt let them absorb capital without ceding control.'],
  ],
  'l4-pif-phase-2' => [
    ['Absence from the six ecosystems is not exit','Sport left PIF\'s named priority ecosystems, but the assets remain inside the portfolio, most likely within the Strategic Portfolio.'],
    ['Al-Hilal is privatisation with retained influence','PIF divested seventy per cent to Kingdom Holding while keeping combined economic exposure near seventeen per cent and imposing listed-company discipline.'],
    ['The Big Four are redistributed, not liquidated','Direct exposure falls and operating mandates sharpen as clubs move to commercially-minded or sector-aligned hosts; the architecture survives in disciplined form.'],
    ['The redeployment reads as sophistication, not retreat','Capital is leaving sport near-term under war-period pressure, but the preserved 2034 pipeline suggests a re-architected, not emptied, structure.'],
  ],
  'l6-apple-mls-case-study' => [
    ['The standalone paywall was the wrong bet','MLS Season Pass at $99 never reached the subscriber depth the revenue-share upside required; premium pricing demands premium content scale.'],
    ['The restructure traded depth for reach','From 2026 MLS sits inside the Apple TV bundle at no incremental cost, shifting the deal\'s commercial geometry from subscriber depth to reach.'],
    ['A smaller headline masks strategic logic','Facing Apple\'s 2027 opt-out, MLS preserved cash against the downside, removed paywall friction, and aligned the deal with its mass-market scale.'],
    ['The 2029 renewal turns on optionality','The side with more options — a multi-broadcaster contest or an Apple content extension — will set the next cycle\'s price.'],
  ],
  'l6-bein-mena-fragmentation' => [
    ['The structural-decline narrative outran its evidence','beIN\'s premium portfolio expanded, not contracted — Premier League, La Liga, UEFA and Formula One all renewed at or above prior-cycle terms.'],
    ['The Saudi challenger dissolved against itself','SSC launched, lost the Saudi Pro League to Thmanyah, and closed within four years — turnover orthogonal to beIN\'s Western-rights position.'],
    ['The genuine pressures are real but narrow','Portfolio gaps in Serie A and Bundesliga, plus MENA\'s young streaming-first audience, name honest weaknesses without proving retreat.'],
    ['DAZN is the threat that matters, not SSC','A PIF-backed streaming-native operator is the serious forward risk, but its MENA expansion is unrealised and Ligue 1 deal collapsed.'],
  ],
  'l8-data-led-underdogs' => [
    ['A shared data stack, not a shared budget','Hearts, Union SG, Como, Ipswich and Bodø/Glimt overperform their wage bills; five buy Jamestown Analytics, the sixth builds the model in-house.'],
    ['The value compounds across three functions','Beyond targeted recruitment, the same data plumbing drives opposition analysis and, increasingly, head-coach search calibrated to each club.'],
    ['The stack is the cheapest senior hire','Costing less than one mid-tier transfer, its edge concentrates in the under-25 market before global scouting consensus catches up.'],
    ['The substrate is the first moat, not the last','Once universal, data access becomes table stakes; the durable edge shifts to coaching identity, academy pipeline, and executive bench.'],
  ],
);

my $ICO_CLOCK = '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';
my $ICO_CAL   = '<rect x="4" y="5" width="16" height="16" rx="1.5"/><path d="M4 9h16M8 3v4M16 3v4"/>';
my $ICO_TAG   = '<path d="M20 12l-8 8-9-9V3h8z"/><circle cx="7.5" cy="7.5" r="1.4"/>';

sub art_breadcrumb {
  my ($a,$raw)=@_;
  if ($raw && $raw =~ /<div class="article-eyebrow">(.*?)<\/div>/s) {
    my $e=$1; $e =~ s/<[^>]+>/ · /g; $e =~ s/\s*·\s*(·\s*)+/ · /g; $e =~ s/\s+/ /g; $e =~ s/^[\s·]+|[\s·]+$//g;
    my @p = split / · /, uc($e);
    my $first = shift @p;
    return '<b>'.esc($first).'</b>'.(@p?' · '.esc(join(' · ',@p)):'');
  }
  my @p = (uc($a->{type}));
  push @p, 'L'.$a->{layer} if $a->{layer} ne '';
  push @p, uc($a->{theme}) if $a->{theme} ne '';
  my $first = shift @p;
  return '<b>'.esc($first).'</b>'.(@p?' · '.esc(join(' · ',@p)):'');
}

sub build_article {
  my ($a)=@_;
  my $slug=$a->{slug};
  my $src="redesign/src-posts/$slug.html";
  my ($raw,$title_html,$standfirst,$prose,$signals);
  my $is_live = (-e $src);
  if ($is_live) {
    $raw = slurp($src);
    $title_html = ($raw =~ /<h1 class="article-title">(.*?)<\/h1>/s) ? $1 : esc($a->{title});
    $standfirst = ($raw =~ /<p class="article-deck">(.*?)<\/p>/s) ? $1 : esc($a->{dek});
    $prose = ($raw =~ /<div class="article-body">(.*?)<\/div>\s*(?:<aside class="signals"|<\/article>)/s) ? $1 : '';
    $signals = ($raw =~ /<aside class="signals">(.*?)<\/aside>/s) ? $1 : '';
  } else {
    $title_html = esc($a->{title});
    $standfirst = esc($a->{dek});
    $prose = '';
  }

  # sections + numbering
  my @secs = ($prose =~ /<h2>(.*?)<\/h2>/gs);
  my $n=0;
  $prose =~ s{<h2>(.*?)</h2>}{ $n++; '<h2 id="sec'.$n.'" class="prose-h2"><span class="prose-h2-num">'.sprintf('%02d',$n).'</span> '.$1.'</h2>' }ge;
  # anchor the footnotes for the TOC "sources" entry
  my $has_notes = ($prose =~ /<aside class="footnotes"/);
  $prose =~ s/<aside class="footnotes"/<aside id="sources" class="footnotes"/;

  # TOC
  my @toc;
  my $i=0;
  for my $s (@secs){ $i++; push @toc, ['sec'.$i, sprintf('%02d',$i), $s]; }
  my $tk = $TAKEAWAYS{$slug};
  push @toc, ['takeaways', sprintf('%02d',++$i), 'Key takeaways'] if $tk;
  push @toc, ['sources', sprintf('%02d',++$i), 'Appendix &amp; sources'] if $has_notes;
  my $toc_html = join("\n          ", map {
    '<li><a class="toc-link" href="#'.$_->[0].'"><span class="toc-num">'.$_->[1].'</span><span>'.$_->[2].'</span></a></li>'
  } @toc);

  # meta strip
  my $mread = $a->{read} ne '' ? $a->{read}.' min' : '—';
  my $mpub  = $a->{date} ne '' ? fmtdate($a->{date}) : 'In production';
  my $mtag  = uc($a->{type}).($a->{theme} ne '' ? ' · '.uc($a->{theme}) : '');
  my $metastrip =
    '<div class="art-meta-cell"><svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4">'.$ICO_CLOCK.'</svg><span><span class="amc-k">Read</span><br><span class="amc-v">'.$mread.'</span></span></div>'.
    '<div class="art-meta-cell"><svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4">'.$ICO_CAL.'</svg><span><span class="amc-k">Published</span><br><span class="amc-v">'.$mpub.'</span></span></div>'.
    '<div class="art-meta-cell"><svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4">'.$ICO_TAG.'</svg><span><span class="amc-k">Filed under</span><br><span class="amc-v">'.esc($mtag).'</span></span></div>';

  # takeaways box
  my $tk_html='';
  if ($tk){
    my $items = join('', map { my $j=$_; '<div class="tk-item"><span class="tk-ico"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4">'.$TK_ICONS[$j % @TK_ICONS].'</svg></span><div><div class="tk-title">'.esc($tk->[$j][0]).'</div><div class="tk-desc">'.esc($tk->[$j][1]).'</div></div></div>' } 0..$#$tk);
    $tk_html = '<div class="art-takeaways" id="takeaways"><div class="art-tk-head">Key takeaways</div>'.$items.'</div>';
  }

  # hero
  my $hp="assets/img/articles/$slug.jpg";
  my $hero = (-e $hp) ? '<div class="art-hero"><img src="/'.$hp.'" alt="" ></div>' : '';

  # body content
  my $body_main;
  if ($is_live) {
    $body_main = $tk_html."\n".'<div class="article-prose">'."\n".$prose."\n".'</div>';
    $body_main .= "\n".'<aside class="art-signals">'.$signals.'</aside>' if $signals && $signals =~ /\S/;
  } else {
    $body_main = '<div class="art-prodnote"><span class="apn-tag">In production</span><h3>This analysis is in production</h3><p>The Ledger is actively researching this piece. The summary above outlines the thesis; the full analysis, data, and sources will publish here.</p></div>';
  }

  # related sidebar — 3 other live pieces
  my @rel = grep { $_->{slug} ne $slug } @live;
  @rel = @rel[0..2] if @rel>3;
  my $rel_html = join("\n          ", map {
    my $r=$_; my ($t)=ov_parts($r);
    '<a class="art-rel-item" href="'.esc($r->{url}).'">'.art_thumb($r,'art-rel-thumb').
    '<div><div class="art-rel-cat">'.esc($t).'</div><div class="art-rel-title">'.esc($r->{title}).'</div><div class="art-rel-date">'.(fmtdate($r->{date})||'In production').'</div></div></a>'
  } @rel);

  my $bc = art_breadcrumb($a,$raw);

  my $body = <<"HTML";
<div class="art-wrap">
  <div class="art-grid">
    <aside class="art-side">
      <a class="art-back" href="/ledger"><span class="arw" style="transform:rotate(180deg);display:inline-block">→</span> Back to The Ledger</a>
      <div class="art-block art-block--toc">
        <div class="art-side-label">Overview</div>
        <ul class="toc-list">
          $toc_html
        </ul>
      </div>
      <div class="art-block">
        <div class="art-side-label">Article info</div>
        <div class="art-info-row"><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">$ICO_CLOCK</svg><b>$mread</b> read</div>
        <div class="art-info-row"><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">$ICO_CAL</svg>Published <b>$mpub</b></div>
        <div class="art-info-row"><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">$ICO_TAG</svg>@{[esc($mtag)]}</div>
        <button class="art-save art-info-row" type="button" aria-pressed="false"><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M6 4h12v16l-6-4-6 4z"/></svg>Save article</button>
      </div>
      <div class="art-block">
        <div class="art-side-label">Related articles</div>
        $rel_html
      </div>
      <div class="fr-news">
        <h4>Stay ahead of the game.</h4>
        <p>Join thousands of leaders shaping the business of football.</p>
        <form onsubmit="return false"><input type="email" placeholder="Your email" aria-label="Your email"><button type="submit">Subscribe to newsletter</button></form>
      </div>
    </aside>

    <article class="art-main">
      <div class="art-breadcrumb">$bc</div>
      <h1 class="art-title">$title_html</h1>
      <p class="art-standfirst">$standfirst</p>
      $hero
      <div class="art-metastrip">$metastrip</div>
      $body_main
    </article>
  </div>
</div>
<script>
(function(){
  var links=[].slice.call(document.querySelectorAll('.toc-link'));
  var save=document.querySelector('.art-save');
  if(save) save.addEventListener('click',function(){this.classList.toggle('on');this.setAttribute('aria-pressed',this.classList.contains('on')?'true':'false');});
  var secs=links.map(function(l){return document.getElementById(l.getAttribute('href').slice(1));}).filter(Boolean);
  if(!secs.length) return;
  var obs=new IntersectionObserver(function(es){
    es.forEach(function(e){ if(e.isIntersecting){ var id=e.target.id;
      links.forEach(function(l){ l.classList.toggle('active', l.getAttribute('href')==='#'+id); }); } });
  },{rootMargin:'-90px 0px -70% 0px',threshold:0});
  secs.forEach(function(s){obs.observe(s);});
})();
</script>
HTML

  render_page(out=>"posts/$slug.html", active=>"ledger",
    title=>$a->{title}." — The Football Ledger",
    desc=>$a->{dek}//$a->{title},
    canonical=>"/posts/$slug", body=>$body);
}

build_article($_) for @arts;

# ============================================================
#  ENTITIES — directory
# ============================================================
my @DIRLAYERS = (
  {id=>1, name=>'Governance', tag=>'Governance', desc=>'The rules, regulators, and institutions that govern the game.'},
  {id=>2, name=>'Leagues &amp; Competitions', tag=>'Leagues', desc=>'The leagues and competitions where the game is played.'},
  {id=>3, name=>'Clubs &amp; Multi-Club Ownership', tag=>'Clubs/MCO', desc=>'Clubs at the heart of the system and the ownership groups behind them.'},
  {id=>4, name=>'Capital', tag=>'Capital', desc=>'Investors and capital providers fuelling growth across football.'},
  {id=>5, name=>'Agencies', tag=>'Agencies', desc=>'Agents and agencies representing players, managers, and clubs.'},
  {id=>6, name=>'Media &amp; Broadcasting', tag=>'Media', desc=>'Broadcasters and streaming platforms distributing football worldwide.'},
  {id=>7, name=>'Commercial', tag=>'Commercial', desc=>'Brands and platforms powering commercial revenue and fan engagement.'},
  {id=>8, name=>'Football-Tech', tag=>'Football-Tech', desc=>'Technology and data companies driving performance and operations.'},
  {id=>9, name=>'Stadium / Fan Experience', tag=>'Stadium/Fan', desc=>'Venues, operators, and platforms shaping the matchday experience.'},
);
my %TYPLABEL = (MCO=>'Multi-club ownership', PE=>'Private equity', agency=>'Agencies', broadcaster=>'Broadcasters', commercial=>'Commercial', confederation=>'Confederations', credit=>'Credit funds', 'fan-platform'=>'Fan platforms', federation=>'Federations', 'football-tech'=>'Football-tech', league=>'Leagues', regulator=>'Regulators', sovereign=>'Sovereign funds', stadium=>'Stadiums', structured=>'Structured capital');
my %POP = (broadcaster=>'broadcasters', PE=>'pe', stadium=>'stadiums', 'football-tech'=>'technology', agency=>'agencies', regulator=>'regulators', federation=>'federations');
my %featRank; for my $L (@LAYERS){ next if $L->{only}; my $r=0; $featRank{$_}=$r++ for @{$L->{feat}}; }

sub ent_card_dir {
  my ($e,$tag)=@_; my $s=$e->{slug}; my $p="assets/img/logos/$s.png";
  my $logo = (-e $p) ? '<img src="/'.$p.'" alt="'.esc($e->{name}).'" loading="lazy">'
                     : '<span class="ent-card-mono">'.mono($e->{name}).'</span>';
  my @pop; push @pop, $POP{$e->{type}} if $POP{$e->{type}}; push @pop, 'clubs' if $e->{layer} eq '3';
  return
  '<a class="ent-card" href="/entities/'.$s.'.html" data-name="'.esc(lc $e->{name}).'" data-desc="'.esc(lc($e->{summary}//'')).'" data-layer="'.$e->{layer}.'" data-type="'.esc($e->{type}//'').'" data-pop="'.join(' ',@pop).'">'."\n".
  '          <div class="ent-card-logo">'.$logo.'</div>'."\n".
  '          <div class="ent-card-name">'.esc($e->{name}).'</div>'."\n".
  '          <div class="ent-card-desc">'.esc(trunc($e->{summary},96)).'</div>'."\n".
  '          <span class="ent-card-tag">L'.$e->{layer}.' · '.$tag.'</span>'."\n".
  '        </a>';
}

my $dir_sections = '';
# Layer 07 Commercial is grouped into commercial sub-categories (as on the legacy map)
my %ebs; $ebs{$_->{slug}}=$_ for @ents;
my @L7GROUPS = (
  ['Kit Suppliers',        [qw(nike adidas puma new-balance)]],
  ['Shirt Sponsors',       [qw(emirates etihad qatar-airways riyadh-air-alula-neom)]],
  ['Merchandise & Licensing',[qw(fanatics ea-sports)]],
  ['Marketing & Data',     [qw(two-circles)]],
);
for my $L (@DIRLAYERS) {
  my @in = grep { $_->{layer} eq $L->{id} } @ents;
  @in = sort { ($featRank{$a->{slug}}//999) <=> ($featRank{$b->{slug}}//999) || lc($a->{name}) cmp lc($b->{name}) } @in;
  next unless @in;
  my $cnt = scalar @in;
  my ($grouped, $body, $viewall) = (0, '', '<span></span>');
  if ($L->{id} eq '7') {
    $grouped = 1;
    my %used;
    for my $g (@L7GROUPS) {
      my @gc = grep { defined } map { $ebs{$_} } @{$g->[1]};
      next unless @gc; $used{$_->{slug}}=1 for @gc;
      $body .= '<div class="dir-subgroup"><div class="dir-subhead">'.$g->[0].'</div><div class="dir-cards">'."\n        ".
               join("\n        ", map { ent_card_dir($_,$L->{tag}) } @gc)."\n      </div></div>\n      ";
    }
    my @rest = grep { !$used{$_->{slug}} } @in;
    if (@rest) {
      $body .= '<div class="dir-subgroup"><div class="dir-subhead">Other commercial</div><div class="dir-cards">'."\n        ".
               join("\n        ", map { ent_card_dir($_,$L->{tag}) } @rest)."\n      </div></div>";
    }
  } else {
    $body = '<div class="dir-cards">'."\n        ".join("\n        ", map { ent_card_dir($_,$L->{tag}) } @in)."\n      </div>";
    $viewall = ($cnt>5) ? '<button class="dir-viewall" type="button"><span class="dvl-txt">View all '.$cnt.'</span> <span class="arw">→</span></button>' : '<span></span>';
  }
  $dir_sections .=
  '<section class="dir-layer'.($grouped?' dir-layer--grouped':'').'" data-layer="'.$L->{id}.'" data-count="'.$cnt.'">'."\n".
  '      <div class="dir-layer-head">'."\n".
  '        <span class="dir-layer-ico"><svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.3">'.$LICO{$L->{id}}.'</svg></span>'."\n".
  '        <div><div class="dir-layer-h"><span class="dir-layer-num">'.sprintf('%02d',$L->{id}).'</span><span class="dir-layer-name">'.$L->{name}.'</span></div><div class="dir-layer-desc">'.$L->{desc}.'</div></div>'."\n".
  '        '.$viewall."\n".
  '      </div>'."\n".
  '      '.$body."\n".
  '    </section>'."\n    ";
}

# rail layer buttons + type options
my $dir_rail = join("\n          ", map {
  my $L=$_;
  '<button class="fr-layer" type="button" data-layer="'.$L->{id}.'" aria-pressed="false"><span class="fr-layer-ico"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4">'.$LICO{$L->{id}}.'</svg></span><span class="fr-layer-num">'.sprintf('%02d',$L->{id}).'</span> '.$L->{tag}.'</button>'
} @DIRLAYERS);
my %tyPresent; $tyPresent{$_->{type}}++ for @ents;
my $dir_types = join("\n          ", map {
  '<option value="'.esc($_).'">'.esc($TYPLABEL{$_}//$_).'</option>'
} sort { ($TYPLABEL{$a}//$a) cmp ($TYPLABEL{$b}//$b) } grep { $_ ne '' } keys %tyPresent);

# ---------- entity detail (reskin legacy profiles) ----------
my $EI_SHIRT = '<path d="M8 4l-4 2 1.2 4 1.8-.5V20h10V9.5l1.8.5L20 6l-4-2a2.6 2.6 0 01-2 1 2.6 2.6 0 01-2-1z"/>';
my $EI_PIN   = '<path d="M12 21s7-5.6 7-11a7 7 0 10-14 0c0 5.4 7 11 7 11z"/><circle cx="12" cy="10" r="2.5"/>';
my $EI_USER  = '<circle cx="12" cy="8" r="4"/><path d="M4.5 20c0-3.6 3.4-6 7.5-6s7.5 2.4 7.5 6"/>';
my $EI_BARS  = '<path d="M5 20V11M12 20V5M19 20v-6"/><path d="M3 20h18"/>';
sub fact_icon {
  my ($lab)=@_; local $_=lc $lab;
  return ($ICO_CAL) if /found/;
  return ($EI_PIN)  if /headquart|based|location/;
  return ($EI_USER) if /leader|ceo|chair/;
  return ($EI_BARS) if /scale|revenue|aum|assets|value/;
  return ($EI_SHIRT) if /type|categ/;
  return $ICO_TAG;
}
sub esc_attr { my ($s)=@_; $s=esc($s); $s =~ s/"/&quot;/g; return $s; }

sub build_entity {
  my ($e)=@_; my $slug=$e->{slug};
  my $src="redesign/src-entities/$slug.html";
  return unless -e $src;
  my $raw=slurp($src);

  my $eyebrow = ($raw =~ /<div class="eyebrow">(.*?)<\/div>\s*<h1/s) ? $1 : '';
  $eyebrow =~ s/<[^>]+>/ /g; $eyebrow =~ s/\s*·\s*/ · /g; $eyebrow =~ s/\s+/ /g; $eyebrow =~ s/^[\s·]+|[\s·]+$//g;
  my @ep = split / · /, $eyebrow;
  my $ov_first = @ep ? shift @ep : uc($e->{type}//'');
  my $overline = '<b>'.esc(uc $ov_first).'</b>'.(@ep?' · '.esc(uc join(' · ',@ep)):'');

  my $name = ($raw =~ /<h1 class="entity-title">(.*?)<\/h1>/s) ? $1 : esc($e->{name});
  my $deck = ($raw =~ /<p class="entity-deck">(.*?)<\/p>/s) ? $1 : esc($e->{summary}//'');

  # facts -> meta strip (first 5)
  my @facts;
  while ($raw =~ /<div class="fact"><div class="fact-label">(.*?)<\/div><div class="fact-value">(.*?)<\/div><\/div>/gs) {
    push @facts, [$1,$2];
  }
  @facts = @facts[0..4] if @facts>5;
  my $metastrip = join('', map {
    my ($k,$v)=@$_;
    '<div class="art-meta-cell"><svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4">'.fact_icon($k).'</svg><span><span class="amc-k">'.esc($k).'</span><br><span class="amc-v">'.$v.'</span></span></div>'
  } @facts);

  # sections
  my @sec;   # [label, contentHtml]
  while ($raw =~ /<section class="section">(.*?)<\/section>/gs) {
    my $inner=$1;
    my $label = ($inner =~ /<div class="section-label">(.*?)<\/div>/s) ? $1 : '';
    (my $content = $inner) =~ s/<div class="section-label">.*?<\/div>//s;
    $content =~ s/<h2>(.*?)<\/h2>/<h3>$1<\/h3>/s;   # editorial headline -> serif subhead
    $content =~ s/^\s+//; $content =~ s/\s+$//;
    push @sec, [$label, $content];
  }

  my $n=0;
  my $prose = join("\n", map {
    my ($lab,$content)=@$_; $n++;
    '<div class="ent-h2" id="esec'.$n.'"><span class="ent-h2-num">'.sprintf('%02d',$n).'</span> '.esc(uc $lab).'</div>'."\n".$content
  } @sec);
  my $ti=0;
  my $toc = join("\n          ", map {
    my ($lab)=@$_; $ti++;
    '<li><a class="toc-link" href="#esec'.$ti.'"><span class="toc-num">'.sprintf('%02d',$ti).'</span><span>'.esc($lab).'</span></a></li>'
  } @sec);

  # logo
  my $lp="assets/img/logos/$slug.png";
  my $logo = (-e $lp) ? '<img src="/'.$lp.'" alt="'.esc_attr($e->{name}).'">'
                      : '<span class="ent-logo-mono">'.mono($e->{name}).'</span>';

  # breadcrumb
  my ($dl) = grep { $_->{id} eq $e->{layer} } @DIRLAYERS;
  my $lname = $dl ? $dl->{tag} : 'Layer '.$e->{layer};
  my $crumbs = '<a href="/entities">Entities</a><span class="sep">/</span><a href="/entities#layer-'.$e->{layer}.'">Layer '.sprintf('%02d',$e->{layer}).' · '.$lname.'</a><span class="sep">/</span><span>'.esc($e->{name}).'</span>';

  my $body = <<"HTML";
<div class="art-wrap">
  <nav class="ent-crumbs" aria-label="Breadcrumb">$crumbs</nav>
  <header class="ent-header">
    <div class="ent-logo-big">$logo</div>
    <div>
      <div class="ent-overline">$overline</div>
      <h1 class="ent-name">$name</h1>
      <p class="ent-deck">$deck</p>
    </div>
  </header>
  <div class="art-metastrip art-metastrip--5">$metastrip</div>

  <div class="art-grid">
    <aside class="art-side">
      <a class="art-back" href="/entities"><span class="arw" style="transform:rotate(180deg);display:inline-block">→</span> Back to Entities</a>
      <div class="art-block art-block--toc">
        <div class="art-side-label">On this profile</div>
        <ul class="toc-list">
          $toc
        </ul>
      </div>
      <div class="fr-news">
        <h4>Stay ahead of the game.</h4>
        <p>Join thousands of leaders shaping the business of football.</p>
        <form onsubmit="return false"><input type="email" placeholder="Your email" aria-label="Your email"><button type="submit">Subscribe to newsletter</button></form>
      </div>
    </aside>
    <article class="art-main">
      <div class="article-prose">
$prose
      </div>
    </article>
  </div>
</div>
<section class="wrap section" style="padding-top:0">
  <div class="cta-onesystem">
    <div class="cta-onesystem-left">
      <span class="cta-onesystem-ico"><svg width="72" height="72" viewBox="0 0 80 80" fill="none" stroke="currentColor" stroke-width="1.1"><circle cx="40" cy="40" r="30"/><circle cx="40" cy="40" r="6"/><circle cx="40" cy="12" r="3"/><circle cx="64" cy="30" r="3"/><circle cx="58" cy="62" r="3"/><circle cx="20" cy="60" r="3"/><circle cx="14" cy="28" r="3"/><path d="M40 18v16M46 40l15-8M44 44l12 16M36 44l-14 14M34 40l-14-10"/></svg></span>
      <div>
        <h3>One system. Infinite connections.</h3>
        <p>Explore how @{[esc($e->{name})]} fits into the football business ecosystem — and how value flows between every layer.</p>
      </div>
    </div>
    <a class="btn btn--primary" href="/ecosystem">Explore the ecosystem <span class="arw">→</span></a>
  </div>
</section>
<script>
(function(){
  var links=[].slice.call(document.querySelectorAll('.toc-link'));
  var secs=links.map(function(l){return document.getElementById(l.getAttribute('href').slice(1));}).filter(Boolean);
  if(!secs.length) return;
  var obs=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting){var id=e.target.id;links.forEach(function(l){l.classList.toggle('active',l.getAttribute('href')==='#'+id);});}});},{rootMargin:'-90px 0px -70% 0px',threshold:0});
  secs.forEach(function(s){obs.observe(s);});
})();
</script>
HTML

  render_page(out=>"entities/$slug.html", active=>"entities",
    title=>$e->{name}." — The Football Ledger",
    desc=>$e->{summary}//$e->{name},
    canonical=>"/entities/$slug", body=>$body);
}
build_entity($_) for @ents;

my $ecount = scalar @ents;
my $dir = slurp("redesign/pages/entities.html");
$dir =~ s/\{\{ENTITY_COUNT\}\}/$ecount/g;
$dir =~ s/\{\{DIR_RAIL_LAYERS\}\}/          $dir_rail/;
$dir =~ s/\{\{DIR_TYPE_OPTIONS\}\}/          $dir_types/;
$dir =~ s/\{\{DIR_SECTIONS\}\}/    $dir_sections/;
render_page(out=>"entities/index.html", active=>"entities",
  title=>"Entities — The Football Ledger",
  desc=>"A searchable directory of every actor in football's business — governing bodies, leagues, clubs, capital, agencies, media, commercial, football-tech and stadium operators.",
  canonical=>"/entities", body=>$dir);

# ---------- About ----------
render_page(out=>"about.html", active=>"about",
  title=>"About — The Football Ledger",
  desc=>"The Football Ledger is a neutral analytical publication on the business, governance, and capital of football — evidence-led deep-dives for readers who build, decide, and lead.",
  canonical=>"/about", body=>slurp("redesign/pages/about.html"));

# ---------- Join ----------
render_page(out=>"join.html", active=>"join",
  title=>"Join the Ledger — The Football Ledger",
  desc=>"Join The Football Ledger. We're looking for curious minds, clear thinkers, and structured writers — analysts, students, and industry insiders who understand football is a business.",
  canonical=>"/join", body=>slurp("redesign/pages/join.html"));

# ============================================================
#  BRIEFING (landing + issues), SEARCH, 404
# ============================================================
my @briefs;
if ($cj =~ /"briefings":\s*\[(.*?)\]\s*\}/s) {
  my $b=$1;
  while ($b =~ /\{([^{}]*)\}/g) { my $o=$1; my %r;
    $r{title}=($o=~/"title":"([^"]*)"/)?$1:'';
    $r{date}=($o=~/"date":"([^"]*)"/)?$1:'';
    $r{url}=($o=~/"url":"([^"]*)"/)?$1:'';
    $r{dek}=($o=~/"dek":"([^"]*)"/)?$1:'';
    push @briefs,\%r if $r{url};
  }
}
@briefs = sort { $b->{date} cmp $a->{date} } @briefs;

# --- Briefing landing ---
my $brief_rows = join("\n    ", map {
  my $r=$_; (my $t=$r->{title}) =~ s/\s*—\s*The Briefing.*$//;
  '<a class="brief-row" href="'.esc($r->{url}).'">'."\n".
  '      <div class="brief-date">'.fmtdate($r->{date}).'</div>'."\n".
  '      <div><div class="brief-title">'.esc($t).'</div>'.($r->{dek}?'<div class="brief-dek">'.esc($r->{dek}).'</div>':'').'</div>'."\n".
  '      <span class="brief-arw">→</span>'."\n".
  '    </a>'
} @briefs);
my $bl = slurp("redesign/pages/briefing.html");
$bl =~ s/\{\{BRIEF_ROWS\}\}/    $brief_rows/;
render_page(out=>"briefing/index.html", active=>"briefing",
  title=>"The Briefing — The Football Ledger",
  desc=>"The Briefing — dated short notes on what is moving in the business of football, week to week. Each issue explains the week's money stories and ends on the question that matters next.",
  canonical=>"/briefing", body=>$bl);

# --- Briefing issues (reskin from preserved source) ---
sub build_briefing {
  my ($r)=@_;
  my $file = (split m{/}, $r->{url})[-1];
  my $src = "redesign/src-briefing/$file";
  return unless -e $src;
  my $raw = slurp($src);
  # breadcrumb from eyebrow
  my $eye = ($raw =~ /<div class="issue-eyebrow">(.*?)<\/div>/s) ? $1 : 'The Briefing';
  $eye =~ s/\s+/ /g; $eye =~ s/^\s+|\s+$//g;
  my @ep = split /\s*·\s*/, $eye;
  my $bc = '<b>'.esc(shift @ep).'</b>'.(@ep?' · '.esc(join(' · ',@ep)):'');
  # title / deck
  my $title = ($raw =~ /<h1 class="issue-title">(.*?)<\/h1>/s) ? $1 : esc($r->{title});
  $title =~ s/^\s+|\s+$//g;
  my $deck = ($raw =~ /<p class="issue-deck">(.*?)<\/p>/s) ? $1 : esc($r->{dek});
  $deck =~ s/^\s+|\s+$//g;
  # meta pairs
  my @meta;
  if ($raw =~ /<div class="issue-meta">(.*?)<\/div>/s) { my $m=$1;
    while ($m =~ /<span>(.*?)<\/span>/gs) { my $s=$1;
      if ($s =~ /^(.*?)·\s*<strong>(.*?)<\/strong>/s) { my ($k,$v)=($1,$2); $k=~s/\s+$//; push @meta,[$k,$v]; }
    }
  }
  my @micons = ($ICO_CLOCK, '<path d="M4 6h16M4 12h16M4 18h10"/>', $ICO_CAL);
  my $metastrip = '';
  for my $i (0..$#meta) { my ($k,$v)=@{$meta[$i]};
    $metastrip .= '<div class="art-meta-cell"><svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4">'.($micons[$i]||$ICO_TAG).'</svg><span><span class="amc-k">'.esc($k).'</span><br><span class="amc-v">'.esc($v).'</span></span></div>';
  }
  my $info_rows = join('', map { '<div class="art-info-row">'.esc($_->[0]).' <b>'.esc($_->[1]).'</b></div>' } @meta);
  # TOC from toc-item strong labels
  my @toc; while ($raw =~ /<div class="toc-item">.*?<div class="toc-item-text"><strong>(.*?)<\/strong>/gs) { push @toc,$1; }
  my $ti=0;
  my $toc_html = join("\n          ", map { $ti++; '<li><a class="toc-link" href="#story'.$ti.'"><span class="toc-num">'.sprintf('%02d',$ti).'</span><span>'.$_.'</span></a></li>' } @toc);
  # stories, with ids for anchors
  my $stories = ($raw =~ /(<section class="stories">.*?<\/section>)/s) ? $1 : '';
  my $si=0; $stories =~ s/<article class="story">/'<article id="story'.(++$si).'" class="story">'/ge;
  (my $t=$r->{title}) =~ s/\s*—\s*The Briefing.*$//;

  my $body = <<"HTML";
<div class="art-wrap">
  <div class="art-grid">
    <aside class="art-side">
      <a class="art-back" href="/briefing"><span class="arw" style="transform:rotate(180deg);display:inline-block">→</span> Back to The Briefing</a>
      <div class="art-block art-block--toc">
        <div class="art-side-label">In this issue</div>
        <ul class="toc-list">
          $toc_html
        </ul>
      </div>
      <div class="art-block">
        <div class="art-side-label">Issue info</div>
        $info_rows
      </div>
      <div class="fr-news">
        <h4>Stay ahead of the game.</h4>
        <p>Join thousands of leaders shaping the business of football.</p>
        <form onsubmit="return false"><input type="email" placeholder="Your email" aria-label="Your email"><button type="submit">Subscribe to newsletter</button></form>
      </div>
    </aside>
    <article class="art-main">
      <div class="art-breadcrumb">$bc</div>
      <h1 class="art-title">$title</h1>
      <p class="art-standfirst">$deck</p>
      <div class="art-metastrip">$metastrip</div>
      $stories
    </article>
  </div>
</div>
<script>
(function(){
  var links=[].slice.call(document.querySelectorAll('.toc-link'));
  var secs=links.map(function(l){return document.getElementById(l.getAttribute('href').slice(1));}).filter(Boolean);
  if(!secs.length) return;
  var obs=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting){var id=e.target.id;links.forEach(function(l){l.classList.toggle('active',l.getAttribute('href')==='#'+id);});}});},{rootMargin:'-90px 0px -70% 0px',threshold:0});
  secs.forEach(function(s){obs.observe(s);});
})();
</script>
HTML
  render_page(out=>"briefing/$file", active=>"briefing",
    title=>$t." — The Briefing · The Football Ledger",
    desc=>$r->{dek}//$t, canonical=>$r->{url}, body=>$body);
}
build_briefing($_) for @briefs;

# --- Search ---
render_page(out=>"search.html", active=>"",
  title=>"Search — The Football Ledger",
  desc=>"Search The Football Ledger archive — articles, entity profiles, and briefings across the business of football.",
  canonical=>"/search", body=>slurp("redesign/pages/search.html"));

# --- 404 ---
render_page(out=>"404.html", active=>"",
  title=>"Page not found — The Football Ledger",
  desc=>"The page you're looking for isn't here.",
  canonical=>"/404", body=>slurp("redesign/pages/404.html"));

print "done.\n";
