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
        text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head><body></body></html>},
      },
      $feed_url => {
        json => {
          dataset => [
            {
              '@type' => 'dcat:Dataset',
              identifier => $ds_id,
              landingPage => "https://hoge/documents/$key",
              title => 'Test Dataset',
              description => 'desc',
              license => 'https://creativecommons.org/licenses/by/4.0',
              distribution => [
                {
                  '@type' => 'dcat:Distribution',
                  title => 'ArcGIS Hub Dataset',
                  format => 'Web Page',
                  mediaType => 'text/html',
                  accessURL => "https://hoge/documents/$key",
                },
                {
                  '@type' => 'dcat:Distribution',
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
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         ok $json->{$key};
         my $item = $json->{$key};
         is $item->{type}, 'dcatus';
         is $item->{id}, $ds_id;
         is $item->{source}->{type}, 'single';
         is $item->{source}->{url}, $feed_url;
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         ok $json->{items}->{'meta:dcat-us.json'};
         is $json->{items}->{'meta:dcat-us.json'}->{type}, 'meta';
         ok ! $json->{items}->{'meta:dcat-us.json'}->{rev}->{insecure};
       }},
      {path => "local/data/$key/package/package.dcat-us.json", json => sub {
         my $json = shift;
         is $json->{identifier}, $ds_id;
         is $json->{title}, 'Test Dataset';
       }},
    ]);
  });
} n => 13, name => 'added dcatus';

Test {
  my $current = shift;
  my $key1 = '11111111111111111111111111111111';
  my $key2 = '22222222222222222222222222222222';
  my $ds1 = "https://www.arcgis.com/home/item.html?id=$key1";
  my $ds2 = "https://www.arcgis.com/home/item.html?id=$key2";
  my $feed_url = "https://hoge/api/feed/dcat-us/1.1.json";
  my $dist1 = "https://hoge/data/f1.zip";
  my $dist2 = "https://hoge/data/f2.zip";
  return $current->prepare (
    undef,
    {
      "https://hoge/documents/$key1" => {
        text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head></html>},
      },
      "https://hoge/documents/$key2" => {
        text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head></html>},
      },
      $feed_url => {
        json => {
          dataset => [
            {
              identifier => $ds1,
              landingPage => "https://hoge/documents/$key1",
              title => 'D1',
              distribution => [{title => 'f1', format => 'ZIP', mediaType => 'application/zip', accessURL => $dist1}],
            },
            {
              identifier => $ds2,
              landingPage => "https://hoge/documents/$key2",
              title => 'D2',
              distribution => [{title => 'f2', format => 'ZIP', mediaType => 'application/zip', accessURL => $dist2}],
            },
          ],
        },
      },
      $dist1 => {bytes => "PK1"},
      $dist2 => {bytes => "PK2"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/documents/$key1"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('add', additional => ["https://hoge/documents/$key2"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is $json->{$key1}->{type}, 'dcatus';
         is $json->{$key1}->{source}->{url}, $feed_url;
         is $json->{$key2}->{type}, 'dcatus';
         is $json->{$key2}->{source}->{url}, $feed_url;
       }},
      {path => "local/data/$key1/package/package.dcat-us.json", json => sub {
         my $json = shift;
         is $json->{identifier}, $ds1;
         is $json->{title}, 'D1';
       }},
      {path => "local/data/$key2/package/package.dcat-us.json", json => sub {
         my $json = shift;
         is $json->{identifier}, $ds2;
         is $json->{title}, 'D2';
       }},
    ]);
  });
} n => 11, name => 'two datasets share feed upstream';

Run;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
