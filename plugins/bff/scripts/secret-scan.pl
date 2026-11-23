#!/usr/bin/perl
# BFF Brain secret scanner.
#   secret-scan.pl FILE...          report findings, exit 1 if any (used by the git pre-commit hook)
#   secret-scan.pl --fix FILE...    redact findings in place, report them, exit 0 (used by unattended jobs)
use strict; use warnings;

my $fix = 0;
if (@ARGV && $ARGV[0] eq '--fix') { $fix = 1; shift @ARGV; }

my @rules = (
  [ 'private key block',   qr/-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|\z)/ ],
  [ 'AWS access key',      qr/\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/ ],
  [ 'GitHub token',        qr/\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{50,})\b/ ],
  [ 'Anthropic API key',   qr/\bsk-ant-[A-Za-z0-9_\-]{20,}/ ],
  [ 'OpenAI API key',      qr/\bsk-(?:proj-)?[A-Za-z0-9_\-]{32,}/ ],
  [ 'Slack token',         qr/\bxox[abprs]-[A-Za-z0-9\-]{10,}/ ],
  [ 'Google API key',      qr/\bAIza[0-9A-Za-z_\-]{35}\b/ ],
  [ 'Stripe live key',     qr/\b(?:sk|rk)_live_[0-9A-Za-z]{20,}\b/ ],
  [ 'Telegram bot token',  qr/\b\d{8,10}:AA[A-Za-z0-9_\-]{33}\b/ ],
  [ 'Notion/Airtable token', qr/\b(?:secret_[A-Za-z0-9]{43}|ntn_[A-Za-z0-9]{40,}|pat[A-Za-z0-9]{14}\.[a-f0-9]{64})\b/ ],
  [ 'crypto private key',  qr/(?i:priv(?:ate)?[ _-]?key|secret[ _-]?key|privkey)[^\n]{0,40}?\b(?:0x)?[0-9a-fA-F]{64}\b/ ],
  [ 'seed phrase',         qr/(?i:seed|mnemonic|recovery phrase|secret phrase)[^\n]{0,30}?(?:\b[a-z]{3,8}\b[ ,]+){11,23}\b[a-z]{3,8}\b/ ],
  [ 'password assignment', qr/(?i:\bpass(?:word|wd)?\s*[:=]\s*)["']?[^\s"'`]{6,}/ ],
);

my $found = 0;
for my $file (@ARGV) {
  next unless -f $file;
  open(my $fh, '<', $file) or next;
  local $/; my $text = <$fh>; close $fh;
  my $orig = $text;
  for my $r (@rules) {
    my ($name, $re) = @$r;
    while ($text =~ /$re/g) {
      my $line = 1 + (() = substr($text, 0, $-[0]) =~ /\n/g);
      print "$file:$line: $name\n";
      $found++;
    }
    $text =~ s/$re/[REDACTED-SECRET]/g if $fix;
  }
  if ($fix && $text ne $orig) {
    open(my $out, '>', $file) or die "cannot write $file";
    print $out $text; close $out;
  }
}
if ($found && !$fix) {
  print STDERR "\nBFF Brain: $found possible secret(s) found — commit blocked.\nRemove them (and rotate any real key). If it's a false positive, rephrase it.\n";
  exit 1;
}
exit 0;
