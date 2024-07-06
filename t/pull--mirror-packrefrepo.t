use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = "0geEGr42rewe4464Gee4442";
  return $current->prepare ({
    hoge => {
      type => 'packref',
      url => "https://1.hoge/dataset/$key",
    },
  }, {
    "https://1.hoge/dataset/$key" => {
      text => qq{ {"type":"packref","source":{"type": "files","files":{"file:r:1":{"url":"https://hoge/$key/abc.txt"},"file:r:packref":{"url":"https://1.hoge/dataset/$key"}}}} },
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
        type => 'packref',
        url => "https://1.hoge/dataset/$key",
        skip_other_files => 1,
        files => {
          "file:r:1" => {
            sha256 => "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
          },
        },
      },
    }, {
      "https://1.hoge/" => {
        text => "x",
      },
      "https://hoge/$key/abc.txt" => {
        text => "ABC",
      },
      "https://1.hoge/dataset/$key" => {
        text => qq{ {"type":"packref","source":{"type": "files","files":{"file:r:1":{"url":"https://hoge/$key/abc.txt"},"file:r:packref":{"url":"https://1.hoge/dataset/$key"}}}} },
      },
      $current->mirrors_url_prefix . 'hash-packref-1.hoge.jsonl' => {
        jsonl => [
          ["930469a0fa4b20d4631f3571af869a45d256df35b2280f1a9fc4320733628e66",
           "https://1.hoge/$key/hash1.zip",
           $r->{json}->{sha256}],
        ],
      },
      "https://1.hoge/$key/hash1.zip" => {
        file => $current->app_path (0)->child ('a.zip'),
      },
    }, app => 1);
  })->then (sub {
    return $current->run ('pull', app => 1);
  })->then (sub {
    return $current->check_files ([
      {path => "local/data/foo/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 3;
         is $json->{items}->{"file:r:1"}->{type}, 'file';
         is $json->{items}->{"file:r:1"}->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
         is $json->{items}->{"file:r:packref"}->{type}, 'file';
         is $json->{items}->{"file:r:packref"}->{rev}->{sha256}, "a369ab0659b3d0586378d20a3077338a84a78a0bec6da44ebc74a9b35756a91b";
         is $json->{items}->{"meta:packref.json"}->{type}, 'meta';
         is $json->{items}->{"meta:packref.json"}->{rev}->{sha256}, "a369ab0659b3d0586378d20a3077338a84a78a0bec6da44ebc74a9b35756a91b";
       }},
      {path => "local/data/foo/files/abc.txt", text => "abc"},
    ], app => 1);
  })->then (sub {
    return $current->get_access_count ("https://1.hoge/");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'site repo not accessed';
    } $current->c;
    return $current->get_access_count ("https://1.hoge/dataset/$key");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'packref not accessed';
    } $current->c;
  })->then (sub {
    return $current->run ('pull', app => 1); # 2nd pull, no change
  })->then (sub {
    return $current->check_files ([
      {path => "local/data/foo/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 3;
         is $json->{items}->{"file:r:1"}->{type}, 'file';
         is $json->{items}->{"file:r:1"}->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
         is $json->{items}->{"file:r:packref"}->{type}, 'file';
         is $json->{items}->{"file:r:packref"}->{rev}->{sha256}, "a369ab0659b3d0586378d20a3077338a84a78a0bec6da44ebc74a9b35756a91b";
       }},
      {path => "local/data/foo/files/abc.txt", text => "abc"},
    ], app => 1);
  })->then (sub {
    return $current->get_access_count ("https://1.hoge/$key/hash1.zip");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 1, '2nd pull does not fetch zip';
    } $current->c;
  });
} n => 20, name => 'from mirror';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
