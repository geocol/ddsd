use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

for my $args (
  [],
  [""],
  ["hoge"],
  ["//foo/bar"],
  ["javascript:"],
  ["nothttps://foo/bar"],
  ["https://www.test/", "https://www.test/"],
  ["https://badserver.test/"],
  ["http://badserver.test/"],
) {
  Test {
    my $current = shift;
    return $current->prepare (undef, {})->then (sub {
      return $current->run ('add', additional => $args);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'config', is_none => 1},
        {path => 'local/data', is_none => 1},
      ]);
    });
  } n => 3, name => ['add bad argument', @$args];
}

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "http://foo.test/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "http://foo.test/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["http://foo.test/abc/dataset/" . $key], insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         my $def = $json->{$key};
         is 0+keys %{$def}, 3;
         is $def->{type}, 'ckan';
         is $def->{url}, "http://foo.test/abc/dataset/".$key;
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is 0+keys %{$json->{url_sha256s}}, 0;
         is 0+keys %{$json->{urls}}, 0;
         is 0+keys %{$json->{items}}, 1;
         my $item = [values %{$json->{items}}]->[0];
         is $item->{files}->{data}, 'package/package.ckan.json';
         is $item->{type}, 'meta';
       }},
      {path => "local/data/$key/package/package.ckan.json", json => sub {
        my $json = shift;
        is 0+@{$json->{result}->{resources}}, 0;
      }},
    ]);
  });
} n => 12, name => 'empty packages';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "http://foo.test/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "http://foo.test/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('add', insecure => 1,
                          additional => ["http://foo.test/abc/dataset/" . $key]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         my $def = $json->{$key};
         is 0+keys %{$def}, 3;
         is $def->{type}, 'ckan';
         is $def->{url}, "http://foo.test/abc/dataset/".$key;
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is 0+keys %{$json->{url_sha256s}}, 0;
         is 0+keys %{$json->{urls}}, 0;
         is 0+keys %{$json->{items}}, 1;
         my $item = [values %{$json->{items}}]->[0];
         is $item->{files}->{data}, 'package/package.ckan.json';
         is $item->{type}, 'meta';
       }},
      {path => "local/data/$key/package/package.ckan.json", json => sub {
        my $json = shift;
        is 0+@{$json->{result}->{resources}}, 0;
      }},
    ]);
  });
} n => 12, name => 'empty packages, explicit --insecure';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "http://foo.test/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "http://foo.test/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('add', insecure => 0,
                          additional => ["http://foo.test/abc/dataset/" . $key]);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', is_none => 1},
      {path => 'local/data', is_none => 1},
    ]);
  });
} n => 2, name => 'empty packages, insecure';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "http://foo.test/abc/dataset/" . $key => {
        status => 404,
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "http://foo.test/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('add', insecure => 1,
                          additional => ["http://foo.test/abc/dataset/" . $key]);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
      isnt $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', is_none => 1},
      {path => 'local/data', is_none => 1},
    ]);
  });
} n => 3, name => '404';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {},
    {
      "http://foo.test/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "http://foo.test/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["http://foo.test/abc/dataset/" . $key], insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def}, 3;
         is $def->{type}, 'ckan';
         is $def->{url}, "http://foo.test/abc/dataset/".$key;
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is 0+keys %{$json->{url_sha256s}}, 0;
         is 0+keys %{$json->{urls}}, 0;
         is 0+keys %{$json->{items}}, 1;
         my $item = [values %{$json->{items}}]->[0];
         is $item->{files}->{data}, 'package/package.ckan.json';
         is $item->{type}, 'meta';
       }},
      {path => "local/data/$key/package/package.ckan.json", json => sub {
        my $json = shift;
        is 0+@{$json->{result}->{resources}}, 0;
      }},
    ]);
  });
} n => 13, name => 'added to empty package list';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'foo',
      },
    },
    {
      "http://foo.test/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "http://foo.test/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["http://foo.test/abc/dataset/" . $key], insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         is 0+keys %$json, 2;
         is $json->{$key}->{type}, 'foo';
         is 0+keys %{$json->{$key}}, 1;
         my $def = $json->{"$key-2"};
         is 0+keys %{$def}, 3;
         is $def->{type}, 'ckan';
         is $def->{url}, "http://foo.test/abc/dataset/".$key;
       }},
      {path => "local/data/$key-2/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is 0+keys %{$json->{url_sha256s}}, 0;
         is 0+keys %{$json->{urls}}, 0;
         is 0+keys %{$json->{items}}, 1;
         my $item = [values %{$json->{items}}]->[0];
         is $item->{files}->{data}, 'package/package.ckan.json';
         is $item->{type}, 'meta';
       }},
      {path => "local/data/$key-2/package/package.ckan.json", json => sub {
        my $json = shift;
        is 0+@{$json->{result}->{resources}}, 0;
      }},
    ]);
  });
} n => 15, name => 'auto-rename by conflict';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'foo',
      },
      "$key-2" => {
        type => 'foo',
      },
    },
    {
      "http://foo.test/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "http://foo.test/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["http://foo.test/abc/dataset/" . $key], insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         is 0+keys %$json, 3;
         is $json->{$key}->{type}, 'foo';
         is 0+keys %{$json->{$key}}, 1;
         is $json->{"$key-2"}->{type}, 'foo';
         is 0+keys %{$json->{"$key-2"}}, 1;
         my $def = $json->{"$key-3"};
         is 0+keys %{$def}, 3;
         is $def->{type}, 'ckan';
         is $def->{url}, "http://foo.test/abc/dataset/".$key;
       }},
      {path => "local/data/$key-3/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is 0+keys %{$json->{url_sha256s}}, 0;
         is 0+keys %{$json->{urls}}, 0;
         is 0+keys %{$json->{items}}, 1;
         my $item = [values %{$json->{items}}]->[0];
         is $item->{files}->{data}, 'package/package.ckan.json';
         is $item->{type}, 'meta';
       }},
      {path => "local/data/$key-3/package/package.ckan.json", json => sub {
        my $json = shift;
        is 0+@{$json->{result}->{resources}}, 0;
      }},
    ]);
  });
} n => 17, name => 'auto-rename by conflict, 2';

