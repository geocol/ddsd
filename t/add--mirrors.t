use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = "0geEGr42rewe4464Gee444";
  return $current->prepare ({
    hoge => {
      type => 'ckan',
      url => "https://2.hoge/dataset/$key",
    },
  }, {
    "https://2.hoge/dataset/$key" => {
      text => "x",
    },
    "https://2.hoge/dataset/activity/$key" => {
      text => "y",
    },
    "https://2.hoge/api/action/package_show?id=$key" => {
      text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc.txt"}]}} },
    },
    "https://hoge/$key/abc.txt" => {
      text => "abc",
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->run ('export', additional => ['mirrorzip', 'hoge', 'a.zip', '--json'], json => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare ({
      foo0 => {
        type => 'packref',
        url => "https://2.hoge/dataset/$key.packref",
      },
    }, {
      "https://2.hoge/dataset/$key.packref" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://2.hoge/dataset/$key",
            skip_other_files => 1,
            files => {
              package => {
                sha256 => "dbb997f2c34c915e733551336ba8a01e01a1265d1ddddb50181af37caca72246",
              },
              "package:activity.html" => {},
              "file:index:0" => {
                sha256 => "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
              },
            },
          },
        },
      },
      "https://2.hoge/" => {
        text => "x",
      },
      "https://hoge/$key/abc.txt" => {
        text => "ABC",
      },
      "https://2.hoge/api/action/package_show?id=$key" => {
        text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc.txt"}]}} },
      },
      $current->mirrors_url_prefix . 'hash-ckan-2.hoge.jsonl' => {
        jsonl => [
          ["904a4013cee2be0fc0f575bbe7ac97ec5da7b56eccad2e19257e6ca91d9fd823",
           "https://2.hoge/$key/hash1.zip",
           $r->{json}->{sha256}],
        ],
      },
      "https://2.hoge/$key/hash1.zip" => {
        file => $current->app_path (0)->child ('a.zip'),
      },
    }, app => 1);
  })->then (sub {
    return $current->run ('pull', app => 1);
  })->then (sub {
    return $current->prepare (undef, {
      $current->mirrors_url_prefix . 'hash-ckan-2.hoge.jsonl' => {
        json => {},
      },
      "https://2.hoge/$key/hash1.zip" => {
        status => 404, text => "",
      },
      "https://2.hoge/api/action/package_show?id=$key" => {
        status => 404, text => "",
      },
    });
  })->then (sub {
    return $current->run ('add', additional => ["https://2.hoge/dataset/$key.packref", '--name', 'foo'], app => 1);
  })->then (sub {
    return $current->run ('ls', app => 1, additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{rev}->{sha256}, "dbb997f2c34c915e733551336ba8a01e01a1265d1ddddb50181af37caca72246";
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
      }
    } $current->c;
    return $current->check_files ([
      {path => "local/ddsd/states/packages.json", json => sub {
        my $json = shift;
        is $json->{foo}->{ckan}->{"https://2.hoge/dataset/$key"}->{mirror_url}, "https://2.hoge/$key/hash1.zip";
      }},
    ], app => 1);
  });
} n => 7, name => 'indirectly', timeout => 300;

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
