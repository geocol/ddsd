use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        files => {
          "package" => {},
          "file:id:r1" => {},
          "file:id:r2" => {},
        },
        skip_other_files => 1,
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1"},
              {id => "r2", url => "http://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1" => {text => "r1"},
      "http://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => 'local/data/foo/package-ckan.json', json => sub { }},
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', is_none => 1},
    ]);
  });
} n => 5, name => 'skipped a resource';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        files => {
          "file:id:r1" => {},
          "file:id:r2" => {},
        },
        skip_other_files => 1,
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1"},
              {id => "r2", url => "http://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1" => {text => "r1"},
      "http://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', is_none => 1},
      {path => 'local/data/foo/package-ckan.json', is_none => 1},
      {path => 'local/data/foo/files/r1', is_none => 1},
      {path => 'local/data/foo/files/r2', is_none => 1},
      {path => 'local/data/foo/files/r3', is_none => 1},
    ]);
  });
} n => 2, name => 'skipped a package';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
