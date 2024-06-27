package FileNames;
use strict;
use warnings;
use Web::Encoding;

sub is_free_file_name ($) {
  my $s = $_[0];

  return 0 if $s eq "";
  return 0 if 127 < length $s;

  return 0 if $s =~ /[\x00-\x2C\x2F\x3A-\x40\x5B-\x5E\x60\x7B-\xFF]/;
  return 0 if $s =~ /\A[-.]/;
  return 0 if $s =~ /\.\z/;

  $s = decode_web_utf8 encode_web_utf8 $s;
  return 0 if not $s eq $_[0];

  return 0 if $s =~ /[\x80-\x9F]/;

  return 1;
} # is_free_file_name

sub escape_file_name ($) {
  my $name = shift;
  $name = decode_web_utf8 encode_web_utf8 $name;
  $name =~ s{([\x00-\x2C\x2F\x3A-\x40\x5B-\x5E\x60\x7B-\x7F]|\A[\x2D\x2E]|\x2E\z)}{sprintf '_%02X', ord $1}ge;
  return $name;
} # escape_file_name

sub truncate_file_name ($) {
  my $name = shift;
  return substr $name, 0, 120;
} # truncate_file_name

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
