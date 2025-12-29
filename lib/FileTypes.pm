package FileTypes;
use strict;
use warnings;

my $MIMENormalize = {
  'application/json; charset=utf-8' => 'application/json',
  'application/x-zip-compressed' => 'application/zip',
  'binary/octet-stream' => 'application/octet-stream',
  'text/turtle; charset=utf-8' => 'text/turtle; charset=UTF-8',
};

sub normalize_mime_type_string ($) {
  my $m = $_[0];
  $m =~ s{\A([^;]+);\s*[Cc][Hh][Aa][Rr][Ss][Ee][Tt]=[Uu][Tt][Ff]-8\z}{$1; charset=utf-8};
  $m =~ s{^([^;\s]+)}{lc $1}e;
  $m = $MIMENormalize->{$m} // $m;
  return $m;
} # normalize_mime_type_string

sub remove_mime_type_parameters ($) {
  my $m = $_[0];
  $m =~ s{\s*;.*\z}{}gs;
  return $m;
} # remove_mime_type_parameters

1;

=head1 LICENSE

Copyright 2024-2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
