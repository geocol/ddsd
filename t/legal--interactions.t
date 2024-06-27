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
      foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
    },
    {
      "https://hoge/$key/" => {
        text => "",
      },
      "https://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
        }},
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [
          {
            url_prefix => qq<https://hoge/$key/>,
            source => {type => 'packref', url => "https://hoge/$key/license"},
            legal_key => "ABC",
          },
        ],
      },
      "https://hoge/$key/license" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "ABC" => {
            is_free => "free",
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => '2nd pull';
    return $current->get_access_count ("https://hoge/$key/license");
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 1;
    } $current->c;
    return $current->get_access_count ("https://hoge/$key/");
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 0, 'implied terms preferred, site not accessed';
    } $current->c;
  });
} n => 4, name => 'CKAN package and implied terms';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
    },
    {
      "https://hoge/$key/" => {
        text => do {
          use utf8;
          qq{<a href="https://hoge/$key/license.html">利用規約</a>};
        },
      },
      "https://hoge/$key/license.html" => {
        text => qq{},
      },
      "https://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
        }},
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [
          {
            terms_url => qq<https://hoge/$key/license.html>,
            source => {type => 'packref', url => "https://hoge/$key/license"},
            legal_key => "ABC",
          },
        ],
      },
      "https://hoge/$key/license" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "ABC" => {
            is_free => "free",
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->get_access_count ("https://hoge/$key/");
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 1;
    } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => '2nd pull';
    return $current->get_access_count ("https://hoge/$key/license");
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 1;
    } $current->c;
    return $current->get_access_count ("https://hoge/$key/license.html");
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 0;
    } $current->c;
    return $current->get_access_count ("https://hoge/$key/");
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 1;
    } $current->c;
  });
} n => 6, name => 'CKAN site explicit linked';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
    },
    {
      "https://hoge/$key/" => {
        text => "",
      },
      "https://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
        }},
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [
          {
            url_prefix => qq<https://hoge/$key/>,
            source => {type => 'packref', url => "https://hoge/$key/license"},
            legal_key => "ABC",
          },
        ],
      },
      "https://hoge/$key/license" => {
        json => {
          type => 'packref',
          source => {type => 'files', files => {
            'file:r:x' => {url => "http://hoge/$key/license.html"},
          }, insecure => 1},
        },
      },
      "http://hoge/$key/license.html" => {
        text => "",
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('legal', additional => ['foo', '--json'], json => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok $r->{json}->{insecure};
      ok $r->{json}->{legal}->[0]->{insecure};
      ok ! $r->{json}->{legal}->[1]->{insecure};
    } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => '2nd pull';
    return $current->get_access_count ("https://hoge/$key/license");
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 1;
    } $current->c;
    return $current->get_access_count ("http://hoge/$key/license.html");
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 1;
    } $current->c;
    return $current->get_access_count ("https://hoge/$key/");
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 0, 'implied terms preferred, site not accessed';
    } $current->c;
    return $current->run ('legal', additional => ['foo', '--json'], json => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok $r->{json}->{insecure};
      ok $r->{json}->{legal}->[0]->{insecure};
      ok ! $r->{json}->{legal}->[1]->{insecure};
    } $current->c;
  });
} n => 13, name => 'implied insecures';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
