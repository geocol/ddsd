use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('use', additional => []);
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
} n => 3, name => ['bad argument 0'];

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('use', additional => ['--all']);
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
} n => 3, name => ['bad argument 0 --all'];

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('use', additional => ['hoge', '--all']);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
      isnt $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data', is_none => 1},
    ]);
  });
} n => 3, name => ['bad argument 0 --all'];

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('use', additional => ['hoge', 'fuga', '--all']);
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
} n => 3, name => ['bad argument 0 --all'];

for my $args (
  [""],
  ["notfound"],
  ["//foo/bar"],
  ["javascript:"],
  ["nothttps://foo/bar"],
  ["https://fo/bar"],
  ["hoge", "fiuga"],
  ["#abc"],
  [" #foo"],
) {
  Test {
    my $current = shift;
    return $current->prepare (undef, {})->then (sub {
      return $current->run ('use', additional => [@$args]);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'config/ddsd/packages.json', text => @$args == 2 ? "" : undef,
         is_none => @$args == 1},
        {path => 'local/data', is_none => 1},
      ]);
    });
  } n => 3, name => ['bad argument 1', @$args];
  
  Test {
    my $current = shift; 
    return $current->prepare (undef, {})->then (sub {
      return $current->run ('use', additional => [@$args, 'hoge']);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'config/ddsd/packages.json', text => @$args == 1 ? "" : undef,
         is_none => @$args > 1},
        {path => 'local/data', is_none => 1},
      ]);
    });
  } n => 3, name => ['bad argument 2', @$args];
  
  Test {
    my $current = shift;
    return $current->prepare (undef, {})->then (sub {
      return $current->run ('use', additional => ['hoge', @$args]);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'config/ddsd/packages.json', text => @$args == 1 ? "" : undef,
         is_none => @$args > 1},
        {path => 'local/data', is_none => 1},
      ]);
    });
  } n => 3, name => ['bad argument 3', @$args];
}

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
    return $current->run ('add', additional => [
      "https://hoge/abc/dataset/" . $key,
      '--min',
    ]);
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
         is 0+keys %{$json->{items}}, 1;
         ok $json->{items}->{package};
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r1',
    ]);
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
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{package};
         ok $json->{items}->{"file:id:r1"};
         is $json->{items}->{"file:id:r1"}->{name}, undef;
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r1',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'nop';
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         ok $def->{files}->{"file:id:r2"}->{skip};
         ok $def->{files}->{"file:id:r3"}->{skip};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{package};
         ok $json->{items}->{"file:id:r1"};
         is $json->{items}->{"file:id:r1"}->{name}, undef;
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r2',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         is $def->{files}->{"file:id:r1"}->{name}, undef;
         ok ! $def->{files}->{"file:id:r2"}->{skip};
         is $def->{files}->{"file:id:r2"}->{name}, undef;
         ok $def->{files}->{"file:id:r3"}->{skip};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
         ok $json->{items}->{package};
         ok $json->{items}->{"file:id:r1"};
         ok $json->{items}->{"file:id:r2"};
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", text => "r2"},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  });
} n => 44, name => 'use';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'ckan',
        url => "https://hoge/abc/dataset/" . $key,
        files => {
          "file:id:r1" => {name => "r2"},
          "file:id:r2" => {skip => 1},
          "file:id:r3" => {skip => 1},
        },
      },
    },
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
    return $current->run ('use', additional => [
      $key,
      'file:id:r2',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         my $def = $json->{$key};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         is $def->{files}->{"file:id:r1"}->{name}, "r2";
         ok ! $def->{files}->{"file:id:r2"}->{skip};
         is $def->{files}->{"file:id:r2"}->{name}, "r2-1";
         ok $def->{files}->{"file:id:r3"}->{skip};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
         ok $json->{items}->{package};
         ok $json->{items}->{"file:id:r1"};
         ok $json->{items}->{"file:id:r2"};
       }},
      {path => "local/data/$key/files/r2", text => "r1"},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
      {path => "local/data/$key/files/r2-1", text => "r1"},
    ]);
  })->then (sub {
    return $current->run ('unuse', additional => [
      $key,
      'file:id:r1',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         my $def = $json->{$key};
         ok $def->{files}->{"file:id:r1"}->{skip};
         is $def->{files}->{"file:id:r1"}->{name}, "r2";
         ok ! $def->{files}->{"file:id:r2"}->{skip};
         is $def->{files}->{"file:id:r2"}->{name}, "r2-1";
         ok $def->{files}->{"file:id:r3"}->{skip};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{package};
         ok $json->{items}->{"file:id:r2"};
       }},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
      {path => "local/data/$key/files/r2-1", text => "r1"},
    ]);
  });
} n => 25, name => 'use name confliction';

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
    return $current->run ('add', additional => [
      "https://hoge/abc/dataset/" . $key,
      '--min',
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r10',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 5;
         ok $def->{files}->{"file:id:r1"}->{skip};
         ok $def->{files}->{"file:id:r2"}->{skip};
         ok $def->{files}->{"file:id:r3"}->{skip};
         ok $def->{files}->{"file:id:r10"};
         ok ! $def->{files}->{"file:id:r10"}->{skip};
         is $def->{files}->{"file:id:r10"}->{name}, undef;
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         ok $json->{items}->{package};
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  });
} n => 14, name => 'use file not found';

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
      "https://hoge/" . $key . "/r1" => {text => "r1", status => 404},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('add', additional => [
      "https://hoge/abc/dataset/" . $key,
      '--min',
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r1',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         ok $json->{items}->{package};
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  });
} n => 6, name => 'use file 404';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'ckan',
        url => "https://hoge/abc/dataset/" . $key,
        files => {
          "file:id:r1" => {},
          "file:id:r2" => {skip => 1},
          "file:id:r3" => {skip => 1},
        },
      },
    },
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
        status => 404,
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r2',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 3;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         ok ! $def->{files}->{"file:id:r2"}->{skip};
         ok $def->{files}->{"file:id:r3"}->{skip};
       }},
    ]);
  });
} n => 8, name => 'package 404';

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
    return $current->run ('add', additional => [
      "https://hoge/abc/dataset/" . $key,
      '--min',
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r1',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         ok $def->{files}->{"file:id:r2"}->{skip};
         ok $def->{files}->{"file:id:r3"}->{skip};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         ok $json->{items}->{package};
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r1',
      '--insecure',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         ok $def->{files}->{"file:id:r2"}->{skip};
         ok $def->{files}->{"file:id:r3"}->{skip};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{package};
         ok $json->{items}->{"file:id:r1"};
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  });
} n => 25, name => 'insecure error';

