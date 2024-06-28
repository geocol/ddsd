use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key/" => {
        text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/" xxx="">},
      },
      "https://hoge/$key/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key/"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/hoge/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{'file:package_list.json'};
         ok $json->{items}->{'file:index.html'};
       }},
      {path => "local/data/hoge/files/package_list.json", json => sub {
         my $json = shift;
         ok $json->{success};
         is ref $json->{result}, 'ARRAY';
         is 0+@{$json->{result}}, 2;
         is $json->{result}->[0], 'abc';
         is $json->{result}->[1], 'def';
       }},
    ]);
  });
} n => 10, name => 'package list';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key/" => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://hoge/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key/"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/hoge/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 1;
         ok $json->{items}->{'file:package_list.json'};
       }},
      {path => "local/data/hoge/files/package_list.json", json => sub {
         my $json = shift;
         ok $json->{success};
         is ref $json->{result}, 'ARRAY';
         is 0+@{$json->{result}}, 2;
         is $json->{result}->[0], 'abc';
         is $json->{result}->[1], 'def';
       }},
    ]);
  });
} n => 9, name => 'package list (root URL missing)';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    undef,
    {
      "https://hoge.xn--4gq/$key/" => {
        text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge.xn--4gq/$key/" xxx="">},
      },
      "https://hoge.xn--4gq/$key/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge.%E4%B8%80/$key/"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/hoge.xn--4gq/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{'file:index.html'};
         ok $json->{items}->{'file:package_list.json'};
       }},
      {path => "local/data/hoge.xn--4gq/files/package_list.json", json => sub {
         my $json = shift;
         ok $json->{success};
         is ref $json->{result}, 'ARRAY';
         is 0+@{$json->{result}}, 2;
         is $json->{result}->[0], 'abc';
         is $json->{result}->[1], 'def';
       }},
    ]);
  });
} n => 10, name => 'escaped name';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key/" => {
        text => qq{<link rel="shortcut icon" href="/base/images/ckan.ico" /><body data-site-root="https://hoge/$key/" xxx="">},
      },
      "https://hoge/$key/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key/"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/hoge/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{'file:index.html'};
         ok $json->{items}->{'file:package_list.json'};
       }},
      {path => "local/data/hoge/files/package_list.json", json => sub {
         my $json = shift;
         ok $json->{success};
         is ref $json->{result}, 'ARRAY';
         is 0+@{$json->{result}}, 2;
         is $json->{result}->[0], 'abc';
         is $json->{result}->[1], 'def';
       }},
    ]);
  });
} n => 10, name => 'no generator meta';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key/dataset" => {
        text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/" xxx="">},
      },
      "https://hoge/$key/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key/dataset"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/hoge/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 1;
         ok $json->{items}->{'file:package_list.json'};
       }},
    ]);
  });
} n => 4, name => 'page url';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
