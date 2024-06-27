use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

for my $args (
  ['hoge', 'fuga'],
  ['--hoge', 'fuga'],
  ['hoge', '--fuga'],
  ['foo', ''],
  ['', 'foo'],
  ['--foobar'],
) {
  Test {
    my $current = shift;
    return $current->prepare (undef, {})->then (sub {
      return $current->run ('ls', additional => $args);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
      } $current->c;
      return $current->check_files ([
        {path => 'config', is_none => 1},
        {path => 'local', is_none => 1},
      ]);
    });
  } n => 2, name => ['ls bad arguments', @$args];
} # $args

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('ls', lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{lines}}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config', is_none => 1},
      {path => 'local', is_none => 1},
    ]);
  });
} n => 3, name => 'ls empty';

Test {
  my $current = shift;
  return $current->prepare (
    undef,
    {},
    files => {
      "local/data/foo/abc" => {text => ""},
      "local/data/bar/abc" => {text => ""},
      "local/data/bac" => {text => ""},
    },
  )->then (sub {
    return $current->run ('ls', lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{lines}}, 2;
      my $lines = [sort { $a cmp $b } @{$r->{lines}}];
      like $lines->[0], qr{^bar\t};
      like $lines->[1], qr{^foo\t};
    } $current->c;
    return $current->check_files ([
      {path => 'config', is_none => 1},
      {path => 'local/repo', is_none => 1},
    ]);
  });
} n => 5, name => 'ls has directories';

Test {
  my $current = shift;
  return $current->prepare (
    undef,
    {},
    files => {
      "local/data/foo/abc" => {text => ""},
      "local/data/bar/abc" => {text => ""},
      "local/data/baz/abc" => {text => "", code => sub {
                                 chmod 0000, $_[0]->parent;
                               }},
      "local/data/bac" => {text => ""},
    },
  )->then (sub {
    return $current->run ('ls', lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{lines}}, 3;
      my $lines = [sort { $a cmp $b } @{$r->{lines}}];
      like $lines->[0], qr{^bar\t};
      like $lines->[1], qr{^baz\t};
      like $lines->[2], qr{^foo\t};
    } $current->c;
    return $current->check_files ([
      {path => 'config', is_none => 1},
      {path => 'local/repo', is_none => 1},
    ]);
  });
} n => 6, name => 'has unreadable directory';

Test {
  my $current = shift;
  return $current->prepare (
    undef,
    {},
    files => {
      "local/data/foo/abc" => {text => ""},
      "local/data/bar/abc" => {text => ""},
      "local/data/bac" => {text => ""},
    },
    post => sub {
      chmod 0000, $_[0]->child ('local/data');
    },
  )->then (sub {
    return $current->run ('ls', lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{lines}}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config', is_none => 1},
      {path => 'local/repo', is_none => 1},
    ]);
  });
} n => 3, name => 'data area is unreadable';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
