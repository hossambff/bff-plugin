#!/usr/bin/perl
# Remove former BFF team members from Brain pages, in place.
#   scrub-former.pl TEAM_JSON FILE...
# Names and aliases come from "former_members" in team.json. Owners/leads become
# "unassigned", "<name> to Follow-Up" becomes "Follow-Up (unassigned)", and any
# other mention is attributed to "BFF". Prints the files it changed.
use strict; use warnings; use JSON::PP;

my $team = shift @ARGV or die "usage: scrub-former.pl TEAM_JSON FILE...\n";
open(my $tf, '<', $team) or die "cannot read $team\n";
my $json = do { local $/; <$tf> }; close $tf;
my $former = (decode_json($json)->{former_members}) || [];
my %seen; my @names = grep { defined && length && !$seen{$_}++ }
  map { ($_->{name}, @{ $_->{aliases} || [] }) } @$former;
exit 0 unless @names;
@names = sort { length($b) <=> length($a) } @names;     # longest first: full names before their aliases
my %is_former = map { $_ => 1 } @names;
# "Mac" is also a computer: leave "Mac app", "Mac users" etc. alone.
my $N = join '|', map { $_ eq 'Mac' ? 'Mac(?!\s+(?:app|apps|desktop|computer|mini|Pro|Studio|users?|version|client|App Store)\b)' : quotemeta } @names;

local $/;
for my $file (@ARGV) {
  next unless -f $file;
  open(my $fh, '<', $file) or next; my $s = <$fh>; close $fh;
  my $o = $s;
  $s =~ s/^(bff_owner:\s*)"?(?:$N)"?[ \t]*$/$1"unassigned"/mg;
  $s =~ s{^(bff_leads:[ \t]*)\[(.*)\][ \t]*$}{
    my ($k, $l) = ($1, $2);
    my @keep = grep { my $x = $_; $x =~ s/^\s+|\s+$//g; $x =~ s/^"|"$//g; !$is_former{$x} } grep { /\S/ } split /,/, $l;
    s/^\s+|\s+$//g for @keep;
    $k . '[' . join(', ', @keep) . ']'
  }mge;
  $s =~ s/^- Lead analyst: (?:$N)[ \t]*\n//mg;
  $s =~ s/\b(?:$N) to Follow-Up\b/Follow-Up (unassigned)/g;
  $s =~ s/^(- \[ \] )(?:$N)( — )/$1unassigned$2/mg;
  $s =~ s/relationship owner: (?:$N)\b/relationship owner: unassigned/g;
  $s =~ s/\b(?:$N)\b/BFF/g;
  $s =~ s/, BFF and BFF/ and BFF/g; $s =~ s/BFF (?:and|&) BFF/BFF/g; $s =~ s/BFF, BFF/BFF/g; $s =~ s/BFF BFF/BFF/g;
  if ($s ne $o) { open(my $out, '>', $file) or die; print $out $s; close $out; print "$file\n"; }
}
