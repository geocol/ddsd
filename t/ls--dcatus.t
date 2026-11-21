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
  return $current->prepare (
    undef,
    {
      "https://hoge/documents/$key" => {
        text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head></html>},
      },
      $feed_url => {
        json => {
          dataset => [
            {
              identifier => $ds_id,
              landingPage => "https://hoge/documents/$key",
              title => 'Test Dataset',
              description => 'desc',
              license => 'https://creativecommons.org/licenses/by/4.0',
              distribution => [
                {
                  title => 'ArcGIS Hub Dataset',
                  format => 'Web Page',
                  mediaType => 'text/html',
                  accessURL => "https://hoge/documents/$key",
                },
                {
                  title => 'Data file',
                  format => 'ZIP',
                  mediaType => 'application/zip',
                  accessURL => $dist_url,
                },
              ],
            },
          ],
        },
      },
      $dist_url => {bytes => "PK\x03\x04fake"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/documents/$key"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok 0+@{$r->{jsonl}} >= 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{title}, 'Test Dataset';
        is $item->{package_item}->{page_url}, "https://hoge/documents/$key";
        ok $item->{package_item}->{snapshot_hash};
      }
      {
        my $meta = [grep { $_->{key} eq 'meta:dcat-us.json' } @{$r->{jsonl}}]->[0];
        ok $meta;
        is $meta->{type}, 'meta';
        like $meta->{path}, qr{/local/data/\Q$key\E/package/package\.dcat-us\.json$};
        is $meta->{package_item}->{mime}, 'application/json';
        ok $meta->{rev}->{sha256};
      }
      {
        my @files = grep { $_->{type} eq 'file' } @{$r->{jsonl}};
        is 0+@files, 1;
        is $files[0]->{package_item}->{title}, 'Data file';
        is $files[0]->{source}->{url}, $dist_url;
      }
    } $current->c;
  });
 } n => 16, name => 'ls dcatus';

Test {
  my $current = shift;
  my $key = '5b39df6ec10146909b72240e9bf300b0';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge/api/feed/dcat-us/1.1.json";
  my $dist_url = "https://hoge/data/file1.csv.zip";
  return $current->prepare (
    undef,
    {
      "https://hoge/documents/$key" => {
        text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head></html>},
      },
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
      $dist_url => {bytes => "PK\x03\x04fake"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/documents/$key"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    # Remove upstream single repo so nested dcatus storage is unreachable via index.
    my $repo_root = $current->app_path (0)->child ('local/ddsd/repo/single');
    if ($repo_root->is_dir) {
      system ('chmod', '-R', 'u+w', $repo_root->stringify);
      $repo_root->remove_tree;
    }
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      # Should not crash; degraded result is acceptable.
      is $r->{exit_code}, 12;
      ok ref $r->{jsonl} eq 'ARRAY';
    } $current->c;
  });
} n => 3, name => 'ls dcatus without upstream does not crash';

Run;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
