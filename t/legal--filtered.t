use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = 'lf_' . rand;
  my $uk = 'u_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file',
        source => { type => 'single', url => "https://hoge/$uk" },
      },
    },
    { "https://hoge/$uk" => {text => "<p>Legal</p>", mime => "text/html"} },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->run ('legal', additional => [$key]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0, 'legal ok' } $current->c;
  });
} n => 1, name => 'legal filtered single';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