for (
  ['a%5B%5D' => 'a__'],
  ['%00' => '_'],
  ['a%2F%5Cb' => 'a__b'],
  ["1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901", "123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890"],
) {
  my ($in_name, $out_name) = @$_;
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (
      undef,
      {
        "http://foo.test/$key/dataset/" . $in_name => {
          text => q{<meta name="generator" content="ckan 1.2.3">},
        },
        "http://foo.test/$key/api/action/package_show?id=" . $in_name => {
          json => {
            success => \1,
            result => {
              resources => [],
            },
          },
        },
      },
    )->then (sub {
      return $current->run ('add', additional => ["http://foo.test/$key/dataset/" . $in_name], insecure => 1);
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 0;
      } $current->c;
      return $current->check_files ([
        {path => 'config/ddsd/packages.json', json => sub {
           my $json = shift;
           is 0+keys %$json, 1;
           my $def = $json->{$out_name};
           is 0+keys %{$def}, 3;
           is $def->{type}, 'ckan';
           is $def->{url}, "http://foo.test/$key/dataset/".$in_name;
         }},
        {path => "local/data/$out_name/index.json", json => sub {
           my $json = shift;
           is $json->{type}, 'datasnapshot';
           is 0+keys %{$json->{url_sha256s}}, 0;
           is 0+keys %{$json->{urls}}, 0;
           is 0+keys %{$json->{items}}, 1;
           my $item = [values %{$json->{items}}]->[0];
           is $item->{files}->{data}, 'package/package.ckan.json';
           is $item->{type}, 'meta';
         }},
        {path => "local/data/$out_name/package/package.ckan.json", json => sub {
          my $json = shift;
          is 0+@{$json->{result}->{resources}}, 0;
        }},
      ]);
    });
  } n => 13, name => ['bad name', $in_name];
}

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {},
    {
      "https://foo.test/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://foo.test/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => [
      "https://foo.test/abc/dataset/" . $key,
      '--name' => 'hoge123',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{hoge123};
         is 0+keys %{$def}, 3;
         is $def->{type}, 'ckan';
         is $def->{url}, "https://foo.test/abc/dataset/".$key;
       }},
      {path => "local/data/hoge123/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is 0+keys %{$json->{url_sha256s}}, 0;
         is 0+keys %{$json->{urls}}, 0;
         is 0+keys %{$json->{items}}, 1;
         my $item = [values %{$json->{items}}]->[0];
         is $item->{files}->{data}, 'package/package.ckan.json';
         is $item->{type}, 'meta';
       }},
      {path => "local/data/hoge123/package/package.ckan.json", json => sub {
        my $json = shift;
        is 0+@{$json->{result}->{resources}}, 0;
      }},
    ]);
  });
} n => 13, name => '--name';

for my $name (
  '',
  "\x00",
  "\x0A",
  "a/b",
  "q[]",
) {
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (
      undef,
      {
        "https://foo.test/abc/dataset/" . $key => {
          text => q{<meta name="generator" content="ckan 1.2.3">},
        },
        "https://foo.test/abc/api/action/package_show?id=" . $key => {
          json => {
            success => \1,
            result => {
              resources => [],
            },
          },
        },
      },
    )->then (sub {
      return $current->run ('add', additional => [
        "https://foo.test/abc/dataset/" . $key,
        '--name' => $name,
      ]);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'config', is_none => 1},
        {path => "local/data", is_none => 1},
      ]);
    });
  } n => 3, name => ['bad --name', $name];
}

for my $name (
  'abcd',
) {
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (
      {
        $name => {type => 'hoge'},
      },
      {
        "https://foo.test/abc/dataset/" . $key => {
          text => q{<meta name="generator" content="ckan 1.2.3">},
        },
        "https://foo.test/abc/api/action/package_show?id=" . $key => {
          json => {
            success => \1,
            result => {
              resources => [],
            },
          },
        },
      },
    )->then (sub {
      return $current->run ('add', additional => [
        "https://foo.test/abc/dataset/" . $key,
        '--name' => $name,
      ]);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'config/ddsd/packages.json', json => sub {
           my $json = shift;
           is 0+keys %{$json}, 1;
           is $json->{abcd}->{type}, 'hoge';
         }},
        {path => "local/data", is_none => 1},
      ]);
    });
  } n => 5, name => ['conflict --name', $name];
}

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://foo.test/$key" => {
        text => q{hoge},
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://foo.test/$key"]);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
      isnt $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', is_none => 1},
      {path => 'local/data', is_none => 1},
    ]);
  });
} n => 3, name => 'not supported response 1';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://foo.test/$key" => {
        text => q{ {"type": "unknown"} },
        mime => 'application/json',
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://foo.test/$key"]);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
      isnt $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', is_none => 1},
      {path => 'local/data', is_none => 1},
    ]);
  });
} n => 3, name => 'not supported response 2';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
