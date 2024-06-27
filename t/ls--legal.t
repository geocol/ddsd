use strict;
use warnings;
use Path::Tiny;
BEGIN { $ENV{TEST_MAX_CONCUR} = 1 }
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/dataset/$key"},
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [],
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {json => []},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{package_item}->{legal}}, 0;
      }
    } $current->c;
  });
} n => 3, name => 'no legal info';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/dataset/$key"},
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", title => "abc", is => "b-x"},
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {json => []},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{package_item}->{legal}}, 1;
        {
          my $l = $item->{package_item}->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, 'a-x';
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/api/action/package_show?id=$key";
        }
      }
    } $current->c;
  });
} n => 7, name => 'all matched';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/dataset/$key"},
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [],
          license_id => "foo\x{4000}",
          license_url => "bar\x{5000}",
          license_title => "abc\x{6000}",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", title => "abc", is => "b-x"},
          {id => "foo\x{4000}", url => "bar\x{5000}", title => "abc\x{6000}",
           is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {json => []},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{package_item}->{legal}}, 1;
        {
          my $l = $item->{package_item}->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, 'a-x';
        }
      }
    } $current->c;
  });
} n => 5, name => 'non-ascii';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/dataset/$key"},
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {json => []},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{package_item}->{legal}}, 1;
        {
          my $l = $item->{package_item}->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, undef;
          is $l->{license_id}, "foo";
          is $l->{license_url}, "bar";
          is $l->{license_title}, "abc";
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/api/action/package_show?id=$key";
        }
      }
    } $current->c;
  });
} n => 10, name => 'unknown';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/dataset/$key"},
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", title => "abc", is => "b-x"},
          {id => "foo", url => "bar", title => "abc", is => "a-x", db => 1},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {json => []},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{package_item}->{legal}}, 1;
        {
          my $l = $item->{package_item}->{legal}->[0];
          is $l->{type}, 'db_license';
          is $l->{key}, 'a-x';
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/api/action/package_show?id=$key";
        }
      }
    } $current->c;
  });
} n => 7, name => 'db-only license';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/dataset/$key"},
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
          extras => [{key => 'copyright', value => 'Foo'}],
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
          {id => "foo", url => "bar", title => "abc", is => "b-x",
           extras_copyright => 'Foo'},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {json => []},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{package_item}->{legal}}, 1;
        {
          my $l = $item->{package_item}->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, 'b-x';
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/api/action/package_show?id=$key";
        }
      }
    } $current->c;
  });
} n => 7, name => 'extras';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/dataset/$key"},
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
          tags => [{name => 'Foo'}],
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "b-x",
           tag => 'Foo'},
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {json => []},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{package_item}->{legal}}, 1;
        {
          my $l = $item->{package_item}->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, 'b-x';
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/api/action/package_show?id=$key";
        }
      }
    } $current->c;
  });
} n => 7, name => 'tags';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
    },
    {
      "https://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [],
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "b-x",
           tag => 'Foo'},
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "$key-license",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
    },
  )->then (sub {
    $current->set_o (time1 => time);
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    $current->set_o (time2 => time);
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{package_item}->{legal}}, 1;
        {
          my $l = $item->{package_item}->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "$key-license";
          is $l->{source_type}, 'site_legal';
          is $l->{source_url}, undef;
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
        }
      }
    } $current->c;
    $current->set_o (time3 => time);
    return $current->run ('pull', additional => ['--now' => time + 200*60*60]);
  })->then (sub {
    my $r = $_[0];
    $current->set_o (time4 => time);
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'site legal not changed';
    return $current->prepare (undef, {
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "$key-license-2",
        }],
      },
    });
  })->then (sub {
    $current->set_o (time5 => time);
    return $current->run ('pull', additional => ['--now' => time + 400*60*60]);
  })->then (sub {
    my $r = $_[0];
    $current->set_o (time6 => time);
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'site legal changed';
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{package_item}->{legal}}, 2;
        {
          my $l = $item->{package_item}->{legal}->[0];
          is $l->{type}, 'site_license';
          is $l->{key}, "$key-license";
          is $l->{source_type}, 'site_legal';
          is $l->{source_url}, undef;
          is 0+@{$l->{timestamps}}, 2;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
          ok $current->o ('time3') < $l->{timestamps}->[1];
          ok $l->{timestamps}->[1] < $current->o ('time4');
        }
        {
          my $l = $item->{package_item}->{legal}->[1];
          is $l->{type}, 'site_license';
          is $l->{key}, "$key-license-2";
          is $l->{source_type}, 'site_legal';
          is $l->{source_url}, undef;
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time5') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time6');
        }
      }
    } $current->c;
  });
} n => 30, name => 'site legal';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
    },
    {
      "https://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "b-x",
           tag => 'Foo'},
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "$key-license",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
    },
  )->then (sub {
    $current->set_o (time1 => time);
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    $current->set_o (time2 => time);
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{package_item}->{legal}}, 2;
        {
          my $l = $item->{package_item}->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "a-x";
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/$key/api/action/package_show?id=$key";
        }
        {
          my $l = $item->{package_item}->{legal}->[1];
          is $l->{type}, 'site_license';
          is $l->{key}, "$key-license";
          is $l->{source_type}, 'site_legal';
          is $l->{source_url}, undef;
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
        }
      }
    } $current->c;
  });
} n => 14, name => 'site legal and package legal';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
