package FileNames;
use strict;
use warnings;
use Web::Encoding;
use Web::Encoding::Normalization;

use _CharClasses;

sub is_free_file_name ($) {
  my $s = $_[0];

  return 0 if not defined $s;
  return 0 if $s eq "";
  return 0 if 127 < length $s;

  return 0 if $s =~ /[^\x{0000}-\x{10FFFF}]/;
  return 0 if $s =~ /[\x00-\x2C\x2F\x3A-\x40\x5B-\x5E\x60\x7B-\x9F]/;
  return 0 if $s =~ /\p{InNotNameChar}/;
  return 0 if $s =~ /\A[-.\p{InNotNameStartChar}]/;
  return 0 if $s =~ /[\.\p{InNotNameEndChar}]\z/;
  return 0 if $s =~ /\p{InNotNameEndChar}\.[^.]+\z/;

  if (not $s =~ m{\x2E[0-9A-Za-z_]+\z} or
      $s =~ /\.(?:[Ll][Nn][Kk]|[Uu][Rr][Ll]|[Pp][Ii][Ff]|[Ss][Cc][Ff])\z/) {
    return 0 if $s =~ /\./;
  }

  ## <https://wiki.suikawiki.org/n/%E7%89%B9%E6%AE%8A%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E5%90%8D>
  my $t = $s;
  $t =~ tr/A-Z/a-z/;
  return 0 if {
    'desktop.ini' => 1,
    'thumbs.db' => 1,
    'autorun.inf' => 1,
    'cvs' => 1,
    'meta-inf' => 1,
    '_FOSSIL_' => 1,
  }->{$t};
  $t =~ s/\..*//s;
  return 0 if {
    con => 1, prn => 1, aux => 1, nul => 1, com0 => 1, com1 => 1, com2 => 1,
    com3 => 1, com4 => 1, com5 => 1, com6 => 1, com7 => 1, com8 => 1,
    com9 => 1, "com\xB9" => 1, "com\xB2" => 1, "com\xB3" => 1, lpt0 => 1,
    lpt1 => 1, lpt2 => 1, lpt3 => 1, lpt4 => 1, lpt5 => 1, lpt6 => 1,
    lpt7 => 1, lpt8 => 1, lpt9 => 1, "lpt\xB9" => 1, "lpt\xB2" => 1,
    "lpt\xB3" => 1,
  }->{$t};

  $s = decode_web_utf8 encode_web_utf8 $s;
  return 0 if not $s eq $_[0];

  return 1;
} # is_free_file_name

sub escape_file_name ($) {
  my $name = shift;
  $name = decode_web_utf8 encode_web_utf8 $name;
  $name =~ s{([\x00-\x2C\x2F\x3A-\x40\x5B-\x5E\x60\x7B-\x7F]|\A[\x2D\x2E]|\x2E\z)}{_}g;
  $name =~ s{\p{InNotNameChar}}{_}g;
  if (not $name =~ m{\x2E[0-9A-Za-z_]+\z} or
      $name =~ /\.(?:[Ll][Nn][Kk]|[Uu][Rr][Ll]|[Pp][Ii][Ff]|[Ss][Cc][Ff])\z/) {
    $name =~ s/\x2E/_/g;
  }
  $name =~ s{\A\p{InNotNameStartChar}}{_};
  $name =~ s{\p{InNotNameEndChar}\z}{_};
  $name =~ s{\p{InNotNameEndChar}(?=\.[^.]+\z)}{_};
  return $name;
} # escape_file_name

sub truncate_file_name ($) {
  my $name = shift;
  return substr $name, 0, 120;
} # truncate_file_name

sub normalize_for_duplicate_check ($) {
  return to_nfc lc uc lc $_[0];
} # normalize_for_duplicate_check

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
