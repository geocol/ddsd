use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
        files => {
          "file:r:123" => {url => "https://hoge/$key/bar"},
        },
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/dataset/package-name-$key",
          },
        },
      },
      "https://hoge/dataset/package-name-$key" => {
        text => "",
      },
      "https://hoge/api/action/package_show?id=package-name-$key" => {
        json => {
          success => \1,
          result => {
            resources => [{
              id => 'foo',
              url => "https://hoge/$key/foo",
            }],
          },
        },
      },
      "https://hoge/$key/foo" => {text => "abc"},
      "https://hoge/$key/bar" => {text => "xyz"},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 5;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{file}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{mime}, undef;
        is $item->{package_item}->{author}, undef;
        is $item->{package_item}->{org}, undef;
        is $item->{package_item}->{desc}, undef;
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is $item->{path}, undef;
        is $item->{rev}, undef;
        is 0+@{$item->{package_item}->{legal}}, 0;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:ckan.json';
        is $item->{file}->{directory}, 'package';
        is $item->{file}->{name}, 'package.ckan.json';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{mime}, 'application/json';
        like $item->{path}, qr{^/.+/local/data/foo/package/package.ckan.json$}; # XXX platform
        ok $item->{rev}->{http_date};
        ok $item->{rev}->{length};
        ok $item->{rev}->{sha256};
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{url}, "https://hoge/api/action/package_show?id=package-name-$key";
        is $item->{rev}->{original_url}, $item->{rev}->{url};
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:activity.html';
        is $item->{file}->{directory}, 'package';
        is $item->{file}->{name}, 'activity.html';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{mime}, 'text/html;charset=utf-8';
        is $item->{path}, undef;
        is $item->{rev}, undef;
      }
      {
        my $item = $r->{jsonl}->[3];
        is $item->{type}, 'file';
        is $item->{key}, 'file:id:foo';
        is $item->{file}->{directory}, undef;
        is $item->{file}->{name}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{mime}, 'application/octet-stream';
        like $item->{path}, qr{^/.+/local/data/foo/files/foo$}; # XXX platform
        ok $item->{rev}->{http_date};
        ok $item->{rev}->{length};
        ok $item->{rev}->{sha256};
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{url}, "https://hoge/$key/foo";
        is $item->{rev}->{original_url}, $item->{rev}->{url};
      }
      {
        my $item = $r->{jsonl}->[4];
        is $item->{type}, 'file';
        is $item->{key}, 'file:r:123';
        is $item->{file}->{directory}, undef;
        is $item->{file}->{name}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{mime}, 'application/octet-stream';
        like $item->{path}, qr{^/.+/local/data/foo/files/bar$}; # XXX platform
        ok $item->{rev}->{http_date};
        ok $item->{rev}->{length};
        ok $item->{rev}->{sha256};
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{url}, "https://hoge/$key/bar";
        is $item->{rev}->{original_url}, $item->{rev}->{url};
      }
    } $current->c;
  });
} n => 64, name => 'ls --jsonl';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'files',
            url => "https://hoge/dataset/package-name-$key",
            files => {
              "file:r:123" => {url => "https://hoge/$key/bar"},
            },
          },
        },
      },
      "https://hoge/dataset/package-name-$key" => {
        text => "",
      },
      "https://hoge/api/action/package_show?id=package-name-$key" => {
        json => {
          success => \1,
          result => {
            resources => [{
              id => 'foo',
              url => "https://hoge/$key/foo",
            }],
          },
        },
      },
      "https://hoge/$key/foo" => {text => "abc"},
      "https://hoge/$key/bar" => {text => "xyz"},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{file}, undef;
        is $item->{rev}, undef;
        is $item->{path}, undef;
        is $item->{package_item}->{mime}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, '';
        is $item->{package_item}->{org}, '';
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is ref $item->{package_item}->{legal}, 'ARRAY';
        is 0+@{$item->{package_item}->{legal}}, 0;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:packref.json';
        is $item->{file}->{directory}, 'meta';
        is $item->{file}->{name}, 'packref.json';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{mime}, 'application/json';
        like $item->{path}, qr{^/.+/local/data/foo/meta/packref.json$}; # XXX platform
        ok $item->{rev}->{http_date};
        ok $item->{rev}->{length};
        ok $item->{rev}->{sha256};
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{url}, "https://hoge/$key/pack.json";
        is $item->{rev}->{original_url}, $item->{rev}->{url};
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'file';
        is $item->{key}, 'file:r:123';
        is $item->{file}->{directory}, undef;
        is $item->{file}->{name}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{mime}, 'application/octet-stream';
        like $item->{path}, qr{^/.+/local/data/foo/files/bar$}; # XXX platform
        ok $item->{rev}->{http_date};
        ok $item->{rev}->{length};
        ok $item->{rev}->{sha256};
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{url}, "https://hoge/$key/bar";
        is $item->{rev}->{original_url}, $item->{rev}->{url};
      }
    } $current->c;
  });
} n => 44, name => 'files only';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        text => qq{{
          "type": "packref",
          "source": {
            "type": "files",
            "url": "https://hoge/dataset/package-name-$key",
            "files": {
              "file:r:123": {"url":"https://hoge/$key/bar"}
            }
          }
        }},
      },
      "https://hoge/dataset/package-name-$key" => {
        text => "",
      },
      "https://hoge/api/action/package_show?id=package-name-$key" => {
        json => {
          success => \1,
          result => {
            resources => [{
              id => 'foo',
              url => "https://hoge/$key/foo",
            }],
          },
        },
      },
      "https://hoge/$key/foo" => {text => "abc"},
      "https://hoge/$key/bar" => {text => "xyz"},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
            '21af51e4d7ae35ec79244d99ec225b7610bb5222cbaa41d2845ca64f21261784';
      }
    } $current->c;
  });
} n => 4, name => 'snapshot_hash, files only';

