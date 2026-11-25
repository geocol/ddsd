use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

# filtered upstream of zip: filtered output is not a zip -> should error
Test {
  my $current = shift;
  my $key = 'faz_' . rand;
  my $uk = 'u_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'zip',
        file_path => 'file',
        source => {
          type => 'filtered',
          filter => 'strip_tags',
          upstream_file_key => 'file',
          source => { type => 'single', url => "https://hoge/$uk" },
        },
      },
    },
    { "https://hoge/$uk" => {text => "<p>not a zip</p>", mime => "text/html"} },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 12, 'fails because filtered output is not zip') } $current->c;
  });
} n => 1, name => 'filtered upstream of zip is error';

# filtered upstream of dcatus: filtered output is not a DCAT-US feed -> should error
Test {
  my $current = shift;
  my $key = 'fad_' . rand;
  my $uk = 'u_' . rand;
  my $ds_id = "https://hoge/dataset/$uk";
  return $current->prepare (
    {
      $key => {
        type => 'dcatus',
        id => $ds_id,
        source => {
          type => 'filtered',
          filter => 'strip_tags',
          upstream_file_key => 'file',
          source => { type => 'single', url => "https://hoge/$uk/feed.json" },
        },
      },
    },
    { "https://hoge/$uk/feed.json" => {text => "<p>not json</p>", mime => "text/html"} },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 12, 'fails because filtered output is not dcatus feed') } $current->c;
  });
} n => 1, name => 'filtered upstream of dcatus is error';

# unknown upstream type in filtered source
Test {
  my $current = shift;
  my $key = 'fau_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file',
        source => { type => 'nosuchtype', url => 'https://hoge/x' },
      },
    },
    {},
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 255, 'fails on unknown upstream type') } $current->c;
  });
} n => 1, name => 'filtered unknown upstream type';

# files type not allowed as normal upstream source
Test {
  my $current = shift;
  my $key = 'faf_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file',
        source => { type => 'files', files => {} },
      },
    },
    {},
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 255, 'fails on files upstream type') } $current->c;
  });
} n => 1, name => 'filtered files upstream type rejected';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
