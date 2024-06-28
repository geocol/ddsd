use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

for my $name (
  'notfound',
  '.abc',
  '..',
  '.',
  './hoge',
  './-hoge',
  '/abc',
  '\\abc',
  '',
  '~',
) {
  Test {
    my $current = shift;
    return $current->prepare (undef, {})->then (sub {
      return $current->run ('ls', additional => [$name], lines => 1);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
        is 0+@{$r->{lines}}, 0;
      } $current->c;
      return $current->check_files ([
        {path => 'config', is_none => 1},
        {path => 'local', is_none => 1},
      ]);
    });
  } n => 4, name => ['ls name not found', $name];
}

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('ls', additional => [''], lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
      isnt $r->{exit_code}, 12;
      is 0+@{$r->{lines}}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config', is_none => 1},
      {path => 'local', is_none => 1},
    ]);
  });
} n => 4, name => 'ls name not found';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      abcd => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
          ],
        }},
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['abcd'], lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok grep { /package/ } @{$r->{lines}};
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 1;
      {
        my $f = $r->{jsonl}->[0];
        like $f->{path}, qr{^/.+}; # XXX If Windows,
        is $f->{rev}->{url}, 'http://hoge/api/action/package_show?id=package-name-' . $key;
        is $f->{rev}->{original_url}, 'http://hoge/api/action/package_show?id=package-name-' . $key;
        is $f->{rev}->{length}, 39;
        ok $f->{rev}->{sha256};
        ok $f->{rev}->{timestamp};
        ok $f->{rev}->{http_date};
        is $f->{key}, 'package';
        is $f->{package_item}->{mime}, 'application/json';
        is $f->{package_item}->{title}, '';
      }
    } $current->c;
  });
} n => 15, name => 'package file';

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      abcd => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {url => "http://hoge/file1/" . $key},
          ],
        }},
      },
      "http://hoge/file1/" . $key => {
        text => "abcd",
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['abcd'], lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok grep { /package/ } @{$r->{lines}};
      ok grep { /file1/ } @{$r->{lines}};
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $f = $r->{jsonl}->[0];
        like $f->{path}, qr{^/.+}; # XXX If Windows,
        is $f->{rev}->{url}, 'http://hoge/api/action/package_show?id=package-name-' . $key;
        is $f->{rev}->{original_url}, 'http://hoge/api/action/package_show?id=package-name-' . $key;
        is $f->{rev}->{length}, 79;
        ok $f->{rev}->{sha256};
        ok $f->{rev}->{timestamp};
        ok $f->{rev}->{http_date};
        is $f->{rev}->{http_last_modified}, undef;
        is $f->{rev}->{http_etag}, undef;
        is $f->{key}, 'package';
        is $f->{package_item}->{mime}, 'application/json';
        is $f->{package_item}->{title}, '';
      }
      {
        my $f = $r->{jsonl}->[1];
        like $f->{path}, qr{^/.+}; # XXX If Windows,
        is $f->{rev}->{url}, 'http://hoge/file1/' . $key,
        is $f->{rev}->{original_url}, 'http://hoge/file1/' .  $key;
        is $f->{rev}->{length}, 4;
        ok $f->{rev}->{sha256};
        ok $f->{rev}->{timestamp};
        ok $f->{rev}->{http_date};
        is $f->{rev}->{http_last_modified}, undef;
        is $f->{rev}->{http_etag}, undef;
        is $f->{key}, 'file:index:0';
        is $f->{package_item}->{mime}, 'application/octet-stream';
        is $f->{package_item}->{title}, '';
      }
    } $current->c;
  });
} n => 30, name => 'package with file';

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      abcd => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {
              url => "http://hoge/file1/" . $key,
              mimetype => 'foobar/bazta',
              id => "abrrA\x{4e00}a\x00\x0Db",
              name => "ZFher\x{6314}\x{10000}xaz\x0Aab",
            },
          ],
          hogA => 1,
        }},
      },
      "http://hoge/file1/" . $key => {
        text => "abcd",
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['abcd'], lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok grep { /package/ } @{$r->{lines}};
      ok grep { /file1/ } @{$r->{lines}};
      ok not grep { /CKAN/ } @{$r->{lines}};
      ok not grep { /hogA/ } @{$r->{lines}};
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $f = $r->{jsonl}->[0];
        like $f->{path}, qr{^/.+}; # XXX If Windows,
        is $f->{rev}->{url}, 'http://hoge/api/action/package_show?id=package-name-' . $key;
        is $f->{rev}->{original_url}, 'http://hoge/api/action/package_show?id=package-name-' . $key;
        is $f->{rev}->{length}, 177;
        ok $f->{rev}->{sha256};
        ok $f->{rev}->{timestamp};
        ok $f->{rev}->{http_date};
        is $f->{rev}->{http_last_modified}, undef;
        is $f->{rev}->{http_etag}, undef;
        is $f->{key}, 'package';
        is $f->{package_item}->{mime}, 'application/json';
        is $f->{package_item}->{title}, '';
        is $f->{ckan_package}, undef;
        is $f->{ckan_resource}, undef;
      }
      {
        my $f = $r->{jsonl}->[1];
        like $f->{path}, qr{^/.+}; # XXX If Windows,
        is $f->{rev}->{url}, 'http://hoge/file1/' . $key,
        is $f->{rev}->{original_url}, 'http://hoge/file1/' .  $key;
        is $f->{rev}->{length}, 4;
        ok $f->{rev}->{sha256};
        ok $f->{rev}->{timestamp};
        ok $f->{rev}->{http_date};
        is $f->{rev}->{http_last_modified}, undef;
        is $f->{rev}->{http_etag}, undef;
        is $f->{key}, "file:id:abrrA\x{4e00}a\x00\x0Db";
        is $f->{package_item}->{mime}, 'foobar/bazta';
        is $f->{package_item}->{title}, "ZFher\x{6314}\x{10000}xaz\x0Aab";
        is $f->{ckan_package}, undef;
        is $f->{ckan_resource}, undef;
      }
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--with-source-meta'], lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok grep { /package/ } @{$r->{lines}};
      ok grep { /file1/ } @{$r->{lines}};
      ok grep { /CKAN/ } @{$r->{lines}};
      ok ! grep { /File revision/ } @{$r->{lines}};
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--with-file-meta'], lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok grep { /package/ } @{$r->{lines}};
      ok grep { /file1/ } @{$r->{lines}};
      ok ! grep { /CKAN/ } @{$r->{lines}};
      ok grep { /File revision/ } @{$r->{lines}};
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--with-file-meta', '--with-source-meta'], lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok grep { /package/ } @{$r->{lines}};
      ok grep { /file1/ } @{$r->{lines}};
      ok grep { /CKAN/ } @{$r->{lines}};
      ok grep { /File revision/ } @{$r->{lines}};
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $f = $r->{jsonl}->[0];
        like $f->{path}, qr{^/.+}; # XXX If Windows,
        is $f->{rev}->{url}, 'http://hoge/api/action/package_show?id=package-name-' . $key;
        is $f->{rev}->{original_url}, 'http://hoge/api/action/package_show?id=package-name-' . $key;
        is $f->{rev}->{length}, 177;
        ok $f->{rev}->{sha256};
        ok $f->{rev}->{timestamp};
        ok $f->{rev}->{http_date};
        is $f->{rev}->{http_last_modified}, undef;
        is $f->{rev}->{http_etag}, undef;
        is $f->{key}, 'package';
        is $f->{package_item}->{mime}, 'application/json';
        is $f->{package_item}->{title}, '';
        ok $f->{ckan_package}->{hogA};
        ok $f->{ckan_package}->{resources};
        is $f->{ckan_resource}, undef;
      }
      {
        my $f = $r->{jsonl}->[1];
        like $f->{path}, qr{^/.+}; # XXX If Windows,
        is $f->{rev}->{url}, 'http://hoge/file1/' . $key,
        is $f->{rev}->{original_url}, 'http://hoge/file1/' .  $key;
        is $f->{rev}->{length}, 4;
        ok $f->{rev}->{sha256};
        ok $f->{rev}->{timestamp};
        ok $f->{rev}->{http_date};
        is $f->{rev}->{http_last_modified}, undef;
        is $f->{rev}->{http_etag}, undef;
        is $f->{key}, "file:id:abrrA\x{4e00}a\x00\x0Db";
        is $f->{package_item}->{mime}, 'foobar/bazta';
        is $f->{package_item}->{title}, "ZFher\x{6314}\x{10000}xaz\x0Aab";
        is $f->{ckan_package}, undef;
        is $f->{ckan_resource}->{url}, 'http://hoge/file1/' .  $key;
      }
    } $current->c;
  });
} n => 82, name => 'package with file';

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      abcd => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {url => "http://hoge/file1/" . $key},
          ],
        }},
        last_modified => 665244566,
        mime => 'text/plain',
      },
      "http://hoge/file1/" . $key => {
        text => "abcd",
        last_modified => 4224456,
        mime => 'text/csv',
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $f = $r->{jsonl}->[0];
        is $f->{package_item}->{file_time}, 665244566;
        is $f->{package_item}->{mime}, 'text/plain';
      }
      {
        my $f = $r->{jsonl}->[1];
        is $f->{package_item}->{file_time}, 4224456;
        is $f->{package_item}->{mime}, 'text/csv';
      }
    } $current->c;
  });
} n => 6, name => 'package file metadata from http';

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      abcd => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {
              url => "http://hoge/file1/" . $key,
              last_modified => ckan_timestamp (4224456),
              created => ckan_timestamp (12345),
              mimetype => 'text/csv',
              name => "xyz",
            },
          ],
          metadata_modified => ckan_timestamp (665244566),
          metadata_created => ckan_timestamp (12345),
          title => "ABC",
          name => "abc",
        }},
        mime => 'text/plain',
      },
      "http://hoge/file1/" . $key => {
        text => "abcd",
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $f = $r->{jsonl}->[0];
        is $f->{package_item}->{file_time}, 665244566;
        is $f->{package_item}->{mime}, 'text/plain';
        is $f->{package_item}->{title}, 'ABC';
      }
      {
        my $f = $r->{jsonl}->[1];
        is $f->{package_item}->{file_time}, 4224456;
        is $f->{package_item}->{mime}, 'text/csv';
        is $f->{package_item}->{title}, 'xyz';
      }
    } $current->c;
  });
} n => 8, name => 'package file metadata from package, 1';

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      abcd => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {
              url => "http://hoge/file1/" . $key,
              created => ckan_timestamp (4224456),
              mimetype => 'text/csv',
            },
          ],
          metadata_created => ckan_timestamp (665244566),
          name => "abc",
        }},
        mime => 'text/plain',
      },
      "http://hoge/file1/" . $key => {
        text => "abcd",
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $f = $r->{jsonl}->[0];
        is $f->{package_item}->{file_time}, 665244566;
        is $f->{package_item}->{mime}, 'text/plain';
        is $f->{package_item}->{title}, 'abc';
      }
      {
        my $f = $r->{jsonl}->[1];
        is $f->{package_item}->{file_time}, 4224456;
        is $f->{package_item}->{mime}, 'text/csv';
        is $f->{package_item}->{title}, '';
      }
    } $current->c;
  });
} n => 8, name => 'package file metadata from package, 2';

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      abcd => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {
              url => "http://hoge/file1/" . $key,
            },
          ],
        }},
        date => 665244566,
      },
      "http://hoge/file1/" . $key => {
        text => "abcd",
        date => 4224456,
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $f = $r->{jsonl}->[0];
        is $f->{package_item}->{file_time}, 665244566;
        is $f->{package_item}->{mime}, 'application/json';
        is $f->{package_item}->{title}, '';
      }
      {
        my $f = $r->{jsonl}->[1];
        is $f->{package_item}->{file_time}, 4224456;
        is $f->{package_item}->{mime}, 'application/octet-stream';
        is $f->{package_item}->{title}, '';
      }
    } $current->c;
  });
} n => 8, name => 'package file metadata default';

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      abcd => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-' . $key,
        },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {url => "https://hoge/file1/" . $key},
          ],
        }},
      },
      "https://hoge/file1/" . $key => {
        text => "abcd",
      },
    },
  )->then (sub {
    return $current->run ('ls', additional => ['abcd'], lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok grep { /package/ } @{$r->{lines}};
      ok ! grep { /file1/ } @{$r->{lines}};
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 1;
      {
        my $f = $r->{jsonl}->[0];
        is $f->{path}, undef;
        is $f->{rev}, undef;
        is $f->{package_item}->{mime}, 'application/json';
        is $f->{package_item}->{title}, '';
        is $f->{ckan_package}, undef;
        is $f->{ckan_resource}, undef;
      }
    } $current->c;
  });
} n => 11, name => 'non pulled, ckan';

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      abcd => {
        type => 'packref',
        url => 'https://hoge/dataset/package-name-' . $key,
        },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {url => "https://hoge/file1/" . $key},
          ],
        }},
      },
      "https://hoge/file1/" . $key => {
        text => "abcd",
      },
    },
  )->then (sub {
    return $current->run ('ls', additional => ['abcd'], lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok grep { /package/ } @{$r->{lines}};
      ok ! grep { /file1/ } @{$r->{lines}};
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 1;
      {
        my $f = $r->{jsonl}->[0];
        is $f->{path}, undef;
        is $f->{rev}, undef;
        is $f->{package_item}->{mime}, 'application/json';
        is $f->{package_item}->{title}, '';
        is $f->{ckan_package}, undef;
        is $f->{ckan_resource}, undef;
      }
    } $current->c;
  });
} n => 11, name => 'non pulled, packref';

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      abcd => {
        type => 'ckansite',
        url => 'https://hoge/dataset/package-name-' . $key,
        },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {url => "https://hoge/file1/" . $key},
          ],
        }},
      },
      "https://hoge/file1/" . $key => {
        text => "abcd",
      },
    },
  )->then (sub {
    return $current->run ('ls', additional => ['abcd'], lines => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok grep { /package/ } @{$r->{lines}};
      ok ! grep { /file1/ } @{$r->{lines}};
    } $current->c;
    return $current->run ('ls', additional => ['abcd', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 1;
      {
        my $f = $r->{jsonl}->[0];
        is $f->{path}, undef;
        is $f->{rev}, undef;
        is $f->{package_item}->{mime}, undef;
        is $f->{package_item}->{title}, '';
        is $f->{ckan_package}, undef;
        is $f->{ckan_resource}, undef;
      }
    } $current->c;
  });
} n => 11, name => 'non pulled, ckansiterepo';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
