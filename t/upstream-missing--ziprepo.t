use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

my $mk = sub {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc.txt" => {text => "abc"},
      }},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    my $repo_root = $current->app_path (0)->child ('local/ddsd/repo/single');
    if ($repo_root->is_dir) {
      system ('chmod', '-R', 'u+w', $repo_root->stringify);
      $repo_root->remove_tree;
    }
    return $key;
  });
};

Test {
  my $current = shift;
  return $mk->($current)->then (sub {
    my $key = shift;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
      ok ref $r->{jsonl} eq 'ARRAY';
    } $current->c;
  });
} n => 3, name => 'ls zip without upstream does not crash';

Test {
  my $current = shift;
  return $mk->($current)->then (sub {
    my $key = shift;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { ok $r->{exit_code} == 0 || $r->{exit_code} == 12 } $current->c;
  });
} n => 2, name => 'pull zip without upstream does not crash';

Test {
  my $current = shift;
  return $mk->($current)->then (sub {
    my $key = shift;
    return $current->run ('export', additional => ['mirrorzip', $key, 'foo.zip']);
  })->then (sub {
    my $r = $_[0];
    test { isnt $r->{exit_code}, 0 } $current->c;
    return $current->check_files ([
      {path => 'foo.zip', is_none => 1},
    ]);
  });
} n => 3, name => 'export zip without upstream does not crash';

Test {
  my $current = shift;
  return $mk->($current)->then (sub {
    my $key = shift;
    return $current->run ('use', additional => [$key, '--all']);
  })->then (sub {
    my $r = $_[0];
    test { ok $r->{exit_code} == 0 || $r->{exit_code} == 12 } $current->c;
  });
 } n => 2, name => 'use zip without upstream does not crash';

Test {
  my $current = shift;
  return $mk->($current)->then (sub {
    my $key = shift;
    return $current->run ('freeze', additional => [$key]);
  })->then (sub {
    my $r = $_[0];
    test { ok $r->{exit_code} == 12 } $current->c;
  });
} n => 2, name => 'freeze zip without upstream does not crash';

Run;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
