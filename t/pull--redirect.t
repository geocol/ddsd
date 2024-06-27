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
        url => 'https://hoge/dataset/package-name-' . $key,
      },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
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
      "https://hoge/" . $key . "/r3" => {text => "r3", redirect => "r4.txt"},
      "https://hoge/" . $key . "/r4.txt" => {text => "r4"},
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
         is 0+keys %{$json->{items}}, 4;
         ok ! $json->{items}->{package}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', is_none => 1},
      {path => 'local/data/foo/files/r4.txt', text => "r4"},
    ]);
  })->then (sub {
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $file = $r->{jsonl}->[3];
        ok ! $file->{rev}->{insecure};
        is $file->{rev}->{sha256}, "a2ec8adac7fd24b4b7a8edd89d06990579f6123f5724a14b47ee4bddfb2ba572";
        is $file->{rev}->{url}, "https://hoge/" . $key . "/r4.txt";
        is $file->{rev}->{original_url}, "https://hoge/" . $key . "/r3";
      }
    } $current->c;
  });
} n => 15, name => 'redirect followed';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-' . $key,
      },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
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
      "https://hoge/" . $key . "/r3" => {text => "r3",
                                         redirect => "http://hoge/$key/r4.txt"},
      "http://hoge/" . $key . "/r4.txt" => {text => "r4"},
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
         is 0+keys %{$json->{items}}, 4;
         ok ! $json->{items}->{package}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', is_none => 1},
      {path => 'local/data/foo/files/r4.txt', text => "r4"},
    ]);
  })->then (sub {
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $file = $r->{jsonl}->[3];
        ok $file->{rev}->{insecure};
        is $file->{rev}->{sha256}, "a2ec8adac7fd24b4b7a8edd89d06990579f6123f5724a14b47ee4bddfb2ba572";
        is $file->{rev}->{url}, "http://hoge/" . $key . "/r4.txt";
        is $file->{rev}->{original_url}, "https://hoge/" . $key . "/r3";
      }
    } $current->c;
  });
} n => 15, name => 'redirected to insecure, --insecure';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-' . $key,
      },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
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
      "https://hoge/" . $key . "/r3" => {text => "r3",
                                         redirect => "http://hoge/$key/r4.txt"},
      "http://hoge/" . $key . "/r4.txt" => {text => "r4"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 0);
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
         is 0+keys %{$json->{items}}, 3;
         ok ! $json->{items}->{package}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
       }},
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', is_none => 1},
      {path => 'local/data/foo/files/r4.txt', is_none => 1},
    ]);
  })->then (sub {
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $file = $r->{jsonl}->[3];
        is $file->{rev}, undef;
      }
    } $current->c;
  });
} n => 11, name => 'redirected to insecure, not allowed';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-' . $key,
      },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
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
      "https://hoge/" . $key . "/r3" => {text => "r3",
                                         redirect => "http://hoge/$key/r4.txt"},
      "https://hoge/" . $key . "/r4.txt" => {text => "r4"},
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
         is 0+keys %{$json->{items}}, 4;
         ok ! $json->{items}->{package}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', is_none => 1},
      {path => 'local/data/foo/files/r4.txt', text => "r4"},
    ]);
  })->then (sub {
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $file = $r->{jsonl}->[3];
        ok ! $file->{rev}->{insecure};
        is $file->{rev}->{sha256}, "a2ec8adac7fd24b4b7a8edd89d06990579f6123f5724a14b47ee4bddfb2ba572";
        is $file->{rev}->{url}, "https://hoge/" . $key . "/r4.txt";
        is $file->{rev}->{original_url}, "https://hoge/" . $key . "/r3";
      }
    } $current->c;
  });
} n => 15, name => 'redirected to insecure, auto-upgraded';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-' . $key,
      },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
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
      "https://hoge/" . $key . "/r3" => {text => "r3",
                                         redirect => "http://hoge/$key/r4.txt"},
      "http://hoge/" . $key . "/r4.txt" => {text => "r4",
                                            redirect => "http://hoge/$key/r5.txt"},
      "https://hoge/" . $key . "/r5.txt" => {text => "r5"},
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
         is 0+keys %{$json->{items}}, 4;
         ok ! $json->{items}->{package}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', is_none => 1},
      {path => 'local/data/foo/files/r4.txt', is_none => 1},
      {path => 'local/data/foo/files/r5.txt', text => "r5"},
    ]);
  })->then (sub {
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $file = $r->{jsonl}->[3];
        ok $file->{rev}->{insecure};
        is $file->{rev}->{sha256}, "5eb242aeb68552862913d602cff36deb4cafc18a46cfdea393b4bc1c6917a669";
        is $file->{rev}->{url}, "https://hoge/" . $key . "/r5.txt";
        is $file->{rev}->{original_url}, "https://hoge/" . $key . "/r3";
      }
    } $current->c;
  });
} n => 15, name => 'redirected to insecure to secure';

