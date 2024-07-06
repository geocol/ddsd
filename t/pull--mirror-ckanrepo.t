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
      type => 'ckan',
      url => "https://1.hoge/dataset/$key",
    },
  }, {
    "https://1.hoge/dataset/$key" => {
      text => "x",
    },
    "https://1.hoge/dataset/activity/$key" => {
      text => "y",
    },
    "https://1.hoge/api/action/package_show?id=$key" => {
      text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc.txt"}]}} },
    },
    "https://hoge/$key/abc.txt" => {
      text => "abc",
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->run ('ls', additional => ['hoge']);
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
        url => "https://1.hoge/dataset/$key",
        skip_other_files => 1,
        files => {
          "meta:ckan.json" => {
            sha256 => "4639625a084d7098a0cf0366ebc19b685103b9e97e85724c08a9d61e0bc2a86a",
          },
          "meta:activity.html" => {},
          "file:index:0" => {
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
      "https://1.hoge/api/action/package_show?id=$key" => {
        text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc.txt"}]}} },
      },
      $current->mirrors_url_prefix . 'hash-ckan-1.hoge.jsonl' => {
        jsonl => [
          ["b4bdac56fe0fd601b76de463831b782a4b86b4a00d8f0d0d5eb7f4f3307ac597",
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
         is 0+keys %{$json->{items}}, 3;
         is $json->{items}->{'meta:ckan.json'}->{type}, 'meta';
         is $json->{items}->{'meta:ckan.json'}->{rev}->{sha256}, "4639625a084d7098a0cf0366ebc19b685103b9e97e85724c08a9d61e0bc2a86a";
         is $json->{items}->{"meta:activity.html"}->{type}, 'meta';
         is $json->{items}->{"meta:activity.html"}->{rev}->{sha256}, "a1fce4363854ff888cff4b8e7875d600c2682390412a8cf79b37d0b11148b0fa";
         is $json->{items}->{"file:index:0"}->{type}, 'file';
         is $json->{items}->{"file:index:0"}->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
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
    return $current->get_access_count
        ("https://1.hoge/api/action/package_show?id=$key");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'ckan package not accessed';
    } $current->c;
  })->then (sub {
    return $current->run ('pull', app => 1); # 2nd pull, no change
  })->then (sub {
    return $current->check_files ([
      {path => "local/data/foo/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 3;
         is $json->{items}->{'meta:ckan.json'}->{type}, 'meta';
         is $json->{items}->{'meta:ckan.json'}->{rev}->{sha256}, "4639625a084d7098a0cf0366ebc19b685103b9e97e85724c08a9d61e0bc2a86a";
         is $json->{items}->{"meta:activity.html"}->{type}, 'meta';
         is $json->{items}->{"meta:activity.html"}->{rev}->{sha256}, "a1fce4363854ff888cff4b8e7875d600c2682390412a8cf79b37d0b11148b0fa";
         is $json->{items}->{"file:index:0"}->{type}, 'file';
         is $json->{items}->{"file:index:0"}->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
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
} n => 22, name => 'directly';

Test {
  my $current = shift;
  my $key = "0geEGr42rewe4464Gee4442";
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
              'meta:ckan.json' => {
                sha256 => "4639625a084d7098a0cf0366ebc19b685103b9e97e85724c08a9d61e0bc2a86a",
              },
              "meta:activity.html" => {},
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
          ["b4bdac56fe0fd601b76de463831b782a4b86b4a00d8f0d0d5eb7f4f3307ac597",
           "https://2.hoge/$key/hash1.zip",
           $r->{json}->{sha256}, $r->{json}->{length}],
        ],
      },
      "https://2.hoge/$key/hash1.zip" => {
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
         is $json->{items}->{'meta:ckan.json'}->{type}, 'meta';
         is $json->{items}->{'meta:ckan.json'}->{rev}->{sha256}, "4639625a084d7098a0cf0366ebc19b685103b9e97e85724c08a9d61e0bc2a86a";
         is $json->{items}->{"meta:activity.html"}->{type}, 'meta';
         is $json->{items}->{"meta:activity.html"}->{rev}->{sha256}, "a1fce4363854ff888cff4b8e7875d600c2682390412a8cf79b37d0b11148b0fa";
         is $json->{items}->{"file:index:0"}->{type}, 'file';
         is $json->{items}->{"file:index:0"}->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
       }},
      {path => "local/data/foo/files/abc.txt", text => "abc"},
    ], app => 1);
  })->then (sub {
    return $current->get_access_count ("https://2.hoge/");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'site repo not accessed';
    } $current->c;
    return $current->get_access_count
        ("https://2.hoge/api/action/package_show?id=$key");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'ckan package not accessed';
    } $current->c;
  })->then (sub {
    return $current->run ('pull', app => 1); # 2nd pull, no change
  })->then (sub {
    return $current->check_files ([
      {path => "local/data/foo/index.json", json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 3;
         is $json->{items}->{'meta:ckan.json'}->{type}, 'meta';
         is $json->{items}->{'meta:ckan.json'}->{rev}->{sha256}, "4639625a084d7098a0cf0366ebc19b685103b9e97e85724c08a9d61e0bc2a86a";
         is $json->{items}->{"meta:activity.html"}->{type}, 'meta';
         is $json->{items}->{"meta:activity.html"}->{rev}->{sha256}, "a1fce4363854ff888cff4b8e7875d600c2682390412a8cf79b37d0b11148b0fa";
         is $json->{items}->{"file:index:0"}->{type}, 'file';
         is $json->{items}->{"file:index:0"}->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
       }},
      {path => "local/data/foo/files/abc.txt", text => "abc"},
    ], app => 1);
  })->then (sub {
    return $current->get_access_count ("https://2.hoge/$key/hash1.zip");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 1, '2nd pull does not fetch zip';
    } $current->c;
  });
} n => 22, name => 'indirectly', timeout => 300;


