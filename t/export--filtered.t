use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = 'exf_' . rand;
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
    { "https://hoge/$uk" => {text => "<p>Export</p><script>x</script>", mime => "text/html; charset=utf-8"} },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->run ('export', additional => ['mirrorzip', $key, 'out.zip']);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0, 'export ok' } $current->c;
    return $current->check_files ([
      {path => "out.zip", zip => sub {
         my $files = shift;
         ok $files->{"index.json"}->{central}->{byte_length}, 'has index.json';
         ok $files->{"LICENSE"}->{central}->{byte_length}, 'has LICENSE';
       }},
    ]);
  });
} n => 4, name => 'export filtered single mirrorzip';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
