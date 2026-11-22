use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = '5b39df6ec10146909b72240e9bf300b0';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge/api/feed/dcat-us/1.1.json";
  my $dist_url = "https://hoge/data/file1.csv.zip";
  my $upstream_pkg = 'upstream-feed';

  # App 0: create upstream mirrorzip containing only the feed.
  return $current->prepare ({
    $upstream_pkg => {
      type => 'single',
      url => $feed_url,
    },
  }, {
    $feed_url => {
      json => {
        dataset => [
          {
            identifier => $ds_id,
            landingPage => "https://hoge/documents/$key",
            title => 'Test Dataset',
            distribution => [
              { title => 'Data file', format => 'ZIP', mediaType => 'application/zip', accessURL => $dist_url },
            ],
          },
        ],
      },
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c, name => 'pull upstream';
    return $current->run ('export', additional => ['mirrorzip', $upstream_pkg, 'upstream.zip', '--json'], json => 1);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c, name => 'export upstream mirrorzip';

    # App 1: dcatus package, upstream feed unavailable, but upstream mirrorzip available via state.
    return $current->prepare ({
      dcatuspkg => {
        type => 'dcatus',
        source => { type => 'single', url => $feed_url },
        id => $ds_id,
      },
    }, {
      $feed_url => { status => 404, text => '' },
      $dist_url => { bytes => "PK\x03\x04fake" },
      "https://hoge/documents/$key" => {
        text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head></html>},
      },
      "https://hoge/mirror/upstream.zip" => {
        file => $current->app_path (0)->child ('upstream.zip'),
      },
    }, app => 1, files => {
      'local/ddsd/states/packages.json' => {
        text => qq{{"dcatuspkg":{"single":{"$feed_url":{"mirror_url":"https://hoge/mirror/upstream.zip"}}}}},
      },
    });
  })->then (sub {
    return $current->run ('pull', app => 1);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c, name => 'pull dcatus with upstream mirror only';
    return $current->run ('ls', additional => ['dcatuspkg', '--jsonl'], jsonl => 1, app => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok ref $r->{jsonl} eq 'ARRAY';
      my $items = $r->{jsonl} || [];
      ok @$items >= 2;
      is $items->[0]{type}, 'package';
    } $current->c, name => 'ls after pull';
  });
} n => 7, name => 'dcatus pull with upstream-only mirrorzip';

Run;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
