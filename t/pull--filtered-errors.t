use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

# bad source: missing source
Test {
  my $current = shift;
  my $key = 'fe_' . rand;
  return $current->prepare (
    { $key => { type => 'filtered', filter => 'strip_tags', upstream_file_key => 'file' } },
    {},
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 255, 'fails on missing source' } $current->c;
  });
} n => 1, name => 'filtered missing source';

# bad file_url
Test {
  my $current = shift;
  my $key = 'fe_' . rand;
  my $uk = 'u_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered', filter => 'strip_tags', upstream_file_key => 'file',
        file_url => '::::',
        source => { type => 'single', url => "https://hoge/$uk" },
      },
    },
    { "https://hoge/$uk" => {text => "<p>x</p>", mime => "text/html"} },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 255, 'fails on bad file_url' } $current->c;
  });
} n => 1, name => 'filtered bad file_url';

# unknown filter
Test {
  my $current = shift;
  my $key = 'fe_' . rand;
  my $uk = 'u_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered', filter => 'drop_all', upstream_file_key => 'file',
        source => { type => 'single', url => "https://hoge/$uk" },
      },
    },
    { "https://hoge/$uk" => {text => "<p>x</p>", mime => "text/html"} },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 12, 'fails on unknown filter' } $current->c;
  });
} n => 1, name => 'filtered unknown filter';

# missing filter
Test {
  my $current = shift;
  my $key = 'fe_' . rand;
  my $uk = 'u_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered', upstream_file_key => 'file',
        source => { type => 'single', url => "https://hoge/$uk" },
      },
    },
    { "https://hoge/$uk" => {text => "<p>x</p>", mime => "text/html"} },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 12, 'fails on missing filter' } $current->c;
  });
} n => 1, name => 'filtered missing filter';

# explicit file_url points to missing upstream item
Test {
  my $current = shift;
  my $key = 'fe_' . rand;
  my $uk = 'u_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered', filter => 'strip_tags', upstream_file_key => 'file',
        file_url => "https://hoge/$uk-missing",
        source => { type => 'single', url => "https://hoge/$uk" },
      },
    },
    { "https://hoge/$uk" => {text => "<p>x</p>", mime => "text/html"} },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 12, 'fails on missing upstream item for file_url' } $current->c;
  });
} n => 1, name => 'filtered missing upstream item by file_url';



# upstream 404
Test {
  my $current = shift;
  my $key = 'fe_' . rand;
  my $uk = 'u_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered', filter => 'strip_tags', upstream_file_key => 'file',
        source => { type => 'single', url => "https://hoge/$uk" },
      },
    },
    { "https://hoge/$uk" => {status => 404, text => ""} },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 12, 'fails on upstream 404' } $current->c;
  });
} n => 1, name => 'filtered upstream 404';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
