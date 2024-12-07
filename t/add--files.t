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
      "http://foo.test/abc/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "http://foo.test/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {
                "id" => "hoge123",
                "url" => "http://foo.test/hoge123/" . $key . "/foo.txt",
              },
            ],
          },
        },
      },
      "http://foo.test/hoge123/" . $key . "/foo.txt" => {
        text => "abc def",
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
         is 0+keys %{$def}, 2;
         is $def->{type}, 'ckan';
         is $def->{url}, "http://foo.test/abc/dataset/".$key;
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is 0+keys %{$json->{url_sha256s}}, 0;
         is 0+keys %{$json->{urls}}, 0;
         is 0+keys %{$json->{items}}, 2;
         {
           my $item = $json->{items}->{package};
           is $item->{files}->{data}, 'package.ckan.json';
           is $item->{type}, 'package';
         }
         {
           my $item = $json->{items}->{"file:id:hoge123"};
           is $item->{files}->{data}, 'files/foo.txt';
           is $item->{type}, 'file';
         }
         is $json->{source}->{type}, 'ckan';
         is $json->{source}->{url}, "http://foo.test/abc/api/action/package_show?id=" . $key;
       }},
      {path => "local/data/$key/package/package.ckan.json", json => sub {
        my $json = shift;
        is 0+@{$json->{result}->{resources}}, 1;
      }},
      {path => "local/data/$key/files/foo.txt", text => sub {
        is $_[0], "abc def";
      }},
    ]);
  });
} n => 17, name => 'a file';

for (
  ["\x00\x01_.txt" => "_00_01_.txt"],
  ["%00%1F.txt" => "_00_1F.txt"],
  ["%0A%0D_.txt" => "_0A_0D_.txt"],
  ["-foo\x01." => "_2Dfoo_01_2E"],
  [".foo\x01-" => "_2Efoo_01-"],
  ["\x{4e00}abc" => "\x{4e00}abc", 1],
  ["abc...def" => "abc...def", 1],
  [q{a<>"_qt~} => "a_3C_3E_22_qt_7E"],
  ["ab-cd-AX012" => "ab-cd-AX012", 1],
  ["a/b/c.txt" => "c.txt", 1],
  ["a/b/c\\d.txt" => "d.txt", 1],
  ["a/b/c%2Fd.txt" => "c_2Fd.txt"],
  ["a/b/c%2F%5Cd.txt" => "c_2F_5Cd.txt"],
  ["\x{10000}" => "\x{10000}", 1],
  ["%EF%BF%BE" => "\x{FFFE}", 1],
  ["%EF%BF%BF" => "\x{FFFF}", 1],
  ["%F4%8F%BF%BF" => "\x{10FFFF}", 1],
) {
  my ($name1, $name2, $flag) = @$_;
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
              resources => [
                {
                  "id" => "hoge123",
                  "url" => "http://foo.test/hoge123/" . $key . "/" . $name1,
                },
              ],
            },
          },
        },
        "http://foo.test/hoge123/" . $key . "/" . $name1 => {
          text => "abc def",
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
        {path => "local/data/$key/index.json", json => sub {
           my $json = shift;
           is $json->{type}, 'snapshot';
           {
             my $item = $json->{items}->{"file:id:hoge123"};
             is $item->{files}->{data}, 'files/' . $name2;
             is $item->{type}, 'file';
           }
         }},
        {path => "local/data/$key/files/" . $name2, text => sub {
           is $_[0], "abc def";
         }},
        {path => 'config/ddsd/packages.json', json => sub {
           my $json = shift;
           my $def = $json->{$key};
           if ($flag) {
             is 0+keys %{$def}, 2;
             ok 1;
           } else {
             is 0+keys %{$def}, 3;
             is $def->{files}->{"file:id:hoge123"}->{name}, $name2;
           }
           is $def->{type}, 'ckan';
           is $def->{url}, "http://foo.test/abc/dataset/".$key;
         }},
      ]);
    });
  } n => 10, name => ['filename', $name1];
}

for (
  "%80",
  "%ED%9F%C0", # U+D900
  "%EF%BF%BD", # U+FFFD
) {
  my $name1 = $_;
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
              resources => [
                {
                  "id" => "hoge123",
                  "url" => "http://foo.test/hoge123/" . $key . "/" . $name1,
                },
              ],
            },
          },
        },
        "http://foo.test/hoge123/" . $key . "/" . $name1 => {
          text => "abc def",
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
        {path => "local/data/$key/index.json", json => sub {
           my $json = shift;
           is $json->{type}, 'snapshot';
           is 0+keys %{$json->{items}}, 2;
           {
             my $item = $json->{items}->{"file:id:hoge123"};
             is $item->{type}, "file";
             is $item->{files}->{data}, "files/1";
           }
         }},
        {path => "local/data/$key/files/" . $name1, is_none => 1},
        {path => "local/data/$key/files/1", text => sub {
           my $text = shift;
           is $text, "abc def";
         }},
        {path => 'config/ddsd/packages.json', json => sub {
           my $json = shift;
           my $def = $json->{$key};
           is 0+keys %{$def}, 3;
           is $def->{type}, 'ckan';
           is $def->{url}, "http://foo.test/abc/dataset/".$key;
           is 0+keys %{$def->{files}}, 1;
           is $def->{files}->{"file:id:hoge123"}->{name}, "1";
         }},
      ]);
    });
  } n => 12, name => ['broken filename', $name1];
}

