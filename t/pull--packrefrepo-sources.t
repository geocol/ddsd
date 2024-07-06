use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 0;
       }},
    ]);
  });
} n => 5, name => 'ckan, no source URL';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge:fuga",
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 0;
       }},
    ]);
  });
} n => 5, name => 'ckan, broken source URL';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "javascript://hoge:fuga",
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 0;
       }},
    ]);
  });
} n => 5, name => 'ckan, bad source URL scheme';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
