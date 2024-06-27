use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

for my $pack (
  undef,
  135,
  [],
  "abc",
  {foo => undef},
  {foo => 12},
  {foo => ""},
  {foo => []},
  {foo => {
    type => 'ckan',
    url => "https://foo/",
    files => [],
  }},
  {foo => {
    type => 'ckan',
    url => "https://foo/",
    files => "abc",
  }},
  {foo => {
    type => 'ckan',
    url => "https://foo/",
    files => 0,
  }},
  {foo => {
    type => 'ckan',
    url => "https://foo/",
    files => {
      hoge => [],
    },
  }},
  {foo => {
    type => 'ckan',
    url => "https://foo/",
    files => {
      hoge => undef,
    },
  }},
  {foo => {
    type => 'ckan',
    url => "https://foo/",
    files => {
      hoge => "foo",
    },
  }},
  {foo => {
    type => 'files',
    files => {
      hoge => {url => "https://foo/"},
    },
  }},
) {
  Test {
    my $current = shift;
    return $current->prepare (
      $pack,
      {},
      null => 1,
    )->then (sub {
      return $current->run ('pull');
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
      } $current->c;
      return $current->check_files ([
        {path => 'local', is_none => 1},
      ]);
    });
  } n => 2, name => 'broken package list';
} # $in

for my $code (
  sub { $_[0]->child ('config')->mkpath; $_[0]->child ('config/ddsd')->spew ("abc") }, # not a directory
  sub { $_[0]->child ('config/ddsd')->mkpath; $_[0]->child ('config/ddsd/config.json')->spew ("{}"); chmod 0000, $_[0]->child ('config/ddsd/config.json') },
  sub { $_[0]->child ('config/ddsd')->mkpath; $_[0]->child ('config/ddsd/config.json')->spew ("{}"); chmod 0000, $_[0]->child ('config/ddsd') },
  sub { $_[0]->child ('config/ddsd/config.json')->mkpath },
) {
  Test {
    my $current = shift;
    return Promise->resolve ($current->app_path (0))->then ($code)->then (sub {
      return $current->run ('pull');
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
      } $current->c;
      return $current->check_files ([
        {path => 'local', is_none => 1},
      ]);
    });
  } n => 2, name => 'broken package list file';
} # $in

for my $in (
  {"#hoge" => {}},
  {"#hoge" => "abc"},
  {"   #hoge" => {}},
  {" #hoge" => "abc"},
  {" #" => "abc"},
  {"#" => "abc"},
) {
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (
      {
        %$in,
        foo => {
          type => 'ckan',
          url => 'http://hoge/dataset/package-name-' . $key,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {success => \1, result => {}},
        },
      },
    )->then (sub {
      return $current->run ('pull', insecure => 1);
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
      ]);
    });
  } n => 5, name => 'comments';
} # $in

for my $in (
  {"foo/bar" => {type => "ckan", url => ""}},
  {"foo\\bar" => {type => "ckan", url => ""}},
  {"foobar." => {type => "ckan", url => ""}},
  {".foobar" => {type => "ckan", url => ""}},
  {"-foobar" => {type => "ckan", url => ""}},
  {"~foobar" => {type => "ckan", url => ""}},
  {"" => {type => "ckan", url => ""}},
  {"/abc" => {type => "ckan", url => ""}},
) {
  Test {
    my $current = shift;
    my $key = '' . rand;
    [values %$in]->[0]->{url} = "http://hoge/dataset/package-2-" . $key;
    return $current->prepare (
      {
        %$in,
        foo => {
          type => 'ckan',
          url => 'http://hoge/dataset/package-name-' . $key,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {success => \1, result => {}},
        },
        "http://hoge/api/action/package_show?id=package-2-" . $key => {
          json => {success => \1, result => {}},
        },
      },
    )->then (sub {
      return $current->run ('pull', insecure => 1);
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
           is 0+keys %{$json->{items}}, 1;
         }},
        {path => 'local/data', check => sub {
           my $path = shift;
           is 0+@{[$path->children]}, 1;
         }},
      ]);
    });
  } n => 6, name => ['bad data area name', %$in];
} # $in

