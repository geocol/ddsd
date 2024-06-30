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
        type => 'ckan',
        url => "https://hoge/dataset/$key",
        files => {
          "file:id:bar" => {skip => 0},
        },
      },
    },
    {
      "https://hoge/dataset/$key" => {text => ""},
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
              {id => 'bar', url => "https://hoge/$key/bar"},
            ],
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
        is $item->{path}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:ckan.json';
        like $item->{path}, qr{^/.+/local/data/foo/package/package.ckan.json$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:activity.html';
        like $item->{path}, qr{^/.+/local/data/foo/package/activity.html$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[3];
        is $item->{type}, 'file';
        is $item->{key}, 'file:id:foo';
        like $item->{path}, qr{^/.+/local/data/foo/files/foo$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[4];
        is $item->{type}, 'file';
        is $item->{key}, 'file:id:bar';
        like $item->{path}, qr{^/.+/local/data/foo/files/bar$}; # XXX platform
      }
    } $current->c;
  });
} n => 18, name => 'not skipped';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
        files => {
          "file:id:bar" => {skip => 1},
        },
      },
    },
    {
      "https://hoge/dataset/$key" => {text => ""},
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
              {id => 'bar', url => "https://hoge/$key/bar"},
            ],
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
        is $item->{path}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:ckan.json';
        like $item->{path}, qr{^/.+/local/data/foo/package/package.ckan.json$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:activity.html';
        like $item->{path}, qr{^/.+/local/data/foo/package/activity.html$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[3];
        is $item->{type}, 'file';
        is $item->{key}, 'file:id:foo';
        like $item->{path}, qr{^/.+/local/data/foo/files/foo$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[4];
        is $item->{type}, 'file';
        is $item->{key}, 'file:id:bar';
        is $item->{path}, undef;
      }
    } $current->c;
  });
} n => 18, name => 'skipped by packages.json';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/packref.json",
      },
    },
    {
      "https://hoge/$key/packref.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/dataset/$key",
            files => {
              "file:id:bar" => {skip => 1},
            },
          },
        },
      },
      "https://hoge/dataset/$key" => {text => ""},
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
              {id => 'bar', url => "https://hoge/$key/bar"},
            ],
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
        is $item->{path}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:ckan.json';
        like $item->{path}, qr{^/.+/local/data/foo/package/package.ckan.json$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:activity.html';
        like $item->{path}, qr{^/.+/local/data/foo/package/activity.html$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[3];
        is $item->{type}, 'file';
        is $item->{key}, 'file:id:foo';
        like $item->{path}, qr{^/.+/local/data/foo/files/foo$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[4];
        is $item->{type}, 'file';
        is $item->{key}, 'file:id:bar';
        is $item->{path}, undef;
      }
    } $current->c;
  });
} n => 18, name => 'skipped by packref';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/packref2.json",
      },
    },
    {
      "https://hoge/$key/packref2.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'packref',
            url => "https://hoge/$key/packref.json",
          },
        },
      },
      "https://hoge/$key/packref.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/dataset/$key",
            files => {
              "file:id:bar" => {skip => 1},
            },
          },
        },
      },
      "https://hoge/dataset/$key" => {text => ""},
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
              {id => 'bar', url => "https://hoge/$key/bar"},
            ],
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
        is $item->{path}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:ckan.json';
        like $item->{path}, qr{^/.+/local/data/foo/package/package.ckan.json$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:activity.html';
        like $item->{path}, qr{^/.+/local/data/foo/package/activity.html$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[3];
        is $item->{type}, 'file';
        is $item->{key}, 'file:id:foo';
        like $item->{path}, qr{^/.+/local/data/foo/files/foo$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[4];
        is $item->{type}, 'file';
        is $item->{key}, 'file:id:bar';
        is $item->{path}, undef;
      }
    } $current->c;
  });
} n => 18, name => 'skipped by packref nested';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/packref2.json",
        files => {
          "file:id:bar" => {skip => 0},
        },
      },
    },
    {
      "https://hoge/$key/packref2.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'packref',
            url => "https://hoge/$key/packref.json",
          },
        },
      },
      "https://hoge/$key/packref.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/dataset/$key",
            files => {
              "file:id:bar" => {skip => 1},
            },
          },
        },
      },
      "https://hoge/dataset/$key" => {text => ""},
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
              {id => 'bar', url => "https://hoge/$key/bar"},
            ],
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
        is $item->{path}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:ckan.json';
        like $item->{path}, qr{^/.+/local/data/foo/package/package.ckan.json$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:activity.html';
        like $item->{path}, qr{^/.+/local/data/foo/package/activity.html$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[3];
        is $item->{type}, 'file';
        is $item->{key}, 'file:id:foo';
        like $item->{path}, qr{^/.+/local/data/foo/files/foo$}; # XXX platform
      }
      {
        my $item = $r->{jsonl}->[4];
        is $item->{type}, 'file';
        is $item->{key}, 'file:id:bar';
        like $item->{path}, qr{^/.+/local/data/foo/files/bar$}; # XXX platform
      }
    } $current->c;
  });
} n => 18, name => 'skip cancelled';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