Test {
  my $current = shift;
  my $key = '' . rand;
  my $name = '' . rand;
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
    return $current->run ('add', additional => [
      "https://hoge/abc/dataset/" . $key,
      '--min',
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r1',
      '--name', $name,
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         is $def->{files}->{"file:id:r1"}->{name}, $name;
         ok $def->{files}->{"file:id:r2"}->{skip};
         ok $def->{files}->{"file:id:r3"}->{skip};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{package};
         ok $json->{items}->{"file:id:r1"};
       }},
      {path => "local/data/$key/files/$name", text => "r1"},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r1',
      '--name', "$name.2",
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'name changed';
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         is $def->{files}->{"file:id:r1"}->{name}, "$name.2";
         ok $def->{files}->{"file:id:r2"}->{skip};
         ok $def->{files}->{"file:id:r3"}->{skip};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{package};
         ok $json->{items}->{"file:id:r1"};
       }},
      {path => "local/data/$key/files/$name.2", text => "r1"},
      {path => "local/data/$key/files/$name", is_none => 1},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  });
} n => 28, name => '--name';

Test {
  my $current = shift;
  my $key = '' . rand;
  my $name = '' . rand;
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
    return $current->run ('add', additional => [
      "https://hoge/abc/dataset/" . $key,
      '--min',
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r1',
      '--name', "abc/$name",
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         is $def->{files}->{"file:id:r1"}->{name}, "abc/$name";
         ok $def->{files}->{"file:id:r2"}->{skip};
         ok $def->{files}->{"file:id:r3"}->{skip};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         ok $json->{items}->{package};
       }},
      {path => "local/data/$key/files/abc_2F$name", is_none => 1},
      {path => "local/data/$key/files/abc/$name", is_none => 1},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  });
} n => 13, name => '--name bad name';

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
    return $current->run ('add', additional => [
      "https://hoge/abc/dataset/" . $key,
      '--min',
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r2',
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r1',
      '--name', "r2",
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         is $def->{files}->{"file:id:r1"}->{name}, "r2";
         ok ! $def->{files}->{"file:id:r2"}->{skip};
         is $def->{files}->{"file:id:r2"}->{name}, undef;
         ok $def->{files}->{"file:id:r3"}->{skip};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         ok $json->{items}->{package};
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  });
} n => 14, name => '--name conflicting name';

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
    return $current->run ('add', additional => [
      "https://hoge/abc/dataset/" . $key,
      '--min',
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      '--all',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         is $def->{files}->{"file:id:r1"}->{name}, undef;
         ok ! $def->{files}->{"file:id:r2"}->{skip};
         is $def->{files}->{"file:id:r2"}->{name}, undef;
         ok ! $def->{files}->{"file:id:r3"}->{skip};
         is $def->{files}->{"file:id:r3"}->{name}, undef;
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
         ok $json->{items}->{package};
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", text => "r2"},
      {path => "local/data/$key/files/r3", text => "r3"},
    ]);
  });
} n => 15, name => '--all';

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
    return $current->run ('add', additional => [
      "https://hoge/abc/dataset/" . $key,
      '--min',
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r1',
      '--name' => 'r2',
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      '--all',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         is $def->{files}->{"file:id:r1"}->{name}, 'r2';
         ok ! $def->{files}->{"file:id:r2"}->{skip};
         is $def->{files}->{"file:id:r2"}->{name}, 'r2-1';
         ok ! $def->{files}->{"file:id:r3"}->{skip};
         is $def->{files}->{"file:id:r3"}->{name}, undef;
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
         ok $json->{items}->{package};
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", text => "r1"},
      {path => "local/data/$key/files/r2-1", text => "r2"},
      {path => "local/data/$key/files/r3", text => "r3"},
    ]);
  });
} n => 15, name => '--all, 2';

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
    return $current->run ('add', additional => [
      "https://hoge/abc/dataset/" . $key,
      '--min',
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r1',
      '--name' => 'r1/2',
    ]);
  })->then (sub {
    return $current->run ('use', additional => [
      $key,
      '--all',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         is $def->{files}->{"file:id:r1"}->{name}, 'r1/2';
         ok ! $def->{files}->{"file:id:r2"}->{skip};
         is $def->{files}->{"file:id:r2"}->{name}, undef;
         ok ! $def->{files}->{"file:id:r3"}->{skip};
         is $def->{files}->{"file:id:r3"}->{name}, undef;
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
         ok $json->{items}->{package};
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", text => "r2"},
      {path => "local/data/$key/files/r3", text => "r3"},
    ]);
  });
} n => 15, name => '--all, 3';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/abc/dataset/$key",
            files => {"file:id:r1" => {skip => 1}},
          },
        },
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
    return $current->run ('add', additional => ["https://hoge/$key.json", '--min']);
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
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  })->then (sub {
    return $current->run ('use', additional => [$key, "--all"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 3;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r2"}->{skip};
         is $def->{files}->{"file:id:r2"}->{name}, undef;
         ok ! $def->{files}->{"file:id:r3"}->{skip};
         is $def->{files}->{"file:id:r3"}->{name}, undef;
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", text => "r2"},
      {path => "local/data/$key/files/r3", text => "r3"},
    ]);
  });
} n => 17, name => 'packref --all';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/abc/dataset/$key",
            files => {"file:id:r1" => {skip => 1}},
          },
        },
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
    return $current->run ('add', additional => ["https://hoge/$key.json", '--min']);
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
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  })->then (sub {
    return $current->run ('use', additional => [$key, "file:id:r1"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok $def->{files}->{"file:id:r1"};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         ok $def->{files}->{"file:id:r2"}->{skip};
         ok $def->{files}->{"file:id:r3"}->{skip};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  });
} n => 17, name => 'packref add hidden';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'ckan',
        url => "https://hoge/abc/dataset/" . $key,
        files => {
          "file:id:r1" => {skip => 1},
          "file:id:r2" => {skip => 1},
          "file:id:r3" => {skip => 1},
        },
      },
    },
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
      "https://hoge/" . $key . "/r2" => {text => "r2", status => 404},
      "https://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('use', additional => [
      $key,
      '--all',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok ! $def->{files}->{"file:id:r1"}->{skip};
         is $def->{files}->{"file:id:r1"}->{name}, undef;
         ok ! $def->{files}->{"file:id:r2"}->{skip};
         is $def->{files}->{"file:id:r2"}->{name}, undef;
         ok ! $def->{files}->{"file:id:r3"}->{skip};
         is $def->{files}->{"file:id:r3"}->{name}, undef;
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 3;
         ok $json->{items}->{package};
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", text => "r3"},
    ]);
  });
} n => 15, name => '--all with 404';


Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'ckan',
        url => "https://hoge/abc/dataset/" . $key,
      },
    },
    {
      "https://hoge/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://hoge/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'r2', url => "https://hoge/$key/r2"},
            ],
          },
        },
      },
      "https://hoge/$key/r2" => {
        text => "xyz",
      },
      $current->legal_url_prefix . 'packref.json' => {
        json => {
          type => 'packref',
          source => {
            type => 'files',
            files => {
              'file:r:ckan.json' => {
                url => 'abc',
              },
            },
          },
        },
      },
      $current->legal_url_prefix . 'abc' => {
        text => 'ABC',
      },
    },
  )->then (sub {
    return $current->run ('use', additional => [
      $key,
      'file:id:r2',
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/ddsd/data/legal/index.json', json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 1;
         is $json->{items}->{'file:r:ckan.json'}->{files}->{data}, 'files/abc';
       }},
      {path => 'local/ddsd/data/legal/files/abc', text => 'ABC'},
    ]);
  });
} n => 4, name => 'legal';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
