use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

for my $args (
  [],
  [""],
  ["notfound"],
  ["//foo/bar"],
  ["javascript:"],
  ["nothttps://foo/bar"],
  ["https://fo/bar"],
  ["hoge", "fiuga"],
  ["#foo"],
  [" #foo"],
) {
  Test {
    my $current = shift;
    return $current->run ('freeze', additional => $args)->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 2;
      } $current->c;
      return $current->check_files ([
        {path => 'config', is_none => 1},
        {path => 'local', is_none => 1},
      ]);
    });
  } n => 3, name => ['bad argument', @$args];
}

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-' . $key,
        hoge => "abc",
      },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1.txt"},
              {id => "r2", url => "https://hoge/" . $key . "/r2.txt"},
              {id => "r3", url => "https://hoge/" . $key . "/r3.txt"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1.txt" => {text => "r1"},
      "https://hoge/" . $key . "/r2.txt" => {text => "r2"},
      "https://hoge/" . $key . "/r3.txt" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 0);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('freeze', additional => ['foo']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         my $def = $json->{foo};
         is 0+keys %{$def}, 5;
         is $def->{type}, 'ckan';
         is $def->{url}, 'https://hoge/dataset/package-name-' . $key;
         is $def->{hoge}, "abc";
         ok $def->{skip_other_files};
         is 0+keys %{$def->{files}}, 5;
         {
           my $f = $def->{files}->{'meta:ckan.json'};
           is $f->{name}, undef;
           ok $f->{sha256};
           ok ! $f->{sha256_insecure};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r1"};
           is $f->{name}, "r1.txt";
           is $f->{sha256}, "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828";
           ok ! $f->{sha256_insecure};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r2"};
           is $f->{name}, "r2.txt";
           is $f->{sha256}, "db77fd01af957221a4989b64b3770a83a3c56068405b9f0e9408feae57fd17e4";
           ok ! $f->{sha256_insecure};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r3"};
           is $f->{name}, "r3.txt";
           is $f->{sha256}, "e49d63b2a8a78f048bafc4b4590029603a5a4165ee8bf98af15d62f24cd83479";
           ok ! $f->{sha256_insecure};
           ok ! $f->{skip};
         }
       }},
    ]);
  });
} n => 25, name => 'freeze, HTTPS';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        hoge => "abc",
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1.txt"},
              {id => "r2", url => "http://hoge/" . $key . "/r2.txt"},
              {id => "r3", url => "http://hoge/" . $key . "/r3.txt"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1.txt" => {text => "r1"},
      "http://hoge/" . $key . "/r2.txt" => {text => "r2"},
      "http://hoge/" . $key . "/r3.txt" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('freeze', additional => ['foo']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         my $def = $json->{foo};
         is 0+keys %{$def}, 5;
         is $def->{type}, 'ckan';
         is $def->{url}, 'http://hoge/dataset/package-name-' . $key;
         is $def->{hoge}, "abc";
         ok $def->{skip_other_files};
         is 0+keys %{$def->{files}}, 6;
         {
           my $f = $def->{files}->{'meta:ckan.json'};
           is $f->{name}, undef;
           ok $f->{sha256};
           ok $f->{sha256_insecure};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r1"};
           is $f->{name}, "r1.txt";
           is $f->{sha256}, "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828";
           ok $f->{sha256_insecure};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r2"};
           is $f->{name}, "r2.txt";
           is $f->{sha256}, "db77fd01af957221a4989b64b3770a83a3c56068405b9f0e9408feae57fd17e4";
           ok $f->{sha256_insecure};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r3"};
           is $f->{name}, "r3.txt";
           is $f->{sha256}, "e49d63b2a8a78f048bafc4b4590029603a5a4165ee8bf98af15d62f24cd83479";
           ok $f->{sha256_insecure};
           ok ! $f->{skip};
         }
       }},
    ]);
  });
} n => 25, name => 'freeze, --insecure';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        hoge => "abc",
        files => {"meta:ckan.json" => {skip => 1}},
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1.txt"},
              {id => "r2", url => "http://hoge/" . $key . "/r2.txt"},
              {id => "r3", url => "http://hoge/" . $key . "/r3.txt"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1.txt" => {text => "r1"},
      "http://hoge/" . $key . "/r2.txt" => {text => "r2"},
      "http://hoge/" . $key . "/r3.txt" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('freeze', additional => ['foo']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         my $def = $json->{foo};
         is 0+keys %{$def}, 5;
         is $def->{type}, 'ckan';
         is $def->{url}, 'http://hoge/dataset/package-name-' . $key;
         is $def->{hoge}, "abc";
         ok $def->{skip_other_files};
         is 0+keys %{$def->{files}}, 5;
         {
           my $f = $def->{files}->{'meta:ckan.json'};
           is $f->{name}, undef;
           is $f->{sha256}, undef;
           ok $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r1"};
           is $f->{name}, "r1.txt";
           is $f->{sha256}, "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828";
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r2"};
           is $f->{name}, "r2.txt";
           is $f->{sha256}, "db77fd01af957221a4989b64b3770a83a3c56068405b9f0e9408feae57fd17e4";
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r3"};
           is $f->{name}, "r3.txt";
           is $f->{sha256}, "e49d63b2a8a78f048bafc4b4590029603a5a4165ee8bf98af15d62f24cd83479";
           ok ! $f->{skip};
         }
       }},
    ]);
  });
} n => 21, name => 'package skipped';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        hoge => "abc",
        files => {"file:id:r3" => {skip => 1}},
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1.txt"},
              {id => "r2", url => "http://hoge/" . $key . "/r2.txt"},
              {id => "r3", url => "http://hoge/" . $key . "/r3.txt"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1.txt" => {text => "r1"},
      "http://hoge/" . $key . "/r2.txt" => {text => "r2"},
      "http://hoge/" . $key . "/r3.txt" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('freeze', additional => ['foo']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         my $def = $json->{foo};
         is 0+keys %{$def}, 5;
         is $def->{type}, 'ckan';
         is $def->{url}, 'http://hoge/dataset/package-name-' . $key;
         is $def->{hoge}, "abc";
         ok $def->{skip_other_files};
         is 0+keys %{$def->{files}}, 5;
         {
           my $f = $def->{files}->{'meta:ckan.json'};
           is $f->{name}, undef;
           ok $f->{sha256};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r1"};
           is $f->{name}, "r1.txt";
           is $f->{sha256}, "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828";
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r2"};
           is $f->{name}, "r2.txt";
           is $f->{sha256}, "db77fd01af957221a4989b64b3770a83a3c56068405b9f0e9408feae57fd17e4";
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r3"};
           is $f->{name}, undef;
           is $f->{sha256}, undef;
           ok $f->{skip};
         }
       }},
    ]);
  });
} n => 21, name => 'some file skipped';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        hoge => "abc",
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1.txt"},
              {id => "r2", url => "http://hoge/" . $key . "/r2.txt"},
              {id => "r3", url => "http://hoge/" . $key . "/r3.txt/"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1.txt" => {text => "r1"},
      "http://hoge/" . $key . "/r2.txt" => {text => "r2"},
      "http://hoge/" . $key . "/r3.txt/" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->run ('freeze', additional => ['foo']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         my $def = $json->{foo};
         is 0+keys %{$def}, 5;
         is $def->{type}, 'ckan';
         is $def->{url}, 'http://hoge/dataset/package-name-' . $key;
         is $def->{hoge}, "abc";
         ok $def->{skip_other_files};
         is 0+keys %{$def->{files}}, 6;
         {
           my $f = $def->{files}->{'meta:ckan.json'};
           is $f->{name}, undef;
           ok $f->{sha256};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r1"};
           is $f->{name}, "r1.txt";
           is $f->{sha256}, "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828";
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r2"};
           is $f->{name}, "r2.txt";
           is $f->{sha256}, "db77fd01af957221a4989b64b3770a83a3c56068405b9f0e9408feae57fd17e4";
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r3"};
           is $f->{name}, undef;
           is $f->{sha256}, undef;
           ok $f->{skip};
         }
       }},
    ]);
  });
} n => 21, name => 'implicit skipped';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        hoge => "abc",
        files => {"file:id:r3" => {name => "abcdefg"}},
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1.txt"},
              {id => "r2", url => "http://hoge/" . $key . "/r2.txt"},
              {id => "r3", url => "http://hoge/" . $key . "/r3.txt"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1.txt" => {text => "r1"},
      "http://hoge/" . $key . "/r2.txt" => {text => "r2"},
      "http://hoge/" . $key . "/r3.txt" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('freeze', additional => ['foo']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         my $def = $json->{foo};
         is 0+keys %{$def}, 5;
         is $def->{type}, 'ckan';
         is $def->{url}, 'http://hoge/dataset/package-name-' . $key;
         is $def->{hoge}, "abc";
         ok $def->{skip_other_files};
         is 0+keys %{$def->{files}}, 6;
         {
           my $f = $def->{files}->{'package'};
           is $f->{name}, undef;
           is $f->{sha256}, undef;
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{'meta:ckan.json'};
           is $f->{name}, undef;
           ok $f->{sha256};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r1"};
           is $f->{name}, "r1.txt";
           is $f->{sha256}, "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828";
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r2"};
           is $f->{name}, "r2.txt";
           is $f->{sha256}, "db77fd01af957221a4989b64b3770a83a3c56068405b9f0e9408feae57fd17e4";
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r3"};
           is $f->{name}, "abcdefg";
           is $f->{sha256}, "e49d63b2a8a78f048bafc4b4590029603a5a4165ee8bf98af15d62f24cd83479";
           ok ! $f->{skip};
         }
       }},
    ]);
  });
} n => 24, name => 'name replaced';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'packref',
        url => "https://hoge/$key/packref.json",
        hoge => "abc",
      },
    },
    {
      "https://hoge/$key/packref.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => 'https://hoge/dataset/package-name-' . $key,
          },
        },
      },
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1.txt"},
              {id => "r2", url => "https://hoge/" . $key . "/r2.txt"},
              {id => "r3", url => "https://hoge/" . $key . "/r3.txt"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1.txt" => {text => "r1"},
      "https://hoge/" . $key . "/r2.txt" => {text => "r2"},
      "https://hoge/" . $key . "/r3.txt" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 0);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('freeze', additional => ['foo']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         my $def = $json->{foo};
         is 0+keys %{$def}, 5;
         is $def->{type}, 'packref';
         is $def->{url}, "https://hoge/$key/packref.json";
         is $def->{hoge}, "abc";
         ok $def->{skip_other_files};
         is 0+keys %{$def->{files}}, 6;
         {
           my $f = $def->{files}->{package};
           is $f->{name}, undef;
           is $f->{sha256}, undef;
           ok ! $f->{sha256_insecure};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{'meta:ckan.json'};
           is $f->{name}, undef;
           ok $f->{sha256};
           ok ! $f->{sha256_insecure};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r1"};
           is $f->{name}, "r1.txt";
           is $f->{sha256}, "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828";
           ok ! $f->{sha256_insecure};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r2"};
           is $f->{name}, "r2.txt";
           is $f->{sha256}, "db77fd01af957221a4989b64b3770a83a3c56068405b9f0e9408feae57fd17e4";
           ok ! $f->{sha256_insecure};
           ok ! $f->{skip};
         }
         {
           my $f = $def->{files}->{"file:id:r3"};
           is $f->{name}, "r3.txt";
           is $f->{sha256}, "e49d63b2a8a78f048bafc4b4590029603a5a4165ee8bf98af15d62f24cd83479";
           ok ! $f->{sha256_insecure};
           ok ! $f->{skip};
         }
       }},
    ]);
  });
} n => 29, name => 'packref';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
