use strict;
use warnings;
use Path::Tiny;
BEGIN { $ENV{TEST_MAX_CONCUR} = 1 }
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

Test {
  my $current = shift;
  my $feed_url = "https://hoge/api/feed/dcat-us/1.1.json";
  return $current->prepare (undef, {
    $feed_url => {
      json => { dataset => [] },
    },
  })->then (sub {
    return $current->run ('add', additional => [$feed_url]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         my @keys = keys %$json;
         is 0+@keys, 1;
         my $k = $keys[0];
         is $json->{$k}->{type}, 'single';
         is $json->{$k}->{url}, $feed_url;
       }},
    ]);
  });
} n => 5, name => 'add dcatus feed without id becomes single';

Test {
  my $current = shift;
  my $top_url = "https://hoge/";
  my $feed_url = "https://hoge/api/feed/dcat-us/1.1.json";
  return $current->prepare (undef, {
    $top_url => {
      text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head><body></body></html>},
    },
    $feed_url => {
      json => { dataset => [] },
    },
  })->then (sub {
    return $current->run ('add', additional => [$top_url]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         my @keys = keys %$json;
         is 0+@keys, 1;
         my $k = $keys[0];
         is $json->{$k}->{type}, 'single';
         is $json->{$k}->{url}, $feed_url;
       }},
    ]);
  });
} n => 5, name => 'top page URL';

Test {
  my $current = shift;
  my $key = 'aabbccddeeff00112233445566778899';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge2/api/feed/dcat-us/1.1.json";
  my $dist_url = "https://hoge2/data/file1.csv";
  return $current->prepare (
    undef,
    {
      "https://hoge2/documents/$key" => {
        text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head><body></body></html>},
      },
      $feed_url => {
        json => {
          dataset => [
            {
              identifier => $ds_id,
              landingPage => "https://hoge2/documents/$key",
              title => 'Date test',
              modified => '2024-01-02T03:04:05Z',
              distribution => [
                {
                  title => 'Data file',
                  format => 'CSV',
                  mediaType => 'text/csv',
                  accessURL => $dist_url,
                  issued => '2023-01-01T00:00:00Z',
                },
              ],
            },
          ],
        },
      },
      $dist_url => {text => "a,b\nc,d\n"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge2/documents/$key"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      my @files = grep { $_->{type} eq 'file' } @{$r->{jsonl}};
      ok @files;
      is $files[0]->{package_item}->{file_time}, 1704164645;
    } $current->c;
  });
 } n => 4, name => 'modified/issued parsed as file_time';

Test {
  my $current = shift;
  my $key = 'bbccddee00112233445566778899aabb';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge3/api/feed/dcat-us/1.1.json";
  my $dist_url = "https://hoge3/data/\x{30C6}\x{30B9}\x{30C8}.csv";
  my $dup_url = "https://hoge3/data/dup.csv";
  return $current->prepare (
    undef,
    {
      "https://hoge3/documents/$key" => {
        text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head><body></body></html>},
      },
      $feed_url => {
        json => {
          dataset => [
            {
              identifier => $ds_id,
              landingPage => "https://hoge3/documents/$key",
              title => 'Dup/non-ASCII test',
              distribution => [
                {
                  title => 'nonascii',
                  format => 'CSV',
                  mediaType => 'text/csv',
                  accessURL => $dist_url,
                },
                {
                  title => 'dup1',
                  format => 'CSV',
                  mediaType => 'text/csv',
                  accessURL => $dup_url,
                },
                {
                  title => 'dup2',
                  format => 'CSV',
                  mediaType => 'text/csv',
                  accessURL => $dup_url,
                },
              ],
            },
          ],
        },
      },
      $dist_url => {text => "a\n"},
      $dup_url => {text => "b\n"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge3/documents/$key"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      my @files = grep { $_->{type} eq 'file' } @{$r->{jsonl}};
      is 0+@files, 3;
      my %by_key = map { $_->{key} => $_ } @files;
      ok $by_key{"file:url:https://hoge3/data/\x{30C6}\x{30B9}\x{30C8}.csv"};
      ok $by_key{"file:url:$dup_url"};
      ok $by_key{"file:index:3"};
    } $current->c;
  });
 } n => 5, name => 'dcatus file:url keys, non-ascii, duplicate -> file:index';