Test {
  my $current = shift;
  my $key = "gwaHEy55hey6hja";
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
        files => {
          "file:r:123" => {url => "https://hoge/$key/bar"},
        },
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        text => qq{{
          "type": "packref",
          "source": {
            "type": "ckan",
            "url": "https://hoge/dataset/package-name-$key"
          }
        }},
      },
      "https://hoge/dataset/package-name-$key" => {
        text => "",
      },
      "https://hoge/api/action/package_show?id=package-name-$key" => {
        text => qq{{
          "success": true,
          "result": {
            "resources": [{
              "id":"foo",
              "url": "https://hoge/$key/foo"
            }]
          }
        }},
      },
      "https://hoge/$key/foo" => {text => "abc"},
      "https://hoge/$key/bar" => {text => "xyz"},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 5;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{snapshot_hash},
            'c6cb2a19a22334314c9aaed58760e34029ac5c57509ba6dfd9435ddb822fb498';
      }
    } $current->c;
    return $current->prepare (undef, {
      "https://hoge/$key/foo" => {text => "ABC"},
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 5;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{snapshot_hash},
            '06a9221d06803a0803924fa672adbfd8ef0282a8a99ad0277f168ccd9b5e764f';
      }
    } $current->c;
  });
} n => 12, name => 'snapshot_hash, has source';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        text => qq{{
          "type": "packref",
          "source": {
            "type": "files",
            "url": "https://hoge/dataset/package-name-$key",
            "files": {
              "file:r:123": {"url": "https://hoge/$key/bar"}
            }
          },
          "meta": {
            "title": "\x{6000}",
            "desc": "\x{7000}",
            "author": "\x{8000}",
            "org": "\x{9000}",
            "lang": "es",
            "dir": "rtl",
            "writing_mode": "vertical-rl"
          }
        }},
      },
      "https://hoge/$key/bar" => {text => "xyz"},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{file}, undef;
        is $item->{rev}, undef;
        is $item->{path}, undef;
        is $item->{package_item}->{mime}, undef;
        is $item->{package_item}->{title}, "\x{6000}";
        is $item->{package_item}->{desc}, "\x{7000}";
        is $item->{package_item}->{author}, "\x{8000}";
        is $item->{package_item}->{org}, "\x{9000}";
        is $item->{package_item}->{lang}, 'es';
        is $item->{package_item}->{dir}, 'rtl';
        is $item->{package_item}->{writing_mode}, 'vertical-rl';
        ok $item->{package_item}->{file_time};
        is ref $item->{package_item}->{legal}, 'ARRAY';
        is 0+@{$item->{package_item}->{legal}}, 0;
      }
    } $current->c;
  });
} n => 19, name => 'package metadata';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
