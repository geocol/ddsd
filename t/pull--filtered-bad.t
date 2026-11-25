use strict;
use warnings;
use Path::Tiny;
use JSON::PS;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = 'filtered_bad_' . rand;
  my $upkey = 'up_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'no_such_filter',
        upstream_file_key => 'file',
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
      # Should fail or have error
      is $r->{exit_code}, 12, 'exit code is 12 for bad filter';
    } $current->c;
  });
} n => 1, name => 'pull filtered bad filter';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
