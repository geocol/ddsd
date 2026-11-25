use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = 'unf_' . rand;
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
    { "https://hoge/$uk" => {text => "<p>X</p>", mime => "text/html"} },
  )->then (sub {
    return $current->run ('use', additional => [$key, 'file']);
  })->then (sub {
    my $r = $_[0]; test { is $r->{exit_code}, 0, 'use ok' } $current->c;
    return $current->run ('unuse', additional => [$key, 'file']);
  })->then (sub {
    my $r = $_[0]; test { is $r->{exit_code}, 0, 'unuse ok' } $current->c;
    # after unuse, file should be skipped in packages.json
    my $pkg = json_bytes2perl $current->app_path(0)->child('config/ddsd/packages.json')->slurp;
    test { ok $pkg->{$key}->{files}->{file}->{skip}, 'file skipped in packages' } $current->c;
  });
} n => 3, name => 'unuse filtered single';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