for my $loc (
  'error',
  'https://badserver.test',
  'https://hoge:foo',
  'data:,abc',
  'javascript:',
) {
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'https://hoge/dataset/package-name-' . $key,
        },
      },
      {
        "https://hoge/api/action/package_show?id=package-name-" . $key => {
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
        "https://hoge/" . $key . "/r3" => {text => "r3",
                                           redirect => $loc},
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
         is 0+keys %{$json->{items}}, 3;
         ok ! $json->{items}->{package}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
       }},
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', is_none => 1},
    ]);
  })->then (sub {
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $file = $r->{jsonl}->[3];
        is $file->{rev}, undef;
      }
    } $current->c;
  });
} n => 11, name => 'redirected to error', $loc;
}

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-' . $key,
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
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1", redirect => "r2"},
      "https://hoge/" . $key . "/r2" => {text => "r2", redirect => "r3"},
      "https://hoge/" . $key . "/r3" => {text => "r3", redirect => "r4"},
      "https://hoge/" . $key . "/r4" => {text => "r4", redirect => "r5"},
      "https://hoge/" . $key . "/r5" => {text => "r5", redirect => "r6"},
      "https://hoge/" . $key . "/r6" => {text => "r6", redirect => "r7"},
      "https://hoge/" . $key . "/r7" => {text => "r7", redirect => "r8"},
      "https://hoge/" . $key . "/r8" => {text => "r8", redirect => "r9"},
      "https://hoge/" . $key . "/r9" => {text => "r9", redirect => "r10"},
      "https://hoge/" . $key . "/r10" => {text => "r10", redirect => "r11"},
      "https://hoge/" . $key . "/r11" => {text => "r11", redirect => "r12"},
      "https://hoge/" . $key . "/r12" => {text => "r12", redirect => "r13"},
      "https://hoge/" . $key . "/r13" => {text => "r13", redirect => "r14"},
      "https://hoge/" . $key . "/r14" => {text => "r14", redirect => "r15"},
      "https://hoge/" . $key . "/r15" => {text => "r15", redirect => "r16"},
      "https://hoge/" . $key . "/r16" => {text => "r16", redirect => "r17"},
      "https://hoge/" . $key . "/r17" => {text => "r17", redirect => "r18"},
      "https://hoge/" . $key . "/r18" => {text => "r18", redirect => "r19"},
      "https://hoge/" . $key . "/r19" => {text => "r19", redirect => "r20"},
      "https://hoge/" . $key . "/r20" => {text => "r20", redirect => "r21"},
      "https://hoge/" . $key . "/r21" => {text => "r21", redirect => "r22"},
      "https://hoge/" . $key . "/r22" => {text => "r22"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 0);
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
         ok ! $json->{items}->{package}->{rev}->{insecure};
       }},
      {path => 'local/data/foo/files/r1', is_none => 1},
      {path => 'local/data/foo/files/r19', is_none => 1},
      {path => 'local/data/foo/files/r20', is_none => 1},
      {path => 'local/data/foo/files/r21', is_none => 1},
    ]);
  })->then (sub {
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $file = $r->{jsonl}->[1];
        is $file->{rev}, undef;
      }
    } $current->c;
  });
} n => 9, name => 'redirected depth';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
