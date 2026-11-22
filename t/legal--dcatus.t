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
  my $landing_url = "https://hoge/dataset.address-br.digital.go.jp/documents/$key";
  return $current->prepare (undef, {
    "https://hoge/documents/$key" => {
      text => qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head></html>},
    },
    $landing_url => {
      text => qq{<html><head></head><body></body></html>},
    },
    $feed_url => {
      json => {
        dataset => [
          {
            identifier => $ds_id,
            landingPage => $landing_url,
            title => "地番マスター1",
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
      {
        my ($l) = grep { $_->{key} eq '-ddsd-dcatus-dataset' } @lic;
        is $l->{type}, 'license';
        is $l->{key}, '-ddsd-dcatus-dataset';
        is $l->{source_type}, 'package';
        is $l->{source_url}, $feed_url;
        is $l->{extracted_url} => "https://www.geospatial.jp/ckan/dataset/houmusyouchizu-riyoukiyaku/resource/47871bf1-4c85-48f7-a8fe-b27c6643c1c5";
        use utf8;
        is $l->{notes}, "地番マスター1";
        is $l->{is_free}, 'unknown';
      }
      is $item->{is_free}, 'unknown';
    } $current->c;
  });
 } n => 16, name => 'digital.go.jp cannot understand what "license" is';

Test {
  my $current = shift;
  my $key = '5b39df6ec10146909b72240e9bf300b0';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge/api/feed/dcat-us/1.1.json";
  my $dist_url = "https://hoge/data/file1.csv.zip";
  my $landing_url = "https://hoge/documents/$key";
  my $terms_url = "https://hoge/terms";
  my $landing_html = q{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head><body><script>var a="%7B%22licenseInfo%22%3A%22%3Ca%20href%3D%5C%22https%3A%2F%2Fhoge%2Fterms%5C%22%3E%E5%88%A9%E7%94%A8%E8%A6%8F%E7%B4%84%3C%2Fa%3E%22%7D";</script></body></html>};
  return $current->prepare (undef, {
    $landing_url => {text => $landing_html},
    $terms_url => {text => q{<html><body>Terms</body></html>}},
    $feed_url => {
      json => {
        dataset => [
          {
            identifier => $ds_id,
            landingPage => $landing_url,
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
    return $current->run ('add', additional => [$landing_url]);
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
      my @terms = grep { $_->{type} eq 'site_terms' } @{$item->{legal} || []};
      is 0+@terms, 1;
      {
        my $l = $terms[0];
        is $l->{key}, '-ddsd-unknown';
        is $l->{source_type}, 'site';
        is $l->{source_url}, $terms_url;
        ok 0+@{$l->{timestamps}};
        is $l->{type}, 'site_terms';
        is $l->{is_free}, 'unknown';
      }
    } $current->c;
  });
} n => 10, name => 'dcatus landing page site terms sniffed';

Run;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
