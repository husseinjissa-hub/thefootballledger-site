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
  my $imgp = "assets/img/articles/".$a->{slug}.".png";
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
);
my @LAYERS = (
  [1,'Governing bodies','The regulators and federations that set the rules of competition, governance, and national-team football.',[qw(fifa uefa afc fa saff)]],
  [2,'Traditional leagues &amp; competitions','The leagues and competitions where the game is played, fans are built, and rights are won.',[qw(premier-league la-liga serie-a bundesliga mls)]],
  [3,'Clubs &amp; multi-club ownership','The clubs at the center of the system and the ownership groups building portfolios.',[qw(city-football-group fsg blueco ineos-sport red-bull)]],
  [4,'Capital — sovereign, PE, family, debt','The capital providers funding growth, acquisitions, infrastructure, and innovation.',[qw(pif apollo cvc silver-lake oaktree)]],
  [5,'Agencies &amp; representation','Agents and agencies representing players, managers, and clubs in the global market.',[qw(caa-stellar img wasserman gestifute roc-nation-sports)]],
  [6,'Media &amp; broadcasting','Broadcasters and streaming platforms distributing football to billions of fans.',[qw(amazon dazn bein-sports tnt-sports netflix)]],
  [7,'Commercial — kit, sponsor, retail','Brands and platforms powering commercial revenues and fan engagement.',[qw(nike adidas emirates puma qatar-airways)]],
  [8,'Football-tech, data &amp; performance','Technology and data companies driving performance, operations, and insights.',[qw(catapult stats-perform statsbomb hudl genius-sports)]],
  [9,'Stadium, matchday &amp; fan experience','Stadium operators, venues, and platforms enhancing the fan and matchday experience.',[qw(aeg asm-global populous legends oak-view-group)]],
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
  my ($L)=@_; my ($num,$title,$desc,$feat)=@$L;
  my $flog = join('', map { my $s=$_; my $p="assets/img/logos/$s.png"; my $nm=esc($entName{$s}//$s);
    (-e $p)?'<a class="layer-logo-lnk" href="/entities/'.$s.'.html" aria-label="'.$nm.'"><img class="layer-logo" src="/'.$p.'" alt="'.$nm.'" loading="lazy"></a>':'' } @$feat);
  my @all = sort { lc($a->{name}//'') cmp lc($b->{name}//'') } @{$entByLayer{$num}||[]};
  my $chips = join("\n        ", map { ent_chip($_) } @all);
  return
  '<div class="layer-row" data-layer="'.$num.'">'."\n".
  '      <div class="layer-main">'."\n".
  '        <span class="layer-badge"><span class="layer-ico"><svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.3">'.$LICO{$num}.'</svg></span><b>'.sprintf("%02d",$num).'</b></span>'."\n".
  '        <div class="layer-info"><div class="layer-title">'.$title.'</div><div class="layer-desc">'.$desc.'</div></div>'."\n".
  '        <div class="layer-logos">'.$flog.'</div>'."\n".
  '        <button class="layer-more" type="button" aria-expanded="false">More <span class="arw">→</span></button>'."\n".
  '      </div>'."\n".
  '      <div class="layer-expand">'."\n".
  '        '.$chips."\n".
  '      </div>'."\n".
  '    </div>';
}
my $rows = join("\n    ", map { layer_row($_) } @LAYERS);
my $eco = slurp("redesign/pages/ecosystem.html");
$eco =~ s/\{\{LAYER_ROWS\}\}/    $rows/;
render_page(out=>"ecosystem.html", active=>"ecosystem",
  title=>"Ecosystem — The Football Ledger",
  desc=>"The nine-layer map of football's business — governance, leagues, clubs, capital, agencies, media, commercial, football-tech and stadium — with the key entities in each layer.",
  canonical=>"/ecosystem", body=>$eco);

print "done.\n";
