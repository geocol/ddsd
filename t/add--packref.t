use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/abc/dataset/$key",
          },
        },
      },
      "https://hoge/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "https://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.json"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
         ok ! $json->{items}->{package}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", text => "r2"},
      {path => "local/data/$key/files/r3", text => "r3"},
    ]);
  });
} n => 9, name => 'ok';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/abc/dataset/$key",
            files => {
              "file:r:3" => {url => "https://hoge/" . $key . "/r3"},
            },
          },
        },
      },
      "https://hoge/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.json"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
         ok ! $json->{items}->{package}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", text => "r2"},
      {path => "local/data/$key/files/r3", text => "r3"},
    ]);
  });
} n => 9, name => 'additional file';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
