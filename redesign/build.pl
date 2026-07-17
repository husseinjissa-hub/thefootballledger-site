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
  return
  '<a class="acard" href="'.esc($a->{url}).'">'."\n".
  '      <div class="acard-tags"><span class="acard-cat">'.esc(uc $a->{type}).'</span>'.$pill.$theme.'</div>'."\n".
  '      <div class="acard-title">'.esc($a->{title}).'</div>'."\n".
  '      <div class="acard-media img-ph"><span>Image</span></div>'."\n".
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

print "done.\n";
