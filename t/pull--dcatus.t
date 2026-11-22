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
    return $current->run ('pull')->then (sub { [$repo_root, $_[0]] });
  })->then (sub {
    my ($repo_root, $r) = @{$_[0]};
    test {
      is $r->{exit_code}, 0;
      ok $repo_root->is_dir;
    } $current->c;
  });
 } n => 3, name => 'pull dcatus fetches upstream when missing';

Test {
  my $current = shift;
  my $key = '5b39df6ec10146909b72240e9bf300b0';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$key";
  my $feed_url = "https://hoge/api/feed/dcat-us/1.1.json";
  my $dist_url = "https://hoge/data/file1.csv.zip";
  my $landing_url = "https://hoge/documents/$key";
  my $landing1 = qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head><body>v1</body></html>};
  my $landing2 = qq{<html><head><link rel="stylesheet" href="https://hubcdn.arcgis.com/foo.css"></head><body>v2</body></html>};
  return $current->prepare (undef, {
    $landing_url => {text => $landing1},
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
  })->then (sub {
    return $current->run ('add', additional => [$landing_url]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         ok $json->{items}->{'meta:landing.html'};
         ok $json->{items}->{'meta:dcat-us.json'};
         $current->set_o (landing_sha1 => $json->{items}->{'meta:landing.html'}->{rev}->{sha256});
         $current->set_o (pkg_sha1 => $json->{items}->{'meta:dcat-us.json'}->{rev}->{sha256});
       }},
      {path => "local/data/$key/package/landing.html", text => sub {
         my $text = shift;
         ok index($text, 'v1') >= 0;
       }},
    ]);
  })->then (sub {
    # Update landing HTML only; snapshot hash should not change (like CKAN activity.html)
    return $current->prepare (undef, {
      $landing_url => {text => $landing2},
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
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0 } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         ok $json->{items}->{'meta:landing.html'};
         isnt $json->{items}->{'meta:landing.html'}->{rev}->{sha256}, $current->o ('landing_sha1');
         is $json->{items}->{'meta:dcat-us.json'}->{rev}->{sha256}, $current->o ('pkg_sha1');
       }},
      {path => "local/data/$key/package/landing.html", text => sub {
         my $text = shift;
         ok index($text, 'v2') >= 0;
       }},
    ]);
  });
} n => 12, name => 'pull dcatus landing html';

Run;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
