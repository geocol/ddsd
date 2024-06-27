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
      type => 'ckansite',
      url => "https://1.hoge/$key/",
    },
  }, {
    "https://1.hoge/$key/" => {
      text => "x",
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
        type => 'ckansite',
        url => "https://1.hoge/$key/",
        skip_other_files => 1,
        files => {
          "file:index.html" => {
            sha256 => "2d711642b726b04401627ca9fbac32f5c8530fb1903cc4db02258717921a4881",
          },
        },
      },
    }, {
      "https://1.hoge/" => {
        text => "x",
      },
      "https://1.hoge/$key/" => {
        text => "y",
      },
      $current->mirrors_url_prefix . 'hash-ckansite-1.hoge.jsonl' => {
        jsonl => [
          ["087f9b6d3d5f759281d20ab9ffc13293b94d38e5c023b200b133c953031de88e",
           "https://1.hoge/$key/hash1.zip",
           $r->{json}->{sha256}, $r->{json}->{length}],
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
         is 0+keys %{$json->{items}}, 1;
         is $json->{items}->{"file:index.html"}->{type}, 'file';
         is $json->{items}->{"file:index.html"}->{rev}->{sha256}, "2d711642b726b04401627ca9fbac32f5c8530fb1903cc4db02258717921a4881";
       }},
      {path => "local/data/foo/files/index.html", text => "x"},
    ], app => 1);
  })->then (sub {
    return $current->get_access_count ("https://1.hoge/");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'site repo not accessed';
    } $current->c;
    return $current->get_access_count ("https://1.hoge/$key/");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'index not accessed';
    } $current->c;
    return $current->run ('pull', app => 1); # 2nd pull, no change
  })->then (sub {
    return $current->check_files ([
      {path => "local/data/foo/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 1;
         is $json->{items}->{"file:index.html"}->{type}, 'file';
         is $json->{items}->{"file:index.html"}->{rev}->{sha256}, "2d711642b726b04401627ca9fbac32f5c8530fb1903cc4db02258717921a4881";
       }},
      {path => "local/data/foo/files/index.html", text => "x"},
    ], app => 1);
  })->then (sub {
    return $current->get_access_count ("https://1.hoge/$key/hash1.zip");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 1, '2nd pull does not fetch zip';
    } $current->c;
    return $current->get_access_count ("https://1.hoge/$key/");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'index not accessed';
    } $current->c;
  });
} n => 15, name => 'from mirror';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
