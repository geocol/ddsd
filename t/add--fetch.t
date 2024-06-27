use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "http://hoge/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "http://hoge/abc/api/action/package_show?id=" . $key => {
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
    return $current->run ('add', additional => ["http://hoge/abc/dataset/" . $key], insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
         ok $json->{items}->{package}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", text => "r2"},
      {path => "local/data/$key/files/r3", text => "r3"},
    ]);
  });
} n => 9, name => 'ok';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "http://hoge/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "http://hoge/abc/api/action/package_show?id=" . $key => {
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
      "http://hoge/" . $key . "/r2" => {text => "r2", status => 404},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["http://hoge/abc/dataset/" . $key], insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", text => "r3"},
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         my $def = $json->{$key};
         ok $def->{files}->{"file:id:r2"}->{skip};
       }},
    ]);
  });
} n => 6, name => 'has 404';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "http://hoge/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "http://hoge/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge.badserver.test/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1" => {text => "r1"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["http://hoge/abc/dataset/" . $key], insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", text => "r3"},
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         my $def = $json->{$key};
         ok $def->{files}->{"file:id:r2"}->{skip};
       }},
    ]);
  });
} n => 6, name => 'has network error';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://hoge/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge.badserver.test/" . $key . "/r2"},
              {id => "r3", url => "https://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/abc/dataset/" . $key], insecure => 0, cacert => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", text => "r3"},
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         my $def = $json->{$key};
         ok $def->{files}->{"file:id:r2"}->{skip};
       }},
    ]);
  });
} n => 6, name => 'has network error, HTTPS';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://hoge/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "https://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/abc/dataset/" . $key], insecure => 0);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
         ok ! $json->{items}->{package}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", text => "r2"},
      {path => "local/data/$key/files/r3", text => "r3"},
    ]);
  });
} n => 9, name => 'ok HTTPS';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://hoge/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/abc/dataset/" . $key], insecure => 0);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
         ok ! $json->{items}->{package}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", text => "r2"},
    ]);
  });
} n => 8, name => 'has insecure, no --insecure';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://hoge/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/abc/dataset/" . $key], insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
         ok $json->{items}->{package}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", text => "r2"},
      {path => "local/data/$key/files/r3", text => "r3"},
    ]);
  });
} n => 9, name => 'has --insecure resource';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["http://hoge/abc/dataset/" . $key]);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
      isnt $r->{exit_code}, 2;
    } $current->c;
    return $current->check_files ([
      {path => "config", is_none => 1},
      {path => "local", is_none => 1},
    ]);
  });
} n => 3, name => 'ckan package 404';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
