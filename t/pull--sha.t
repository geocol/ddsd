use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        files => {
          "file:id:r1" => {sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"},
          "file:id:r2" => {sha256 => "db77fd01af957221a4989b64b3770a83a3c56068405b9f0e9408feae57fd17e4"},
        },
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1"},
              {id => "r2", url => "http://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1" => {text => "r1"},
      "http://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
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
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
       }},
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', text => "r3"},
    ]);
  });
} n => 5, name => 'sha256 matched';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        files => {
          "file:id:r1" => {sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"},
          "file:id:r2" => {sha256 => "db77fd01af957221a4989b64b3770a83a3c56068405b9f0e9408feae57fd17e5"},
        },
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1"},
              {id => "r2", url => "http://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1" => {text => "r1"},
      "http://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
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
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/files/r2', is_none => 1},
      {path => 'local/data/foo/files/r3', text => "r3"},
    ]);
  });
} n => 5, name => 'sha256 unmatched';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        files => {
          "meta:ckan.json" => {sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"},
        },
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1"},
              {id => "r2", url => "http://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1" => {text => "r1"},
      "http://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo', is_none => 1},
      {path => 'local/data/foo/package-ckan.json', is_none => 1},
      {path => 'local/data/foo/files/r1', is_none => 1},
      {path => 'local/data/foo/files/r2', is_none => 1},
      {path => 'local/data/foo/files/r3', is_none => 1},
    ]);
  });
} n => 2, name => 'sha256 unmatched package';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
      },
    },
    {
      'http://hoge/dataset/package-name-' . $key => {
        text => q{<meta name="generator" content="ckan 1">},
      },
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1"},
              {id => "r2", url => "http://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1" => {text => "r1"},
      "http://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
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
    return $current->prepare (
      undef,
      {
        "http://hoge/" . $key . "/r1" => {text => "R1"},
        "http://hoge/" . $key . "/r2" => {text => "R2"},
        "http://hoge/" . $key . "/r3" => {text => "R3"},
      },
    );
  })->then (sub {
    return $current->run ('add', additional => ['http://hoge/dataset/package-name-' . $key], insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('pull', insecure => 1);
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
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', text => "r3"},
      {path => "local/data/package-name-$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
       }},
      {path => "local/data/package-name-$key/files/r1", text => "R1"},
      {path => "local/data/package-name-$key/files/r2", text => "R2"},
      {path => "local/data/package-name-$key/files/r3", text => "R3"},
    ]);
  });
} n => 17, name => 'snapshot and latest';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        files => {
          "file:id:r1" => {sha256 => "82f3e9c695dc6b8d1b11818d5701919e286de8d47f7c3eb3100c485f79e57828"},
        },
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1"},
              {id => "r2", url => "http://hoge/" . $key . "/r2"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1" => {text => "r1", mime => 'text/html'},
      "http://hoge/" . $key . "/r2" => {text => "r2"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare (
      undef,
      {
        "http://hoge/" . $key . "/r1" => {text => "r1", mime => 'text/css'},
        "http://hoge/" . $key . "/r2" => {text => "R2"},
      },
    );
  })->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         my $item = $json->{items}->{'file:id:r1'};
         is $item->{rev}->{http_content_type}, 'text/html';
       }},
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "R2"},
    ]);
  });
} n => 4, name => 'sha unchanged file';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
