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
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => "local/data/foo/files/foo", text => "abc"},
      {path => "local/data/foo/files/bar", text => "xyz"},
    ]);
  });
} n => 5, name => 'files';

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
      "https://hoge/$key/bar" => {text => "xyz", status => 404},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
       }},
      {path => "local/data/foo/files/foo", text => "abc"},
      {path => "local/data/foo/files/bar", is_none => 1},
    ]);
  });
} n => 5, name => '404';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
        files => {
          "file:r:123" => {url => "https://hoge/$key/bar",
                           name => "abc.txt"},
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
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => "local/data/foo/files/foo", text => "abc"},
      {path => "local/data/foo/files/bar", is_none => 1},
      {path => "local/data/foo/files/abc.txt", text => "xyz"},
    ]);
  });
} n => 5, name => 'file name specified';

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
            type => 'ckan',
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
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => "local/data/foo/files/foo", text => "abc"},
      {path => "local/data/foo/files/bar", text => "xyz"},
    ]);
  });
} n => 5, name => 'inner';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
        files => {
          "file:r:123" => {url => "https://hoge/$key/baz"},
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
      "https://hoge/$key/baz" => {text => "pqr"},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => "local/data/foo/files/foo", text => "abc"},
      {path => "local/data/foo/files/bar", is_none => 1},
      {path => "local/data/foo/files/baz", text => "pqr"},
    ]);
  });
} n => 5, name => 'inner and outer URLs';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
        files => {
          "file:r:123" => {name => "1.txt"},
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
            files => {
              "file:r:123" => {url => "https://hoge/$key/bar", name => 2},
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
      "https://hoge/$key/baz" => {text => "pqr"},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => "local/data/foo/files/foo", text => "abc"},
      {path => "local/data/foo/files/bar", is_none => 1},
      {path => "local/data/foo/files/baz", is_none => 1},
      {path => "local/data/foo/files/1.txt", text => "xyz"},
    ]);
  });
} n => 5, name => 'inner and outer names';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
        files => {
          "file:r:123" => {},
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
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
       }},
      {path => "local/data/foo/files/foo", text => "abc"},
      {path => "local/data/foo/files/bar", is_none => 1},
    ]);
  });
} n => 5, name => 'URL missing';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
        files => {
          "file:r:123" => {url => "javascript:"},
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
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
       }},
      {path => "local/data/foo/files/foo", text => "abc"},
      {path => "local/data/foo/files/bar", is_none => 1},
    ]);
  });
} n => 5, name => 'bad URL';

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
            files => {
              "file:r:123" => {url => "https://hoge/$key/bar"},
            },
          },
        },
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
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => "local/data/foo/files/bar", text => "xyz"},
    ]);
  });
} n => 5, name => 'files only';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
