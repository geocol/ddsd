use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run (undef);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
    } $current->c;
  });
} n => 1, name => 'no arguments';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('');
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
    } $current->c;
  });
} n => 1, name => 'bad subcommand';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('hoge');
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
    } $current->c;
  });
} n => 1, name => 'bad subcommand';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('--hoge');
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
    } $current->c;
  });
} n => 1, name => 'bad subcommand';

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
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull', additional => ['hoge']);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local', is_none => 1},
    ]);
  });
} n => 2, name => 'bad additional argument';

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
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull', additional => ['--hoge']);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local', is_none => 1},
    ]);
  });
} n => 2, name => 'bad additional option';

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
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('--hoge', additional => ['pull']);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local', is_none => 1},
    ]);
  });
} n => 2, name => 'bad additional option';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
