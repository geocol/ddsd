use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->run ('unuse', additional => [])->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
      isnt $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', is_none => 1},
      {path => 'local', is_none => 1},
    ]);
  });
} n => 3, name => ['bad argument 0'];

for my $args (
  ['--all'],
  ['foo', '--all'],
) {
  Test {
    my $current = shift;
    return $current->run ('unuse', additional => [@$args])->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'config/ddsd/packages.json', is_none => 1},
        {path => 'local', is_none => 1},
      ]);
    });
  } n => 3, name => ['bad argument 0', @$args];
}

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
    return $current->run ('unuse', additional => [@$args])->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'config/ddsd/packages.json', text => @$args == 2 ? "" : undef,
         is_none => @$args == 1},
        {path => 'local', is_none => 1},
      ]);
    });
  } n => 3, name => ['bad argument 1', @$args];
  
  Test {
    my $current = shift;
    return $current->run ('unuse', additional => [@$args, 'hoge'])->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'config/ddsd/packages.json', text => @$args == 1 ? "" : undef,
         is_none => @$args > 1},
        {path => 'local', is_none => 1},
      ]);
    });
  } n => 3, name => ['bad argument 2', @$args];
  
  Test {
    my $current = shift;
    return $current->run ('unuse', additional => ['hoge', @$args])->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'config/ddsd/packages.json', text => @$args == 1 ? "" : undef,
         is_none => @$args > 1},
        {path => 'local', is_none => 1},
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
    return $current->run ('unuse', additional => [
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
         ok $def->{files}->{"file:id:r1"}->{skip};
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
         is 0+keys %$json, 1;
         my $def = $json->{$key};
         is 0+keys %{$def->{files}}, 4;
         ok ! $def->{files}->{packages}->{skip};
         ok $def->{files}->{"file:id:r1"}->{skip};
         is $def->{files}->{"file:id:r1"}->{name}, undef;
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
  });
} n => 39, name => 'unuse';

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
    return $current->run ('unuse', additional => [
      $key,
      'file:id:r10',
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
         ok $def->{files}->{"file:id:r1"}->{skip};
         ok $def->{files}->{"file:id:r2"}->{skip};
         ok $def->{files}->{"file:id:r3"}->{skip};
         ok $def->{files}->{"file:id:r10"}->{skip};
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
} n => 13, name => 'file not found';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
