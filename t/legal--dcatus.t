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
  return $current->prepare (undef, {
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
    $current->legal_url_prefix . 'websites.json' => {json => []},
  })->then (sub {
    return $current->run ('add', additional => ["https://hoge/documents/$key"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('legal', additional => [$key, '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      my $item = $r->{jsonl}->[0];
      ok ref $item->{legal} eq 'ARRAY';
      ok @{$item->{legal}} >= 1;
      is $item->{legal}->[-1]{type}, 'disclaimer';
      is $item->{legal}->[-1]{key}, '-ddsd-disclaimer';
    } $current->c;
  });
} n => 7, name => 'dcatus legal';

Test {
  my $current = shift;
  my $key = '5b39df6ec10146909b72240e9bf300b0';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge/api/feed/dcat-us/1.1.json";
  my $dist_url = "https://hoge/data/file1.csv.zip";
  return $current->prepare (undef, {
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
    $current->legal_url_prefix . 'websites.json' => {json => []},
  })->then (sub {
    return $current->run ('add', additional => ["https://hoge/documents/$key"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    my $repo_root = $current->app_path (0)->child ('local/ddsd/repo/single');
    if ($repo_root->is_dir) {
      system ('chmod', '-R', 'u+w', $repo_root->stringify);
      $repo_root->remove_tree;
    }
    return $current->run ('legal', additional => [$key, '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      ok $r->{exit_code} == 0 || $r->{exit_code} == 12;
      ok ref $r->{jsonl} eq 'ARRAY';
    } $current->c;
  });
} n => 3, name => 'legal dcatus without upstream does not crash';

Test {
  my $current = shift;
  my $key = '5b39df6ec10146909b72240e9bf300b0';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge/api/feed/dcat-us/1.1.json";
  my $dist_url = "https://hoge/data/file1.csv.zip";
  my $license_url = "https://example.org/license";
  return $current->prepare (undef, {
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
            license => $license_url,
            distribution => [
              { title => 'Data file', format => 'ZIP', mediaType => 'application/zip', accessURL => $dist_url },
            ],
          },
        ],
      },
    },
    $dist_url => {bytes => "PK\x03\x04fake"},
    $current->legal_url_prefix . 'websites.json' => {json => []},
  })->then (sub {
    return $current->run ('add', additional => ["https://hoge/documents/$key"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('legal', additional => [$key, '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      my $item = $r->{jsonl}->[0];
      my @lic = grep { $_->{type} eq 'license' } @{$item->{legal} || []};
      ok @lic >= 1;
      my ($l) = grep { $_->{key} eq '-ddsd-dcatus-license' } @lic;
      ok !!$l;
      is $l->{license_url}, $license_url if $l;
      is $l->{source_type}, 'package' if $l;
    } $current->c;
  });
} n => 7, name => 'dcatus legal with license';

Test {
  my $current = shift;
  my $key = '5b39df6ec10146909b72240e9bf300b0';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge/api/feed/dcat-us/1.1.json";
  my $dist_url = "https://hoge/data/file1.csv.zip";
  my $license_url = "https://example.org/license";
  return $current->prepare (undef, {
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
            license => $license_url,
            distribution => [
              { title => 'Data file', format => 'ZIP', mediaType => 'application/zip', accessURL => $dist_url },
            ],
          },
        ],
      },
    },
    $dist_url => {bytes => "PK\x03\x04fake"},
    $current->legal_url_prefix . 'websites.json' => {json => []},
    $current->legal_url_prefix . 'dcatus.json' => {
      json => [
        { url => $license_url, is => 'example-license' },
      ],
    },
    $current->legal_url_prefix . 'info.json' => {
      json => {
        'example-license' => { is_free => 'free' },
        '-ddsd-disclaimer' => { is_free => 'neutral' },
      },
    },
  })->then (sub {
    return $current->run ('add', additional => ["https://hoge/documents/$key"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('legal', additional => [$key, '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      my $item = $r->{jsonl}->[0];
      is 0+@{$item->{legal}}, 2;
      my @lic = grep { $_->{type} eq 'license' } @{$item->{legal} || []};
      my ($l) = grep { $_->{key} eq 'example-license' } @lic;
      ok !!$l;
      is $l->{is_free}, 'free' if $l;
      is $l->{source_type}, 'package' if $l;
      ok ! grep { $_->{key} eq '-ddsd-dcatus-license' } @lic;
      is $item->{is_free}, 'free';
    } $current->c;
  });
} n => 9, name => 'dcatus legal with matching license definition';

Test {
  my $current = shift;
  my $key = '5b39df6ec10146909b72240e9bf300b0';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge/api/feed/dcat-us/1.1.json";
  my $dist_url = "https://hoge/data/file1.csv.zip";
  my $license_url = "https://example.org/license";
  use utf8;
  return $current->prepare (undef, {
    "https://hoge/documents/$key" => {
      text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head></html>},
    },
    $feed_url => {
      json => {
        dataset => [
          {
            identifier => $ds_id,
            landingPage => "https://dataset.address-br.digital.go.jp/documents/$key",
            title => "地番マスター",
            license => $license_url,
            distribution => [
              { title => 'Data file', format => 'ZIP', mediaType => 'application/zip', accessURL => $dist_url },
            ],
          },
        ],
      },
    },
    $dist_url => {bytes => "PK\x03\x04fake"},
    $current->legal_url_prefix . 'websites.json' => {json => []},
    $current->legal_url_prefix . 'dcatus.json' => {
      json => [
        { url => $license_url, is => 'example-license' },
      ],
    },
    $current->legal_url_prefix . 'info.json' => {
      json => {
        'example-license' => { is_free => 'free' },
        '-ddsd-disclaimer' => { is_free => 'neutral' },
      },
    },
  })->then (sub {
    return $current->run ('add', additional => ["https://hoge/documents/$key"]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('legal', additional => [$key, '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      my $item = $r->{jsonl}->[0];
      is 0+@{$item->{legal}}, 3;
      my @lic = grep { $_->{type} eq 'license' } @{$item->{legal} || []};
      my ($l) = grep { $_->{key} eq 'example-license' } @lic;
      ok !!$l;
      is $l->{is_free}, 'free' if $l;
      is $l->{source_type}, 'package' if $l;
      ok ! grep { $_->{key} eq '-ddsd-dcatus-license' } @lic;
      is $item->{is_free}, 'unknown';
    } $current->c;
  });
} n => 9, name => 'digital.go.jp cannot understand what "license" is';

Run;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