for my $in (
  "abc",
  "hoge.txt",
  "FOP.TXT",
  "\x{4e00}",
  "\x{100}\x{2000}",
  ("a" x 60),
  "0",
  "a_b",
  "abcdefghijklmnopqrstuvwxyz",
  "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
  "0123456789-_",
) {
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (
      {
        $in => {
          type => 'ckan',
          url => 'http://hoge/dataset/package-name-' . $key,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {success => \1, result => {
            resources => [{id => 'hoge', url => "http://hoge/$key/hoge"}],
          }},
        },
        "http://hoge/$key/hoge" => {
          text => "ab",
        },
      },
    )->then (sub {
      return $current->run ('pull', insecure => 1);
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 0;
      } $current->c;
      return $current->check_files ([
        {path => "local/data/$in/index.json", json => sub {
           my $json = shift;
           is $json->{type}, 'snapshot';
           is ref $json->{items}, 'HASH';
           is 0+keys %{$json->{items}}, 2;
           ok $json->{items}->{"file:id:hoge"};
         }},
        {path => "local/data/$in/files/hoge", text => sub {
           my $text = shift;
           is $text, "ab";
         }},
      ]);
    });
  } n => 7, name => ['good package name', $in];
  
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://hoge/dataset/package-name-' . $key,
          files => {"file:id:hoge" => {name => $in}},
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {success => \1, result => {
            resources => [{id => 'hoge', url => "http://hoge/$key/"}],
          }},
        },
        "http://hoge/$key/" => {
          text => "ab",
        },
      },
    )->then (sub {
      return $current->run ('pull', insecure => 1);
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
           is 0+keys %{$json->{items}}, 2;
           ok $json->{items}->{"file:id:hoge"};
         }},
        {path => 'local/data/foo/files/'.$in, text => sub {
           my $text = shift;
           is $text, "ab";
         }},
      ]);
    });
  } n => 7, name => ['good file name', $in];
} # $in

for my $in (
  "abc.",
  ("x" x 65),
  "-foo",
  ".foo",
  "",
  "~foo",
  "~",
  "[a]",
  "%00",
  "%80",
  "%FF",
  "\x{90}",
  "a/bc",
  "a\\b",
  "/",
  "\\",
) {
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://hoge/dataset/package-name-' . $key,
          files => {"file:id:hoge" => {name => $in}},
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {success => \1, result => {
            resources => [
              {id => 'hoge', url => "http://hoge/$key/"},
              {id => 'fuga', url => "http://hoge/$key/fuga"},
            ],
          }},
        },
        "http://hoge/$key/" => {
          text => "ab",
        },
        "http://hoge/$key/fuga" => {
          text => "cd",
        },
      },
    )->then (sub {
      return $current->run ('pull', insecure => 1);
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
           ok $json->{items}->{"file:id:fuga"};
         }},
        ((length $in and not $in eq "/" and not $in eq "\\") ? {path => 'local/data/foo/files/'.$in, is_none => 1} : ()),
        {path => 'local/data/foo/files/fuga', text => sub {
           my $text = shift;
           is $text, "cd";
         }},
      ]);
    });
  } n => 7, name => ['bad file name', $in];
} # $in

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        files => {
          "file:id:hoge" => {name => "foo"},
          "file:id:fuga" => {name => "foo"},
        },
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {id => 'hoge', url => "http://hoge/$key/hoge"},
            {id => 'fuga', url => "http://hoge/$key/fuga"},
          ],
        }},
      },
      "http://hoge/$key/hoge" => {
        text => "ab",
      },
      "http://hoge/$key/fuga" => {
        text => "cd",
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
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
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => 'local/data/foo/files/hoge', is_none => 1},
      {path => 'local/data/foo/files/fuga', is_none => 1},
      {path => 'local/data/foo/files/foo', is_none => 1},
    ]);
  });
} n => 5, name => ['dup file name both in packages'];

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        files => {
          "file:id:fuga" => {name => "hoge"},
        },
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {id => 'hoge', url => "http://hoge/$key/hoge"},
            {id => 'fuga', url => "http://hoge/$key/fuga"},
            {id => 'abc', url => "http://hoge/$key/abc"},
          ],
        }},
      },
      "http://hoge/$key/hoge" => {
        text => "ab",
      },
      "http://hoge/$key/fuga" => {
        text => "cd",
      },
      "http://hoge/$key/abc" => {
        text => "abc",
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
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
         ok $json->{items}->{"file:id:abc"};
       }},
      {path => 'local/data/foo/files/hoge', is_none => 1},
      {path => 'local/data/foo/files/fuga', is_none => 1},
      {path => 'local/data/foo/files/abc', text => "abc"},
    ]);
  });
} n => 6, name => ['dup file name in packages and in source'];

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-' . $key,
        files => {
          package => {name => "hoge.txt"},
        },
      },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
            ],
          },
          foo => 1,
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
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
         is 0+keys %{$json->{items}}, 2;
       }},
      {path => 'local/data/foo/files/hoge.txt', json => sub {
         my $json = shift;
         ok $json->{foo};
       }},
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/package-ckan.json', is_none => 1},
    ]);
  });
} n => 6, name => 'package rename';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
