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
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => 'https://hoge/dataset/package-name',
          },
        },
      },
      "https://hoge/api/action/package_show?id=package-name" => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
          foo => 1,
        },
      },
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
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         {
           ok ! $json->{items}->{package};
         }
       }},
      {path => "local/data/foo/package/package.ckan.json", json => sub {
        my $json = shift;
        is $json->{foo}, 1;
      }},
    ]);
  });
} n => 8, name => 'CKAN referenced 1';

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
            url => "https://hoge/$key/dataset/package-name",
          },
        },
      },
      "https://hoge/$key/api/action/package_show?id=package-name" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "abc", url => "https://hoge/$key/abc.txt"},
            ],
          },
          foo => 1,
        },
      },
      "https://hoge/$key/abc.txt" => {
        text => "xyz",
      },
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
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
         {
           ok ! $json->{items}->{package};
         }
       }},
      {path => "local/data/foo/package/package.ckan.json", json => sub {
        my $json = shift;
        is $json->{foo}, 1;
      }},
      {path => "local/data/foo/files/abc.txt", text => "xyz"},
    ]);
  });
} n => 8, name => 'CKAN referenced 2';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
        files => {
          "file:id:abc2" => {skip => 1},
        },
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/$key/dataset/package-name",
          },
        },
      },
      "https://hoge/$key/api/action/package_show?id=package-name" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "abc", url => "https://hoge/$key/abc.txt"},
              {id => "abc2", url => "https://hoge/$key/abc2.txt"},
            ],
          },
          foo => 1,
        },
      },
      "https://hoge/$key/abc.txt" => {
        text => "xyz",
      },
      "https://hoge/$key/abc2.txt" => {
        text => "xyz2",
      },
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
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
         {
           ok ! $json->{items}->{package};
         }
       }},
      {path => "local/data/foo/package/package.ckan.json", json => sub {
        my $json = shift;
        is $json->{foo}, 1;
      }},
      {path => "local/data/foo/files/abc.txt", text => "xyz"},
      {path => "local/data/foo/files/abc2.txt", is_none => 1},
    ]);
  });
} n => 8, name => 'some skipped by local';

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
            url => "https://hoge/$key/dataset/package-name",
            files => {
              "file:id:abc2" => {skip => 1},
            },
          },
        },
      },
      "https://hoge/$key/api/action/package_show?id=package-name" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "abc", url => "https://hoge/$key/abc.txt"},
              {id => "abc2", url => "https://hoge/$key/abc2.txt"},
            ],
          },
          foo => 1,
        },
      },
      "https://hoge/$key/abc.txt" => {
        text => "xyz",
      },
      "https://hoge/$key/abc2.txt" => {
        text => "xyz2",
      },
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
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
         {
           ok ! $json->{items}->{package};
         }
       }},
      {path => "local/data/foo/package/package.ckan.json", json => sub {
        my $json = shift;
        is $json->{foo}, 1;
      }},
      {path => "local/data/foo/files/abc.txt", text => "xyz"},
      {path => "local/data/foo/files/abc2.txt", is_none => 1},
    ]);
  });
} n => 8, name => 'some skipped by ref';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
        files => {
          "file:id:abc" => {name => "abc.xml"},
          "file:id:abc3" => {name => "abc3.xls"},
        },
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/$key/dataset/package-name",
            files => {
              "file:id:abc2" => {name => "abc2.xml"},
              "file:id:abc3" => {name => "abc3.xml"},
            },
          },
        },
      },
      "https://hoge/$key/api/action/package_show?id=package-name" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "abc", url => "https://hoge/$key/abc.txt"},
              {id => "abc2", url => "https://hoge/$key/abc2.txt"},
              {id => "abc3", url => "https://hoge/$key/abc3.txt"},
            ],
          },
          foo => 1,
        },
      },
      "https://hoge/$key/abc.txt" => {
        text => "xyz",
      },
      "https://hoge/$key/abc2.txt" => {
        text => "xyz2",
      },
      "https://hoge/$key/abc3.txt" => {
        text => "xyz3",
      },
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
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
       }},
      {path => "local/data/foo/package/package.ckan.json", json => sub { }},
      {path => "local/data/foo/files/abc.xml", text => "xyz"},
      {path => "local/data/foo/files/abc2.xml", text => "xyz2"},
      {path => "local/data/foo/files/abc3.xls", text => "xyz3"},
      {path => "local/data/foo/files/abc.txt", is_none => 1},
      {path => "local/data/foo/files/abc2.txt", is_none => 1},
      {path => "local/data/foo/files/abc3.txt", is_none => 1},
      {path => "local/data/foo/files/abc3.xml", is_none => 1},
    ]);
  });
} n => 8, name => 'files renamed';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
        files => {
          "file:id:abc" => {sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"}, # matched
          "file:id:abc3" => {sha256 => "bad"},
        },
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/$key/dataset/package-name",
            files => {
              "file:id:abc2" => {sha256 => "bad"},
            },
          },
        },
      },
      "https://hoge/$key/api/action/package_show?id=package-name" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "abc", url => "https://hoge/$key/abc.txt"},
              {id => "abc2", url => "https://hoge/$key/abc2.txt"},
              {id => "abc3", url => "https://hoge/$key/abc3.txt"},
            ],
          },
          foo => 1,
        },
      },
      "https://hoge/$key/abc.txt" => {
        text => "r1",
      },
      "https://hoge/$key/abc2.txt" => {
        text => "r2",
      },
      "https://hoge/$key/abc3.txt" => {
        text => "r3",
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
       }},
      {path => "local/data/foo/package/package.ckan.json", json => sub { }},
      {path => "local/data/foo/files/abc.txt", text => "r1"},
      {path => "local/data/foo/files/abc2.txt", is_none => 1},
      {path => "local/data/foo/files/abc3.txt", is_none => 1},
    ]);
  });
} n => 6, name => 'sha256 1';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
        files => {
          "file:id:abc" => {sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"}, # matched
          "file:id:abc2" => {sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"}, # matched
          "file:id:abc3" => {sha256 => "bad"},
        },
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/$key/dataset/package-name",
            files => {
              "file:id:abc" => {sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"}, # matched
              "file:id:abc2" => {sha256 => "bad"},
              "file:id:abc3" => {sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"}, # matched
            },
          },
        },
      },
      "https://hoge/$key/api/action/package_show?id=package-name" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "abc", url => "https://hoge/$key/abc.txt"},
              {id => "abc2", url => "https://hoge/$key/abc2.txt"},
              {id => "abc3", url => "https://hoge/$key/abc3.txt"},
            ],
          },
          foo => 1,
        },
      },
      "https://hoge/$key/abc.txt" => {
        text => "r1",
      },
      "https://hoge/$key/abc2.txt" => {
        text => "r1",
      },
      "https://hoge/$key/abc3.txt" => {
        text => "r1",
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
       }},
      {path => "local/data/foo/package/package.ckan.json", json => sub { }},
      {path => "local/data/foo/files/abc.txt", text => "r1"},
      {path => "local/data/foo/files/abc2.txt", is_none => 1},
      {path => "local/data/foo/files/abc3.txt", is_none => 1},
    ]);
  });
} n => 6, name => 'sha256 2';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
        files => {
          "file:id:abc" => {sha256_insecure => 1,
                            sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"}, # matched
          "file:id:abc2" => {sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"}, # matched
          "file:id:abc3" => {sha256 => "bad", sha256_insecure => 1},
        },
      },
    },
    {
      "https://hoge/$key/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/$key/dataset/package-name",
            files => {
              "file:id:abc" => {sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"}, # matched
              "file:id:abc2" => {sha256 => "bad", sha256_insecure => 1},
              "file:id:abc3" => {sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"}, # matched
            },
          },
        },
      },
      "https://hoge/$key/api/action/package_show?id=package-name" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "abc", url => "https://hoge/$key/abc.txt"},
              {id => "abc2", url => "https://hoge/$key/abc2.txt"},
              {id => "abc3", url => "https://hoge/$key/abc3.txt"},
            ],
          },
          foo => 1,
        },
      },
      "https://hoge/$key/abc.txt" => {
        text => "r1",
      },
      "https://hoge/$key/abc2.txt" => {
        text => "r1",
      },
      "https://hoge/$key/abc3.txt" => {
        text => "r1",
      },
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
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
       }},
      {path => "local/data/foo/package/package.ckan.json", json => sub { }},
      {path => "local/data/foo/files/abc.txt", text => "r1"},
      {path => "local/data/foo/files/abc2.txt", text => "r1"},
      {path => "local/data/foo/files/abc3.txt", text => "r1"},
    ]);
  });
} n => 8, name => 'sha256 3';

