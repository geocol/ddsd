use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config', is_none => 1},
      {path => 'local/data', is_none => 1},
      {path => 'local/ddsd/data/legal/index.json', json => sub {
        my $json = shift;
      }},
    ]);
  });
} n => 2, name => 'pull nop';

Test {
  my $current = shift;
  return $current->prepare (
    {},
    {},
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data', is_none => 1},
    ]);
  });
} n => 2, name => 'pull empty packages';

Test {
  my $current = shift;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name',
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name" => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
        },
      },
      "http://hoge/dataset/activity/package-name" => {
        text => "a",
      },
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
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{'meta:ckan.json'};
         ok $json->{items}->{'meta:activity.html'};
       }},
      {path => "local/data/foo/package/package.ckan.json", json => sub {}},
      {path => "local/data/foo/package/activity.html", text => sub {}},
    ]);
  });
} n => 7, name => 'pull has packages';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
