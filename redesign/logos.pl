use strict; use warnings;
use File::Copy qw(copy);
sub slurp { my ($f)=@_; open(my $fh,'<:raw',$f) or die "$f: $!"; local $/; my $c=<$fh>; close $fh; return $c; }
sub norm { my $s=lc(shift//''); $s =~ s/[^a-z0-9]//g; return $s; }

# entities from content.json
my $cj = slurp("content.json");
my @ents;
if ($cj =~ /"entities":\s*\[(.*?)\],\s*"briefings"/s) {
  my $b=$1;
  while ($b =~ /\{([^{}]*)\}/g) { my $o=$1; my %e; $e{slug}=$1 if $o=~/"slug":"([^"]*)"/; $e{name}=$1 if $o=~/"name":"([^"]*)"/; push @ents,\%e if $e{slug}; }
}
my (%byname,%byslug);
for my $e (@ents){ $byname{norm($e->{name})}=$e->{slug}; $byslug{norm($e->{slug})}=$e->{slug}; }

# manual overrides: normalized-logo-basename => entity slug
my %ov = (
  'img'=>'img','ssc'=>'ssc-shahid','shahid'=>'ssc-shahid','beinsports'=>'bein-sports',
  'kingdomholdingpartners'=>'kingdom-holding','qatarsportsinvestments'=>'qsi',
  'redbullfootball'=>'red-bull','thesoccertournamenttst'=>'the-soccer-tournament',
  'worldsevensfootballw7f'=>'world-sevens-football','riyadhairalulaneom'=>'riyadh-air-alula-neom',
  'thefa'=>'fa','independentfootballregulator'=>'ifr','opta'=>'stats-perform',
  'rocnation'=>'roc-nation-sports','wassermansports'=>'wasserman','legendshospitality'=>'legends',
  'redbirdcapitalpartners'=>'redbird','fenwaysportsgroup'=>'fsg','ineossport'=>'ineos-sport',
  'apolloglobalmanagement'=>'apollo','aresmanagement'=>'ares','arctospartners'=>'arctos',
  'cvccapitalpartners'=>'cvc','etihadairways'=>'etihad','oaktreecapital'=>'oaktree',
  'saudiproleague'=>'spl','rafaelapimenta'=>'pimenta','socioschiliz'=>'socios-chiliz',
);

my $SRC = "../thefootballledger-editorial/Changes to website/Entities/Logos";
my $DST = "assets/img/logos";
mkdir "assets/img" unless -d "assets/img";
mkdir $DST unless -d $DST;
opendir(my $dh,$SRC) or die "src $SRC: $!"; my @logos = grep { /\.png$/i } readdir($dh); closedir($dh);
my (%done,@gaps);
for my $f (sort @logos) {
  next if $f =~ /(Capital1|SSC1)\.png$/;   # duplicates
  (my $base=$f) =~ s/\.png$//i; $base =~ s/\s+$//;
  my $n = norm($base);
  my $slug = $ov{$n} // $byname{$n} // $byslug{$n};
  if ($slug) { copy("$SRC/$f","$DST/$slug.png") or warn "copy $f: $!"; $done{$slug}=1; }
  else { push @gaps,$f; }
}
my @noLogo = grep { !$done{$_->{slug}} } @ents;
print "entities total: ".scalar(@ents)."\n";
print "logos matched:  ".scalar(keys %done)."\n";
print "UNMATCHED LOGO FILES: ".(@gaps?join(" | ",@gaps):"none")."\n";
print "ENTITIES WITHOUT LOGO: ".(@noLogo?join(", ",map{$_->{slug}}@noLogo):"none")."\n";