for my $in (
  {
    json => {
      type => 'packref',
      source => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-x',
      },
    },
    status => 404,
  },
) {
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
        "https://hoge/$key/pack.json" => $in,
        "https://hoge/api/action/package_show?id=package-name-x" => {
          json => {
            success => \1,
            result => {
              resources => [],
            },
            foo => 1,
          },
        },
      },
    )->then (sub {
      return $current->run ('pull');
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'local/data/foo/index.json', is_none => 1},
        {path => "local/data/foo/package/package.ckan.json", is_none => 1},
      ]);
    });
  } n => 2, name => ['packref broken 1', %$in];
}

for my $in (
  {json => []},
  {json => ""},
  {json => 12},
  {json => {
    type => undef,
    source => {
      type => 'ckan',
      url => "https://hoge/",
    },
  }},
  {json => {
    type => 'oge',
    source => {
      type => 'ckan',
      url => "https://hoge/",
    },
  }},
  {json => {
    type => 'packref',
    source => [],
  }},
  {json => {
    type => 'packref',
  }},
) {
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
        "https://hoge/$key/pack.json" => $in,
        "https://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {
            success => \1,
            result => {
              resources => [],
            },
            foo => 1,
          },
        },
      },
    )->then (sub {
      return $current->run ('pull');
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'local/data/foo/index.json', json => sub {
           my $json = $_[0];
           is 0+keys %{$json->{items}}, 0;
         }},
        {path => "local/data/foo/package/package.ckan.json", is_none => 1},
      ]);
    });
  } n => 3, name => ['packref broken 2', %$in];
}

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
            url => 'https://hoge/dataset/package-name',
          },
        },
      },
      "https://hoge/api/action/package_show?id=package-name" => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
          foo => 1,
        },
        status => 404,
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = $_[0];
         is 0+keys %{$json->{items}}, 0;
       }},
      {path => "local/data/foo/package/package.ckan.json", is_none => 1},
    ]);
  });
} n => 3, name => 'CKAN 404';

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
            type => 'hoge',
            url => 'https://hoge/dataset/package-name-' . $key,
          },
        },
      },
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
          foo => 1,
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = $_[0];
         is 0+keys %{$json->{items}}, 0;
       }},
      {path => "local/data/foo/package/package.ckan.json", is_none => 1},
    ]);
  });
} n => 3, name => 'CKAN bad source';

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
              "file:r:sparql" => {
                url => "https://hoge/$key/sparqlep",
                set_type => 'sparql?',
              },
            },
          },
        },
      },
      "https://hoge/$key/sparqlep" => {
        text => "a",
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => "local/data/foo/files/sparqlep", is_none => 1},
      {path => "local/data/foo/files/sparqlep/part-0.ttl", is_none => 1},
    ]);
  });
} n => 5, name => 'bad set_type';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
