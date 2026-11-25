use strict;
use warnings;
use Path::Tiny;
use JSON::PS;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = 'filtered_missing_' . rand;
  my $upkey = 'up_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'nonexistent',
        source => {
          type => 'single',
          url => "https://hoge/$upkey",
        },
      },
    },
    {
      "https://hoge/$upkey" => {text => "<p>hi</p>", mime => "text/html"},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12, 'exit code is 12 for missing upstream file key';
    } $current->c;
  });
} n => 1, name => 'pull filtered missing key';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
