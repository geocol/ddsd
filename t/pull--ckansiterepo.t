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
        type => 'ckansite',
        url => "https://hoge/$key/",
      },
    },
    {
      "https://hoge/$key/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/foo/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 1;
         ok $json->{items}->{'file:package_list.json'};
       }},
      {path => "local/data/foo/files/package_list.json", json => sub {
         my $json = shift;
         ok $json->{success};
         is ref $json->{result}, 'ARRAY';
         is 0+@{$json->{result}}, 2;
         is $json->{result}->[0], 'abc';
         is $json->{result}->[1], 'def';
       }},
      {path => $current->repo_path ('ckansite', "https://hoge/$key/") . "/index.json", json => sub {
         my $json = shift;
         is $json->{site}->{lang}, undef;
         is $json->{site}->{dir}, undef;
         is $json->{site}->{writing_mode}, undef;
       }},
    ]);
  });
} n => 12, name => 'package list';

Test {
  my $current = shift;
  return $current->prepare (
    {
      foo => {
        type => 'ckansite',
        url => "https://search.ckan.jp/",
      },
    },
    {
      "https://search.ckan.jp/backend/api/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/foo/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 1;
         ok $json->{items}->{'file:package_list.json'};
       }},
      {path => "local/data/foo/files/package_list.json", json => sub {
         my $json = shift;
         ok $json->{success};
         is ref $json->{result}, 'ARRAY';
         is 0+@{$json->{result}}, 2;
         is $json->{result}->[0], 'abc';
         is $json->{result}->[1], 'def';
       }},
    ]);
  });
} n => 9, name => 'package list, search.ckan.jp';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckansite',
        url => "https://hoge/$key/",
      },
    },
    {
      "https://hoge/$key/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
        status => 500,
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/foo/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 0;
       }},
      {path => "local/data/foo/files/package_list.json", is_none => 1},
    ]);
  });
} n => 3, name => 'list error';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckansite',
        url => "https://hoge/$key/",
      },
    },
    {
      "https://hoge/$key/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
      "https://hoge/$key/" => {
        text => q{abc},
      },
      "https://hoge/$key/about" => {
        text => q{xyz},
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/foo/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 3;
         ok $json->{items}->{'file:index.html'};
         ok $json->{items}->{'file:about.html'};
         ok $json->{items}->{'file:package_list.json'};
       }},
      {path => "local/data/foo/files/package_list.json", json => sub {
         my $json = shift;
         ok $json->{success};
         is ref $json->{result}, 'ARRAY';
         is 0+@{$json->{result}}, 2;
         is $json->{result}->[0], 'abc';
         is $json->{result}->[1], 'def';
       }},
      {path => "local/data/foo/files/index.html", text => "abc"},
      {path => "local/data/foo/files/about.html", text => "xyz"},
    ]);
  });
} n => 13, name => 'files';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
