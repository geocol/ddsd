use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (undef,
    {
      "https://hoge/dataset/$key" => {
        text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/" hoge="">},
      },
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
              {id => 'bar', url => "https://hoge/$key/bar"},
            ],
          },
        },
      },
      "https://hoge/$key/foo" => {text => "abc"},
      "https://hoge/$key/bar" => {text => "xyz", status => 404},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/dataset/$key", '--name', "hoge"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         my $def = $json->{hoge};
         ok ! $def->{files}->{"file:id:foo"}->{skip};
         ok $def->{files}->{"file:id:bar"}->{skip};
         ok ! $def->{files}->{"package"}->{skip};
         ok ! $def->{files}->{"meta:ckan.json"}->{skip};
         ok ! $def->{files}->{"meta:activity.html"}->{skip};
       }},
    ]);
  });
} n => 7, name => 'skip by http error';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
