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
              distribution => [
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
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/package/package.dcat-us.json", json => sub {
         my $json = shift;
         is $json->{identifier}, $ds_id;
         is $json->{title}, 'Test Dataset';
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         ok $json->{items}->{'meta:dcat-us.json'};
       }},
    ]);
  });
 } n => 7, name => 'pull dcatus';

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
    my $repo_root = $current->app_path (0)->child ('local/ddsd/repo/single');
    if ($repo_root->is_dir) {
      system ('chmod', '-R', 'u+w', $repo_root->stringify);
      $repo_root->remove_tree;
    }
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      ok $r->{exit_code} == 12;
    } $current->c;
  });
} n => 2, name => 'pull dcatus without upstream does not crash';

Run;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
