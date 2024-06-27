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
      "https://hoge/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
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
      "https://hoge/" . $key . "/r3" => {text => "r3", redirect => "r4",
                                         status => 301},
      "https://hoge/" . $key . "/r4" => {text => "r4"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/abc/dataset/" . $key]);
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
       }},
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         my $def = $json->{$key};
         is $def->{files}->{"file:id:r3"}->{name}, "r4";
         is $def->{files}->{"file:id:r2"}->{name}, undef;
         is $def->{files}->{"file:id:r1"}->{name}, undef;
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", text => "r2"},
      {path => "local/data/$key/files/r3", is_none => 1},
      {path => "local/data/$key/files/r4", text => "r4"},
    ]);
  });
} n => 8, name => 'redirected';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
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
      "https://hoge/" . $key . "/r3" => {text => "r3", redirect => "r4/r2",
                                         status => 303},
      "https://hoge/" . $key . "/r4/r2" => {text => "r4"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/abc/dataset/" . $key]);
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
       }},
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         my $def = $json->{$key};
         is $def->{files}->{"file:id:r3"}->{name}, "r2-2";
         is $def->{files}->{"file:id:r2"}->{name}, "r2-1";
         is $def->{files}->{"file:id:r1"}->{name}, undef;
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2-1", text => "r2"},
      {path => "local/data/$key/files/r2-2", text => "r4"},
    ]);
  });
} n => 8, name => 'redirected with conflicting name';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