for my $in (
  {url => undef},
  {size => 1024*1024*1024},
  {url => q<https://hoge.test/{foo}>},
  {url => q<hoge://>},
  {url => q<javascript:>},
  {url => q<foo bar>},
  {url => q<https://hoge:fuga>},
) {
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
              resources => [
                {
                  "id" => "hoge123",
                  "url" => "http://foo.test/hoge123/" . $key,
                  %$in,
                },
              ],
            },
          },
        },
        "http://foo.test/hoge123/" . $key => {
          text => "abc def",
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
        {path => "local/data/$key/index.json", json => sub {
           my $json = shift;
           is $json->{type}, 'snapshot';
           is 0+keys %{$json->{items}}, 1;
         }},
        {path => "local/data/$key/files/1", is_none => 1},
        {path => 'config/ddsd/packages.json', json => sub {
           my $json = shift;
           my $def = $json->{$key};
           is 0+keys %{$def}, 3;
           is $def->{type}, 'ckan';
           is $def->{url}, "http://foo.test/abc/dataset/".$key;
           is 0+keys %{$def->{files}}, 1;
           ok $def->{files}->{"file:id:hoge123"}->{skip};
         }},
      ]);
    });
  } n => 9, name => ['disabled resource', %$in];
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
            resources => [
              {"id" => "r1", "url" => "http://foo.test/" . $key . "/r1"},
              {"id" => "r2", "url" => "http://foo.test/" . $key . "/r2"},
              {"id" => "r3", "url" => "http://foo.test/" . $key . "/r3"},
              {"id" => "r4", "url" => "http://foo.test/" . $key . "/r4"},
              {"id" => "r5", "url" => "http://foo.test/" . $key . "/r5"},
              {"id" => "r6", "url" => "http://foo.test/" . $key . "/r6"},
              {"id" => "r7", "url" => "http://foo.test/" . $key . "/r7"},
              {"id" => "r8", "url" => "http://foo.test/" . $key . "/r8"},
              {"id" => "r9", "url" => "http://foo.test/" . $key . "/r9"},
              {"id" => "r10", "url" => "http://foo.test/" . $key . "/r10"},
              {"id" => "r11", "url" => "http://foo.test/" . $key . "/r11"},
            ],
          },
        },
      },
      "http://foo.test/" . $key . "/r1" => {text => "r1"},
      "http://foo.test/" . $key . "/r2" => {text => "r2"},
      "http://foo.test/" . $key . "/r3" => {text => "r3"},
      "http://foo.test/" . $key . "/r4" => {text => "r4"},
      "http://foo.test/" . $key . "/r5" => {text => "r5"},
      "http://foo.test/" . $key . "/r6" => {text => "r6"},
      "http://foo.test/" . $key . "/r7" => {text => "r7"},
      "http://foo.test/" . $key . "/r8" => {text => "r8"},
      "http://foo.test/" . $key . "/r9" => {text => "r9"},
      "http://foo.test/" . $key . "/r10" => {text => "r10"},
      "http://foo.test/" . $key . "/r11" => {text => "r11"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["http://foo.test/abc/dataset/" . $key], insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is 0+keys %{$json->{items}}, 11;
       }},
      {path => "local/data/$key/files/r1", text => "r1"},
      {path => "local/data/$key/files/r2", text => "r2"},
      {path => "local/data/$key/files/r3", text => "r3"},
      {path => "local/data/$key/files/r4", text => "r4"},
      {path => "local/data/$key/files/r5", text => "r5"},
      {path => "local/data/$key/files/r6", text => "r6"},
      {path => "local/data/$key/files/r7", text => "r7"},
      {path => "local/data/$key/files/r8", text => "r8"},
      {path => "local/data/$key/files/r9", text => "r9"},
      {path => "local/data/$key/files/r10", text => "r10"},
      {path => "local/data/$key/files/r11", is_none => 1},
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         my $def = $json->{$key};
         is 0+keys %{$def}, 3;
         is $def->{type}, 'ckan';
         is $def->{url}, "http://foo.test/abc/dataset/".$key;
         is 0+keys %{$def->{files}}, 1;
         ok $def->{files}->{"file:id:r11"}->{skip};
       }},
    ]);
  });
} n => 9, name => ['many resources'];

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
    return $current->run ('add',
                          additional => ["https://hoge/abc/dataset/" . $key,
                                         '--min']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         my $def = $json->{$key};
         ok ! $def->{files}->{package};
         ok ! $def->{files}->{package}->{skip};
         ok $def->{files}->{"file:id:r1"}->{skip};
         ok $def->{files}->{"file:id:r2"}->{skip};
         ok $def->{files}->{"file:id:r3"}->{skip};
         ok ! $def->{skip_other_files};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         ok ! $json->{items}->{package}->{rev}->{insecure};
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  });
} n => 12, name => '--min';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      xyz => {
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
    return $current->run ('pull');
  })->then (sub {
    return $current->run ('add',
                          additional => ["https://hoge/abc/dataset/" . $key,
                                         '--min']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         my $def = $json->{$key};
         ok ! $def->{files}->{package};
         ok ! $def->{files}->{package}->{skip};
         ok $def->{files}->{"file:id:r1"}->{skip};
         ok $def->{files}->{"file:id:r2"}->{skip};
         ok $def->{files}->{"file:id:r3"}->{skip};
         ok ! $def->{skip_other_files};
       }},
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'snapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         ok ! $json->{items}->{package}->{rev}->{insecure};
       }},
      {path => "local/data/$key/files/r1", is_none => 1},
      {path => "local/data/$key/files/r2", is_none => 1},
      {path => "local/data/$key/files/r3", is_none => 1},
    ]);
  });
} n => 12, name => '--min after fetched';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
