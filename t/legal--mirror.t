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
      foo => {type => 'ckan', url => "https://1.hoge/dataset/$key"},
    },
    {
      "https://1.hoge/dataset/$key" => {
        text => q{a},
      },
      "https://1.hoge/dataset/activity/$key" => {
        text => q{b},
      },
      "https://1.hoge/api/action/package_show?id=$key" => {
        text => qq{ {"success":true,"result":{"title":"B"}} },
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://1.hoge/",
          source => {type => 'packref', url => "https://1.hoge/$key/license.json"},
          legal_key => "$key-license",
        }],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "$key-license" => {
            "is_free" => "free",
            "notice" => {
              "template" => "abc",
              need_title => 1,
            },
            "lang" => "ja",
          },
        },
      },
      "https://1.hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
    },
    app => 0,
  )->then (sub {
    $current->set_o (time1 => time);
    return $current->run ('pull', app => 0);
  })->then (sub {
    my $r = $_[0];
    $current->set_o (time2 => time);
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1, app => 0);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'site_terms';
          is $l->{key}, "$key-license";
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
        }
        is $item->{is_free}, 'unknown';
      }
    } $current->c;
    return $current->run ('export', additional => ['mirrorzip', 'foo', 'a.zip', '--json'], app => 0, json => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare ({
      foo => {
        type => 'ckan', url => "https://1.hoge/dataset/$key",
        skip_other_files => 1,
        files => {
          package => {
            sha256 => "d2840c3148500190edea68a89ac0769a538776496ee2b29802f096bd3084b651",
          },
        },
      },
    }, {
      "https://1.hoge/api/action/package_show?id=$key" => {
        text => qq{ {"success":true,"result":{}} },
      },
      $current->mirrors_url_prefix . 'hash-ckan-1.hoge.jsonl' => {
        jsonl => [
          ["c4f88fac3e49f4056f066b137730626c474a4a29cd3b91f107be8b12f1183249",
           "https://1.hoge/$key/hash1.zip",
           $r->{json}->{sha256}],
        ],
      },
      "https://1.hoge/$key/hash1.zip" => {
        file => $current->app_path (0)->child ('a.zip'),
      },
      "https://1.hoge/api/action/package_show?id=$key" => {
        status => 404, text => "",
      },
      "https://1.hoge/$key/license.json" => {
        status => 404, text => "",
      },
    }, app => 1);
  })->then (sub {
    return $current->run ('pull', app => 1);
  })->then (sub {
    return $current->prepare (undef, {
      $current->mirrors_url_prefix . 'hash-ckan-2.hoge.jsonl' => {
        json => {},
      },
      "https://1.hoge/$key/hash1.zip" => {
        status => 404, text => "",
      },
    }, app => 1);
  })->then (sub {
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1, app => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'site_terms';
          is $l->{key}, "$key-license";
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
          is $l->{is_free}, 'free';
          is $l->{dir}, 'auto';
          is $l->{source_type}, 'site_legal';
          is $l->{notice}->{template}->{value}, 'abc';
          is $l->{notice}->{template}->{lang}, 'ja';
          is $l->{notice}->{title}->{value}, 'B';
          is $l->{notice}->{title}->{lang}, '';
          is $l->{notice}->{url}, undef;
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{is_free}, 'unknown';
          is $l->{source_type}, 'sniffer';
          is $l->{lang}, '';
          is $l->{notice}, undef;
        }
        is $item->{is_free}, 'unknown';
      }
    } $current->c, name => 'legal unchanged';
    return $current->get_access_count
        ("https://1.hoge/api/action/package_show?id=$key");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'ckan package not accessed';
    } $current->c;
    return $current->get_access_count ("https://1.hoge/");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'ckan top not accessed';
    } $current->c;
    return $current->get_access_count ("https://1.hoge/$key/license.json");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'license not accessed';
    } $current->c;
  });
} n => 37, name => 'freezed legal';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://2.hoge/dataset/$key"},
    },
    {
      "https://2.hoge/dataset/$key" => {
        text => q{a},
      },
      "https://2.hoge/dataset/activity/$key" => {
        text => q{b},
      },
      "https://2.hoge/api/action/package_show?id=$key" => {
        text => qq{ {"success":true,"result":{"title":"B"}} },
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://2.hoge/",
          source => {type => 'packref', url => "https://2.hoge/$key/license.json"},
          legal_key => "$key-license",
        }],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "$key-license" => {
            "is_free" => "free",
            "notice" => {
              "template" => "abc",
              need_title => 1,
            },
            "lang" => "ja",
          },
        },
      },
      "https://2.hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
    },
    app => 0,
  )->then (sub {
    $current->set_o (time1 => time);
    return $current->run ('pull', app => 0);
  })->then (sub {
    my $r = $_[0];
    $current->set_o (time2 => time);
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1, app => 0);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'site_terms';
          is $l->{key}, "$key-license";
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
        }
        is $item->{is_free}, 'unknown';
      }
    } $current->c;
    return $current->run ('export', additional => ['mirrorzip', 'foo', 'a.zip', '--json'], app => 0, json => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare ({
      foo => {
        type => 'packref',
        url => "https://2.hoge/$key/packref",
      },
    }, {
      "https://2.hoge/$key/packref" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan', url => "https://2.hoge/dataset/$key",
            skip_other_files => 1,
            files => {
              package => {
                sha256 => "d2840c3148500190edea68a89ac0769a538776496ee2b29802f096bd3084b651",
              },
            },
          },
        },
      },
      "https://2.hoge/api/action/package_show?id=$key" => {
        text => qq{ {"success":true,"result":{}} },
      },
      $current->mirrors_url_prefix . 'hash-ckan-2.hoge.jsonl' => {
        jsonl => [
          ["c4f88fac3e49f4056f066b137730626c474a4a29cd3b91f107be8b12f1183249",
           "https://2.hoge/$key/hash1.zip",
           $r->{json}->{sha256}],
        ],
      },
      "https://2.hoge/$key/hash1.zip" => {
        file => $current->app_path (0)->child ('a.zip'),
      },
      "https://2.hoge/api/action/package_show?id=$key" => {
        status => 404, text => "",
      },
      "https://2.hoge/$key/license.json" => {
        status => 404, text => "",
      },
    }, app => 1);
  })->then (sub {
    return $current->run ('pull', app => 1);
  })->then (sub {
    return $current->prepare (undef, {
      $current->mirrors_url_prefix . 'hash-ckan-2.hoge.jsonl' => {
        json => {},
      },
      "https://2.hoge/$key/hash1.zip" => {
        status => 404, text => "",
      },
    }, app => 1);
  })->then (sub {
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1, app => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'site_terms';
          is $l->{key}, "$key-license";
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
          is $l->{is_free}, 'free';
          is $l->{dir}, 'auto';
          is $l->{source_type}, 'site_legal';
          is $l->{notice}->{template}->{value}, 'abc';
          is $l->{notice}->{template}->{lang}, 'ja';
          is $l->{notice}->{title}->{value}, 'B';
          is $l->{notice}->{title}->{lang}, '';
          is $l->{notice}->{url}, undef;
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{is_free}, 'unknown';
          is $l->{source_type}, 'sniffer';
          is $l->{lang}, '';
          is $l->{notice}, undef;
        }
        is $item->{is_free}, 'unknown';
      }
    } $current->c, name => 'legal unchanged';
    return $current->get_access_count
        ("https://2.hoge/api/action/package_show?id=$key");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'ckan package not accessed';
    } $current->c;
    return $current->get_access_count ("https://2.hoge/");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'ckan top not accessed';
    } $current->c;
    return $current->get_access_count ("https://2.hoge/$key/license.json");
  })->then (sub {
    my $count = shift;
    test {
      is $count, 0, 'license not accessed';
    } $current->c;
  });
} n => 37, name => 'indirect ';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
