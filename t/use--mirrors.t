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
      foo => {
        type => 'ckan',
        url => "https://2.hoge/dataset/$key",
        skip_other_files => 1,
        files => {
          "meta:ckan.json" => {
            sha256 => "dbb997f2c34c915e733551336ba8a01e01a1265d1ddddb50181af37caca72246",
          },
          "meta:activity.html" => {skip => 1},
          "file:index:0" => {
            sha256 => "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
          },
        },
      },
    }, {
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
          ["f4e4b46625d9fc7a4d138a0a1373359af6c1b0395fc651c14afed1dc0a8621f6",
           "https://2.hoge/$key/hash1.zip",
           $r->{json}->{sha256}, $r->{json}->{length}],
        ],
      },
      "https://2.hoge/$key/hash1.zip" => {
        file => $current->app_path (0)->child ('a.zip'),
      },
    }, app => 1);
  })->then (sub {
    return $current->run ('use', additional => ["foo", "meta:activity.html"], app => 1);
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
    return $current->run ('ls', app => 1, additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $item = $r->{jsonl}->[1];
        is $item->{rev}->{sha256}, "dbb997f2c34c915e733551336ba8a01e01a1265d1ddddb50181af37caca72246";
      }
      {
        my $item = $r->{jsonl}->[3];
        is $item->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
      }
    } $current->c;
    return $current->run ('unuse', additional => ["foo", "meta:activity.html"], app => 1);
  })->then (sub {
    return $current->check_files ([
      {path => "local/ddsd/states/packages.json", json => sub {
        my $json = shift;
        is $json->{foo}->{ckan}->{"https://2.hoge/dataset/$key"}->{mirror_url}, "https://2.hoge/$key/hash1.zip";
      }},
    ], app => 1);
  })->then (sub {
    return $current->run ('ls', app => 1, additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $item = $r->{jsonl}->[1];
        is $item->{rev}->{sha256}, "dbb997f2c34c915e733551336ba8a01e01a1265d1ddddb50181af37caca72246";
      }
      {
        my $item = $r->{jsonl}->[3];
        is $item->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
      }
    } $current->c;
  });
} n => 11, name => 'set mirror by use', timeout => 300;

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