Test {
  my $current = shift;
  my $key = 'ccddeeff00112233445566778899aabb';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge4/api/feed/dcat-us/1.1.json";
  my $valid_url = "https://hoge4/data/ok.csv";
  return $current->prepare (
    undef,
    {
      "https://hoge4/documents/$key" => {
        text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head><body></body></html>},
      },
      $feed_url => {
        json => {
          dataset => [
            {
              identifier => $ds_id,
              landingPage => "https://hoge4/documents/$key",
              title => 'URL test',
              distribution => [
                {
                  title => 'relative',
                  format => 'CSV',
                  mediaType => 'text/csv',
                  accessURL => 'data/relative.csv',
                },
                {
                  title => 'invalid',
                  format => 'CSV',
                  mediaType => 'text/csv',
                  accessURL => 'http://[invalid',
                },
                {
                  title => 'valid',
                  format => 'CSV',
                  mediaType => 'text/csv',
                  accessURL => $valid_url,
                },
              ],
            },
          ],
        },
      },
      $valid_url => {text => "ok\n"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge4/documents/$key"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 12 } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      my @files = grep { $_->{type} eq 'file' } @{$r->{jsonl}};
      is 0+@files, 3;
      my %by_key = map { $_->{key} => $_ } @files;
      ok $by_key{"file:url:data/relative.csv"};
      ok $by_key{"file:url:http://[invalid"};
      ok $by_key{"file:url:$valid_url"};
    } $current->c;
  });
} n => 6, name => 'dcatus relative/invalid URLs listed, bad URL on fetch, valid kept';

Test {
  my $current = shift;
  my $key = 'ddeeff00112233445566778899aabbcc';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge5/api/feed/dcat-us/1.1.json";
  return $current->prepare (
    undef,
    {
      "https://hoge5/documents/$key" => {
        text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head><body></body></html>},
      },
      $feed_url => {
        json => {
          dataset => [
            {
              identifier => $ds_id,
              landingPage => "https://hoge5/documents/$key",
              title => 'Only bad URLs',
              distribution => [
                {
                  title => 'relative',
                  format => 'CSV',
                  mediaType => 'text/csv',
                  accessURL => 'data/relative.csv',
                },
                {
                  title => 'invalid',
                  format => 'CSV',
                  mediaType => 'text/csv',
                  downloadURL => 'http://[invalid',
                },
              ],
            },
          ],
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge5/documents/$key"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 12 } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      my @files = grep { $_->{type} eq 'file' } @{$r->{jsonl}};
      is 0+@files, 2;
      my %by_key = map { $_->{key} => $_ } @files;
      ok $by_key{"file:url:data/relative.csv"};
      ok $by_key{"file:url:http://[invalid"};
      my @pkgs = grep { $_->{type} eq 'package' } @{$r->{jsonl}};
      is 0+@pkgs, 1;
    } $current->c;
  });
 } n => 6, name => 'dcatus only invalid/relative URLs listed, fetch has_error';

Test {
  my $current = shift;
  my $key = 'eeff00112233445566778899aabbccdd';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge6/api/feed/dcat-us/1.1.json";
  return $current->prepare (
    undef,
    {
      "https://hoge6/documents/$key" => {
        text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head><body></body></html>},
      },
      $feed_url => {
        json => {
          dataset => [
            {
              identifier => $ds_id,
              landingPage => "https://hoge6/documents/$key",
              title => 'No URL',
              distribution => [
                {
                  title => 'no url',
                  format => 'CSV',
                  mediaType => 'text/csv',
                },
              ],
            },
          ],
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge6/documents/$key"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 12 } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      my @files = grep { $_->{type} eq 'file' } @{$r->{jsonl}};
      is 0+@files, 1;
      is $files[0]->{key}, 'file:index:1';
      is $files[0]->{source}, undef;
    } $current->c;
  });
} n => 5, name => 'dcatus distribution with no URL listed, fetch broken file';

Run;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
