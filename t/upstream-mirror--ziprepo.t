use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = '' . rand;
  my $zip_url = "https://hoge/$key.zip";
  my $upstream_pkg = 'upstream-zip';

  # App 0: create upstream mirrorzip containing only the zip file.
  return $current->prepare ({
    $upstream_pkg => {
      type => 'single',
      url => $zip_url,
    },
  }, {
    $zip_url => {zip => {
      "abc.txt" => {text => "abc"},
    }},
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c, name => 'pull upstream';
    return $current->run ('export', additional => ['mirrorzip', $upstream_pkg, 'upstream.zip', '--json'], json => 1);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c, name => 'export upstream mirrorzip';

    # App 1: zip package, upstream zip unavailable, but upstream mirrorzip available via state.
    return $current->prepare ({
      zippkg => {
        type => 'zip',
        source => { type => 'single', url => $zip_url },
        file_url => $zip_url,
      },
    }, {
      $zip_url => { status => 404, text => '' },
      "https://hoge/mirror/upstream.zip" => {
        file => $current->app_path (0)->child ('upstream.zip'),
      },
    }, app => 1, files => {
      'local/ddsd/states/packages.json' => {
        text => qq{{"zippkg":{"single":{"$zip_url":{"mirror_url":"https://hoge/mirror/upstream.zip"}}}}},
      },
    });
  })->then (sub {
    return $current->run ('pull', app => 1);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c, name => 'pull zip with upstream mirror only';
    return $current->run ('ls', additional => ['zippkg', '--jsonl'], jsonl => 1, app => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok ref $r->{jsonl} eq 'ARRAY';
      my $items = $r->{jsonl} || [];
      ok @$items >= 2;
    } $current->c, name => 'ls after pull';
  });
} n => 6, name => 'zip pull with upstream-only mirrorzip';

Run;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