Test {
  my $current = shift;
  my $key = "0geEGr42rewe4464Gee4642";
  return $current->prepare ({
    hoge => {
      type => 'ckan',
      url => "https://3.hoge/dataset/$key",
    },
  }, {
    "https://3.hoge/dataset/$key" => {
      text => "x",
    },
    "https://3.hoge/dataset/activity/$key" => {
      text => "y",
    },
    "https://3.hoge/api/action/package_show?id=$key" => {
      text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc3.txt"}]}} },
    },
    "https://hoge/$key/abc3.txt" => {
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
        url => "https://3.hoge/dataset/$key",
        skip_other_files => 1,
        files => {
          'meta:ckan.json' => {
            sha256 => "5745be8ff791e482a9ef418ff5532cde3efe4f6039c5a15ea2b963fd17271b49",
          },
          "meta:activity.html" => {},
          "file:index:0" => {
            sha256 => "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
          },
        },
      },
    }, {
      "https://3.hoge/" => {
        text => "x",
      },
      "https://hoge/$key/abc3.txt" => {
        text => "ABC",
      },
      "https://3.hoge/api/action/package_show?id=$key" => {
        text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc3.txt"}]}} },
      },
      $current->mirrors_url_prefix . 'hash-ckan-3.hoge.jsonl' => {
        jsonl => [
          ["0622f7b69e91a45d477650ea6f52c583ae9b76920e9692bd5d9bd4f3dbf89f01",
           "https://3.hoge/$key/hash1.zip",
           $r->{json}->{sha256}],
        ],
      },
      #"https://3.hoge/$key/hash1.zip" => {
      #  file => $current->app_path (0)->child ('a.zip'),
      #},
    }, app => 1);
  })->then (sub {
    return $current->run ('pull', app => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
      isnt $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/foo", is_none => 1},
    ], app => 1);
  })->then (sub {
    return $current->get_access_count ("https://3.hoge/");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'site repo not accessed';
    } $current->c;
    return $current->get_access_count
        ("https://3.hoge/api/action/package_show?id=$key");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'ckan package not accessed';
    } $current->c;
  });
} n => 6, name => 'mirrorzip not found', timeout => 300;

Test {
  my $current = shift;
  my $key = "0geEGr42rewe4464Gee4442";
  return $current->prepare ({
    hoge => {
      type => 'ckan',
      url => "https://4.hoge/dataset/$key",
    },
  }, {
    "https://4.hoge/dataset/$key" => {
      text => "x",
    },
    "https://4.hoge/dataset/activity/$key" => {
      text => "y",
    },
    "https://4.hoge/api/action/package_show?id=$key" => {
      text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc.txt"}]}} },
    },
    "https://hoge/$key/abc.txt" => {
      text => "abc",
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->run ('export', additional => ['mirrorzip', 'hoge', 'a.zip']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare ({
      foo => {
        type => 'ckan',
        url => "https://4.hoge/dataset/$key",
        skip_other_files => 1,
        files => {
          'meta:ckan.json' => {
            sha256 => "4639625a084d7098a0cf0366ebc19b685103b9e97e85724c08a9d61e0bc2a86a",
          },
          "meta:activity.html" => {},
          "file:index:0" => {
            sha256 => "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
          },
        },
      },
    }, {
      "https://4.hoge/" => {
        text => "x",
      },
      "https://hoge/$key/abc.txt" => {
        text => "ABC",
      },
      "https://4.hoge/api/action/package_show?id=$key" => {
        text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc.txt"}]}} },
      },
      $current->mirrors_url_prefix . 'hash-ckan-4.hoge.jsonl' => {
        jsonl => [
          ["b4bdac56fe0fd601b76de463831b782a4b86b4a00d8f0d0d5eb7f4f3307ac597",
           "https://4.hoge/$key/hash1.zip",
           "acde", 123],
        ],
      },
      "https://4.hoge/$key/hash1.zip" => {
        file => $current->app_path (0)->child ('a.zip'),
      },
    }, app => 1);
  })->then (sub {
    return $current->run ('pull', app => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
      isnt $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/foo", is_none => 1},
    ], app => 1);
  })->then (sub {
    return $current->get_access_count ("https://4.hoge/");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'site repo not accessed';
    } $current->c;
    return $current->get_access_count
        ("https://4.hoge/api/action/package_show?id=$key");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'ckan package not accessed';
    } $current->c;
  });
} n => 6, name => 'sha256 mismatch', timeout => 300;

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
