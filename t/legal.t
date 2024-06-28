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
    },
  )->then (sub {
    return $current->run ('legal', additional => ['bar', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
      isnt $r->{exit_code}, 12;
    } $current->c;
  });
} n => 2, name => 'no repo';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->prepare ({
      foo => {type => 'ckan', url => "https://hoge/dataset/$key"},
    }, {
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
    });
  })->then (sub {
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, '-ddsd-unknown';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 12, name => 'no local copy';

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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, '-ddsd-unknown';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 13, name => 'no legal info';

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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "a-x";
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/$key/api/action/package_show?id=$key";
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "$key-license";
          is $l->{source_type}, 'site_legal';
          is $l->{source_url}, undef;
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 22, name => 'site legal and package legal';

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
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "$key-license" => {
            is_free => "sometimes",
          },
          "-ddsd-disclaimer" => {
            is_free => "neutral",
          },
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "a-x";
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/$key/api/action/package_show?id=$key";
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "$key-license";
          is $l->{source_type}, 'site_legal';
          is $l->{source_url}, undef;
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
          is $l->{is_free}, 'sometimes';
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'neutral';
        }
      }
    } $current->c;
  });
} n => 20, name => 'info';

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
          author => "\x{4000}",
          "title" => "\x{5000}",
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      "https://hoge/$key/dataset/activity/$key" => {
        mime => 'text/html',
        text => q{
          <html lang="fr">
          <link rel="stylesheet" type="text/css" href="/foo/bar/main-rtl.min.css" />
        },
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
            notice => {
              template => "\x{7000}",
              template_not_modified => "\x{8000}",
              "need_holder" => 1,
              need_title => 1,
              need_url => 1,
              need_modified_flag => 1,
            },
            lang => "en",
            dir => "ltr",
            writing_mode => "vertical-rl",
          },
          "-ddsd-disclaimer" => {
            is_free => "neutral",
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "a-x";
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/$key/api/action/package_show?id=$key";
          is $l->{is_free}, 'free';
          is $l->{lang}, 'en';
          is $l->{dir}, "ltr";
          is $l->{writing_mode}, "vertical-rl";
          is $l->{notice}->{holder}->{lang}, 'fr';
          is $l->{notice}->{holder}->{dir}, "rtl";
          is $l->{notice}->{holder}->{writing_mode}, "horizontal-tb";
          is $l->{notice}->{holder}->{value}, "\x{4000}";
          is $l->{notice}->{title}->{lang}, 'fr';
          is $l->{notice}->{title}->{dir}, "rtl";
          is $l->{notice}->{title}->{writing_mode}, "horizontal-tb";
          is $l->{notice}->{title}->{value}, "\x{5000}";
          is $l->{notice}->{url}, "https://hoge/$key/dataset/$key";
          ok $l->{notice}->{need_modified_flag};
          is $l->{notice}->{template}->{lang}, 'en';
          is $l->{notice}->{template}->{dir}, "ltr";
          is $l->{notice}->{template}->{writing_mode}, "vertical-rl";
          is $l->{notice}->{template}->{value}, "\x{7000}";
          is $l->{notice}->{template_not_modified}->{lang}, 'en';
          is $l->{notice}->{template_not_modified}->{dir}, "ltr";
          is $l->{notice}->{template_not_modified}->{writing_mode}, "vertical-rl";
          is $l->{notice}->{template_not_modified}->{value}, "\x{8000}";
          is $l->{alt}, undef;
        }
        is $item->{is_free}, 'free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 32, name => 'package metadata filled';

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
          author => "\x{4000}",
          "title" => "\x{5000}",
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      "https://hoge/$key/dataset/activity/$key" => {
        mime => 'text/html',
        text => q{
          <html lang="fr">
          <link rel="stylesheet" type="text/css" href="/foo/bar/main-rtl.min.css" />
        },
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
            alt => [
              {
                type => 'fallback_license',
                key => "foo-license-2",
                notice => {
                  template => "\x{7000}",
                  template_not_modified => "\x{8000}",
                  "need_holder" => 1,
                  need_title => 1,
                  need_url => 1,
                  need_modified_flag => 1,
                },
              },
            ],
            lang => "en",
            dir => "ltr",
            writing_mode => "vertical-rl",
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "a-x";
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/$key/api/action/package_show?id=$key";
          is $l->{is_free}, 'free';
          is $l->{lang}, 'en';
          is $l->{dir}, "ltr";
          is $l->{writing_mode}, "vertical-rl";
          is $l->{notice}, undef;
          is 0+@{$l->{alt}}, 1;
          {
            my $l = $l->{alt}->[0];
            is $l->{type}, 'fallback_license';
            is $l->{key}, 'foo-license-2';
            is $l->{is_free}, 'unknown';
            is $l->{notice}->{holder}->{lang}, 'fr';
          is $l->{notice}->{holder}->{dir}, "rtl";
          is $l->{notice}->{holder}->{writing_mode}, "horizontal-tb";
          is $l->{notice}->{holder}->{value}, "\x{4000}";
          is $l->{notice}->{title}->{lang}, 'fr';
          is $l->{notice}->{title}->{dir}, "rtl";
          is $l->{notice}->{title}->{writing_mode}, "horizontal-tb";
          is $l->{notice}->{title}->{value}, "\x{5000}";
          is $l->{notice}->{url}, "https://hoge/$key/dataset/$key";
          ok $l->{notice}->{need_modified_flag};
          is $l->{notice}->{template}->{lang}, 'en';
          is $l->{notice}->{template}->{dir}, "ltr";
          is $l->{notice}->{template}->{writing_mode}, "vertical-rl";
          is $l->{notice}->{template}->{value}, "\x{7000}";
          is $l->{notice}->{template_not_modified}->{lang}, 'en';
          is $l->{notice}->{template_not_modified}->{dir}, "ltr";
          is $l->{notice}->{template_not_modified}->{writing_mode}, "vertical-rl";
            is $l->{notice}->{template_not_modified}->{value}, "\x{8000}";
          }
        }
      }
    } $current->c;
  });
} n => 34, name => 'package metadata filled with alt, unknown alt license';

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
          author => "\x{4000}",
          "title" => "\x{5000}",
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      "https://hoge/$key/dataset/activity/$key" => {
        mime => 'text/html',
        text => q{
          <html lang="fr">
          <link rel="stylesheet" type="text/css" href="/foo/bar/main-rtl.min.css" />
        },
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
            alt => [
              {
                type => 'fallback_license',
                key => "foo-license-2",
              },
            ],
            lang => "en",
            dir => "ltr",
            writing_mode => "vertical-rl",
          },
          "foo-license-2" => {
            notice => {
              template => "\x{7000}",
              template_not_modified => "\x{8000}",
              "need_holder" => 1,
              need_title => 1,
              need_url => 1,
              need_modified_flag => 1,
            },
            is_free => 'sometimes',
            lang => 'en-gb',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "a-x";
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/$key/api/action/package_show?id=$key";
          is $l->{is_free}, 'free';
          is $l->{lang}, 'en';
          is $l->{dir}, "ltr";
          is $l->{writing_mode}, "vertical-rl";
          is $l->{notice}, undef;
          is 0+@{$l->{alt}}, 1;
          {
            my $l = $l->{alt}->[0];
            is $l->{type}, 'fallback_license';
            is $l->{key}, 'foo-license-2';
            is $l->{is_free}, 'sometimes';
            is $l->{notice}->{holder}->{lang}, 'fr';
          is $l->{notice}->{holder}->{dir}, "rtl";
          is $l->{notice}->{holder}->{writing_mode}, "horizontal-tb";
          is $l->{notice}->{holder}->{value}, "\x{4000}";
          is $l->{notice}->{title}->{lang}, 'fr';
          is $l->{notice}->{title}->{dir}, "rtl";
          is $l->{notice}->{title}->{writing_mode}, "horizontal-tb";
          is $l->{notice}->{title}->{value}, "\x{5000}";
          is $l->{notice}->{url}, "https://hoge/$key/dataset/$key";
          ok $l->{notice}->{need_modified_flag};
          is $l->{notice}->{template}->{lang}, 'en-gb';
          is $l->{notice}->{template}->{dir}, "ltr";
          is $l->{notice}->{template}->{writing_mode}, "vertical-rl";
          is $l->{notice}->{template}->{value}, "\x{7000}";
          is $l->{notice}->{template_not_modified}->{lang}, 'en-gb';
          is $l->{notice}->{template_not_modified}->{dir}, "ltr";
          is $l->{notice}->{template_not_modified}->{writing_mode}, "vertical-rl";
            is $l->{notice}->{template_not_modified}->{value}, "\x{8000}";
          }
        }
      }
    } $current->c;
  });
} n => 34, name => 'package metadata filled with alt, known alt license';

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
          organization => {title => "\x{6000}"},
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
            notice => {need_holder => 1},
            lang => "en",
            dir => "ltr",
            writing_mode => "vertical-rl",
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "a-x";
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/$key/api/action/package_show?id=$key";
          is $l->{is_free}, 'free';
          is $l->{lang}, 'en';
          is $l->{dir}, "ltr";
          is $l->{writing_mode}, "vertical-rl";
          is $l->{alt}, undef;
          is $l->{notice}->{holder}->{lang}, '';
          is $l->{notice}->{holder}->{dir}, "auto";
          is $l->{notice}->{holder}->{writing_mode}, "horizontal-tb";
          is $l->{notice}->{holder}->{value}, "\x{6000}";
          is $l->{notice}->{title}, undef;
          is $l->{notice}->{url}, undef;
          is $l->{notice}->{need_modified_flag}, undef;
          is $l->{notice}->{template}, undef;
          is $l->{notice}->{template_not_modified}, undef;
        }
      }
    } $current->c;
  });
} n => 21, name => 'holder from organization';

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
          organization => {title => "\x{6000}"},
          author => "\x{4000}\x{3000}",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
            notice => {need_holder => 1},
            lang => "en",
            dir => "ltr",
            writing_mode => "vertical-rl",
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "a-x";
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/$key/api/action/package_show?id=$key";
          is $l->{is_free}, 'free';
          is $l->{lang}, 'en';
          is $l->{dir}, "ltr";
          is $l->{writing_mode}, "vertical-rl";
          is $l->{alt}, undef;
          is $l->{notice}->{holder}->{lang}, '';
          is $l->{notice}->{holder}->{dir}, "auto";
          is $l->{notice}->{holder}->{writing_mode}, "horizontal-tb";
          is $l->{notice}->{holder}->{value}, "\x{4000}\x{3000} (\x{6000})";
          is $l->{notice}->{title}, undef;
          is $l->{notice}->{url}, undef;
          is $l->{notice}->{need_modified_flag}, undef;
          is $l->{notice}->{template}, undef;
          is $l->{notice}->{template_not_modified}, undef;
        }
      }
    } $current->c;
  });
} n => 21, name => 'holder from organization and author';

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
          organization => {title => "\x{6000}"},
          author => "\x{6000}\x{4000}\x{3000}",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
            notice => {need_holder => 1},
            lang => "en",
            dir => "ltr",
            writing_mode => "vertical-rl",
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "a-x";
          is $l->{source_type}, 'package';
          is $l->{source_url}, "https://hoge/$key/api/action/package_show?id=$key";
          is $l->{is_free}, 'free';
          is $l->{lang}, 'en';
          is $l->{dir}, "ltr";
          is $l->{writing_mode}, "vertical-rl";
          is $l->{alt}, undef;
          is $l->{notice}->{holder}->{lang}, '';
          is $l->{notice}->{holder}->{dir}, "auto";
          is $l->{notice}->{holder}->{writing_mode}, "horizontal-tb";
          is $l->{notice}->{holder}->{value}, "\x{6000}\x{4000}\x{3000}";
          is $l->{notice}->{title}, undef;
          is $l->{notice}->{url}, undef;
          is $l->{notice}->{need_modified_flag}, undef;
          is $l->{notice}->{template}, undef;
          is $l->{notice}->{template_not_modified}, undef;
        }
      }
    } $current->c;
    return $current->run ('legal', additional => ['foo'], stdout => "text");
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      like $r->{stdout}, qr{\x{6000}\x{4000}\x{3000}};
      like $r->{stdout}, qr{\Qhttps://hoge/$key/api/action/package_show?id=$key\E};
    } $current->c;
  });
} n => 24, name => 'holder from (organization and) author';

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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
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
          is $l->{source_type}, 'site_legal';
          is $l->{source_url}, undef;
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
      }
    } $current->c;
    return $current->prepare (undef, {
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
        status => 404,
      },
    });
  })->then (sub {
    $current->set_o (time3 => time);
    return $current->run ('pull', additional => ['--now' => time + 200*24*24]);
  })->then (sub {
    my $r = $_[0];
    $current->set_o (time4 => time);
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
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
          is $l->{source_type}, 'site_legal';
          is $l->{source_url}, undef;
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
      }
    } $current->c;
    return $current->prepare (undef, {
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "$key-license-2",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
    });
  })->then (sub {
    $current->set_o (time5 => time);
    return $current->run ('pull', additional => ['--now' => time + 400*24*24]);
  })->then (sub {
    my $r = $_[0];
    $current->set_o (time6 => time);
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'site_terms';
          is $l->{key}, "$key-license";
          is $l->{source_type}, 'site_legal';
          is $l->{source_url}, undef;
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "$key-license-2";
          is $l->{source_type}, 'site_legal';
          is $l->{source_url}, undef;
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time5') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time6');
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 54, name => 'package legal of unknown';

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
          source => {type => 'files', files => {
            "file:r:license.txt" => {url => "http://hoge/$key/license.txt"},
          }, insecure => 1},
        },
      },
      "http://hoge/$key/license.txt" => {
        text => "abc",
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'site_terms';
          is $l->{key}, "$key-license";
          is $l->{source_type}, 'site_legal';
          is $l->{source_url}, undef;
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
          is $l->{is_free}, 'unknown';
          ok $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-insecure";
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
        ok $item->{insecure};
      }
    } $current->c;
  });
} n => 20, name => 'legal has insecure file';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "http://hoge/$key/dataset/$key"},
    },
    {
      "http://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
            notice => {need_holder => 1},
            lang => "en",
            dir => "ltr",
            writing_mode => "vertical-rl",
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "a-x";
          ok $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-insecure";
        }
        ok $item->{insecure};
      }
    } $current->c;
  });
} n => 9, name => 'insecure package license';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "http://hoge/$key/dataset/$key"},
    },
    {
      "http://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          author => "\x{4000}",
          resources => [],
        }},
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "http://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
            notice => {
              template => "\x{7000}",
              template_not_modified => "\x{8000}",
              "need_holder" => 1,
              need_title => 1,
              need_url => 1,
              need_modified_flag => 1,
            },
            lang => "en",
            dir => "ltr",
            writing_mode => "vertical-rl",
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          ok $l->{insecure};
        }
        ok $item->{insecure};
      }
    } $current->c;
  });
} n => 7, name => 'insecure package metadata filled, 1';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "http://hoge/$key/dataset/$key"},
    },
    {
      "http://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          "title" => "\x{5000}",
          resources => [],
        }},
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "http://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
            notice => {
              template => "\x{7000}",
              template_not_modified => "\x{8000}",
              "need_holder" => 1,
              need_title => 1,
              need_url => 1,
              need_modified_flag => 1,
            },
            lang => "en",
            dir => "ltr",
            writing_mode => "vertical-rl",
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          ok $l->{insecure};
        }
        ok $item->{insecure};
      }
    } $current->c;
  });
} n => 7, name => 'insecure package metadata filled, 2';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "http://hoge/$key/dataset/$key"},
    },
    {
      "http://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          organization => {"title" => "\x{5000}"},
          resources => [],
        }},
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "http://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
            notice => {
              template => "\x{7000}",
              template_not_modified => "\x{8000}",
              "need_holder" => 1,
              need_title => 1,
              need_url => 1,
              need_modified_flag => 1,
            },
            lang => "en",
            dir => "ltr",
            writing_mode => "vertical-rl",
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          ok $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-insecure";
        }
        ok $item->{insecure};
      }
    } $current->c;
  });
} n => 9, name => 'insecure package metadata filled, 3';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
        }},
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "non-free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
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
          is $l->{key}, "a-x";
          is $l->{is_free}, 'non-free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'non-free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 12, name => 'computed is_free, non-free';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "non-free",
          },
          bbb => {
            is_free => "sometimes",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'sometimes';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'non-free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'non-free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 16, name => 'computed is_free, non-free, 2';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
          },
          bbb => {
            is_free => "non-free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'non-free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'non-free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 16, name => 'computed is_free, non-free, 3';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
          },
          bbb => {
            is_free => "sometimes",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'sometimes';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'sometimes';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 16, name => 'computed is_free, sometimes, 1';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "abcde",
          },
          bbb => {
            is_free => "sometimes",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'sometimes';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'abcde';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 16, name => 'computed is_free, unknown, 1';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            alt => [{
              type => 'license',
              key => 'free1',
            }],
          },
          free1 => {
            is_free => 'free',
          },
          bbb => {
            is_free => "free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'unknown';
          is $l->{alt}->[0]->{type}, 'license';
          is $l->{alt}->[0]->{key}, 'free1';
          is $l->{alt}->[0]->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 19, name => 'computed alt is_free 1';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            alt => [{
              type => 'license',
              key => 'free1',
            }],
          },
          free1 => {
            is_free => 'sometimes',
          },
          bbb => {
            is_free => "free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'unknown';
          is $l->{alt}->[0]->{type}, 'license';
          is $l->{alt}->[0]->{key}, 'free1';
          is $l->{alt}->[0]->{is_free}, 'sometimes';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 19, name => 'computed alt is_free 2';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            alt => [{
              type => 'license',
              key => 'free1',
            }, {
              type => 'license',
              key => 'free2',
            }],
          },
          free1 => {
            is_free => 'sometimes',
          },
          free2 => {
            is_free => 'free',
          },
          bbb => {
            is_free => "free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'unknown';
          is $l->{alt}->[0]->{type}, 'license';
          is $l->{alt}->[0]->{key}, 'free1';
          is $l->{alt}->[0]->{is_free}, 'sometimes';
          is $l->{alt}->[1]->{type}, 'license';
          is $l->{alt}->[1]->{key}, 'free2';
          is $l->{alt}->[1]->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 22, name => 'computed alt is_free 3';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            alt => [{
              type => 'license',
              key => 'free1',
            }, {
              type => 'license',
              key => 'free2',
            }],
          },
          free1 => {
            is_free => 'non-free',
          },
          free2 => {
            is_free => 'free',
          },
          bbb => {
            is_free => "free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'unknown';
          is $l->{alt}->[0]->{type}, 'license';
          is $l->{alt}->[0]->{key}, 'free1';
          is $l->{alt}->[0]->{is_free}, 'non-free';
          is $l->{alt}->[1]->{type}, 'license';
          is $l->{alt}->[1]->{key}, 'free2';
          is $l->{alt}->[1]->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 22, name => 'computed alt is_free 4';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            alt => [{
              type => 'fallback_license',
              key => 'free1',
            }, {
              type => 'fallback_license',
              key => 'free2',
            }],
          },
          free1 => {
            is_free => 'non-free',
          },
          free2 => {
            is_free => 'free',
          },
          bbb => {
            is_free => "free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'unknown';
          is $l->{alt}->[0]->{type}, 'fallback_license';
          is $l->{alt}->[0]->{key}, 'free1';
          is $l->{alt}->[0]->{is_free}, 'non-free';
          is $l->{alt}->[1]->{type}, 'fallback_license';
          is $l->{alt}->[1]->{key}, 'free2';
          is $l->{alt}->[1]->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 22, name => 'computed alt fallback is_free 1';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "free2"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            alt => [{
              type => 'fallback_license',
              key => 'free1',
            }, {
              type => 'fallback_license',
              key => 'free2',
            }],
          },
          free1 => {
            is_free => 'non-free',
          },
          free2 => {
            is_free => 'free',
          },
          bbb => {
            is_free => "free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "free2";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'unknown';
          is $l->{alt}->[0]->{type}, 'fallback_license';
          is $l->{alt}->[0]->{key}, 'free1';
          is $l->{alt}->[0]->{is_free}, 'non-free';
          is $l->{alt}->[1]->{type}, 'fallback_license';
          is $l->{alt}->[1]->{key}, 'free2';
          is $l->{alt}->[1]->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 22, name => 'computed alt fallback is_free 2';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            alt => [{
              type => 'fallback_license',
              key => 'free1',
            }, {
              type => 'fallback_license',
              key => 'free2',
            }],
          },
          free1 => {
            is_free => 'non-free',
          },
          free2 => {
            is_free => 'free',
          },
          bbb => {
            is_free => "free",
            possible => ['free2'],
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'unknown';
          is $l->{alt}->[0]->{type}, 'fallback_license';
          is $l->{alt}->[0]->{key}, 'free1';
          is $l->{alt}->[0]->{is_free}, 'non-free';
          is $l->{alt}->[1]->{type}, 'fallback_license';
          is $l->{alt}->[1]->{key}, 'free2';
          is $l->{alt}->[1]->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 22, name => '29 computed alt fallback is_free 3';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            alt => [{
              type => 'fallback_license',
              key => 'free1',
            }, {
              type => 'fallback_license',
              key => 'free2',
            }],
          },
          free1 => {
            is_free => 'non-free',
          },
          free2 => {
            is_free => 'sometimes',
          },
          bbb => {
            is_free => "free",
            possible => ['free2'],
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'unknown';
          is $l->{alt}->[0]->{type}, 'fallback_license';
          is $l->{alt}->[0]->{key}, 'free1';
          is $l->{alt}->[0]->{is_free}, 'non-free';
          is $l->{alt}->[1]->{type}, 'fallback_license';
          is $l->{alt}->[1]->{key}, 'free2';
          is $l->{alt}->[1]->{is_free}, 'sometimes';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 22, name => 'computed alt fallback is_free 4';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            alt => [{
              type => 'fallback_license',
              key => 'free1',
            }, {
              type => 'fallback_license',
              key => 'free2',
            }],
          },
          free1 => {
            is_free => 'non-free',
          },
          free2 => {
            is_free => 'sometimes',
          },
          bbb => {
            is_free => "sometimes",
            possible => ['free2'],
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'sometimes';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'unknown';
          is $l->{alt}->[0]->{type}, 'fallback_license';
          is $l->{alt}->[0]->{key}, 'free1';
          is $l->{alt}->[0]->{is_free}, 'non-free';
          is $l->{alt}->[1]->{type}, 'fallback_license';
          is $l->{alt}->[1]->{key}, 'free2';
          is $l->{alt}->[1]->{is_free}, 'sometimes';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 22, name => 'computed alt fallback is_free 5';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
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
      "https://hoge/$key/dataset/activity/" . $key => {
        text => qq{<a href="/$key/license">データ利用規約</a>},
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
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
          is $l->{key}, "-ddsd-unknown";
          is $l->{source_type}, 'site';
          is $l->{source_url}, "https://hoge/$key/license";
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 17, name => 'package legal unknown';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
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
      "https://hoge/$key/dataset/activity/" . $key => {
        text => qq{<a href="/$key/license">データ利用規約</a>},
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          terms_url => "https://hoge/$key/license",
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
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
          is $l->{source_type}, 'site';
          is $l->{source_url}, "https://hoge/$key/license";
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 17, name => '33 package legal known, activity.html';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://data.bodik.jp/$key/dataset/$key"},
    },
    {
      "https://data.bodik.jp/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [],
        }},
      },
      "https://data.bodik.jp/$key/dataset/" . $key => {
        text => qq{<a href="/$key/license">データ利用規約</a>},
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          terms_url => "https://data.bodik.jp/$key/license",
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
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
          is $l->{source_type}, 'site';
          is $l->{source_url}, "https://data.bodik.jp/$key/license";
          is 0+@{$l->{timestamps}}, 1;
          ok $current->o ('time1') < $l->{timestamps}->[0];
          ok $l->{timestamps}->[0] < $current->o ('time2');
          is $l->{is_free}, 'unknown';
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, '-ddsd-disclaimer';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 17, name => 'package legal known, index.html';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            conditional => [{
              type => 'license',
              key => 'free1',
            }, {
              type => 'license',
              key => 'free2',
            }],
          },
          free1 => {
            is_free => 'free',
          },
          free2 => {
            is_free => 'free',
          },
          bbb => {
            is_free => "free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'unknown';
          is 0+@{$l->{conditional}}, 2;
          is $l->{alt}, undef;
          is $l->{conditional}->[0]->{type}, 'license';
          is $l->{conditional}->[0]->{key}, 'free1';
          is $l->{conditional}->[0]->{is_free}, 'free';
          is $l->{conditional}->[1]->{type}, 'license';
          is $l->{conditional}->[1]->{key}, 'free2';
          is $l->{conditional}->[1]->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 24, name => 'computed conditional 1';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            conditional => [{
              type => 'license',
              key => 'free1',
            }, {
              type => 'license',
              key => 'free2',
            }],
          },
          free1 => {
            is_free => 'free',
          },
          bbb => {
            is_free => "free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'unknown';
          is 0+@{$l->{conditional}}, 2;
          is $l->{alt}, undef;
          is $l->{conditional}->[0]->{type}, 'license';
          is $l->{conditional}->[0]->{key}, 'free1';
          is $l->{conditional}->[0]->{is_free}, 'free';
          is $l->{conditional}->[1]->{type}, 'license';
          is $l->{conditional}->[1]->{key}, 'free2';
          is $l->{conditional}->[1]->{is_free}, 'unknown';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 24, name => 'computed conditional 2';

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
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "a-x",
        }],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            conditional => [{
              type => 'license',
              key => 'free1',
            }, {
              type => 'license',
              key => 'free2',
            }],
          },
          free1 => {
            is_free => 'sometimes',
          },
          free2 => {
            is_free => 'free',
          },
          bbb => {
            is_free => "free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "a-x";
          is $l->{is_free}, 'unknown';
          is 0+@{$l->{conditional}}, 2;
          is $l->{alt}, undef;
          is $l->{conditional}->[0]->{type}, 'license';
          is $l->{conditional}->[0]->{key}, 'free1';
          is $l->{conditional}->[0]->{is_free}, 'sometimes';
          is $l->{conditional}->[1]->{type}, 'license';
          is $l->{conditional}->[1]->{key}, 'free2';
          is $l->{conditional}->[1]->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 24, name => 'computed conditional 3';

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
          author => "\x{4000}",
          "title" => "\x{5000}",
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
        }},
      },
      "https://hoge/$key/dataset/activity/$key" => {
        mime => 'text/html',
        text => q{
          <html lang="fr">
          <link rel="stylesheet" type="text/css" href="/foo/bar/main-rtl.min.css" />
        },
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "a-x" => {
            is_free => "free",
            notice => {
              template => "\x{7000}{title}, {holder}, {url}, {modified_by}.{foo}",
              template_not_modified => "\x{8000}",
              "need_holder" => 1,
              need_title => 1,
              need_url => 1,
              need_modified_flag => 1,
            },
            lang => "en",
            dir => "ltr",
            writing_mode => "vertical-rl",
          },
          "-ddsd-disclaimer" => {
            is_free => "neutral",
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
    return $current->run ('legal', additional => ['foo'], stdout => 'text');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        like $r->{stdout}, qr{\x{7000}\x{5000}, \x{4000}, \Qhttps://hoge/$key/dataset/$key\E, \{modified_by\}\.\{foo\}};
      }
    } $current->c;
  });
} n => 3, name => 'template';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
    },
    {
      "https://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
          notes => q{これは測量成果です。},
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          bbb => {
            is_free => "free",
          },
          "-ddsd-jp-sokuryouhou" => {
            is_free => 'non-free',
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'license';
          is $l->{key}, "-ddsd-jp-sokuryouhou";
          is $l->{is_free}, 'non-free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'non-free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 16, name => 'non-free because of jp law, 1';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
    },
    {
      "https://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
          title => q{[測量成果] 地図},
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          bbb => {
            is_free => "free",
          },
          "-ddsd-jp-sokuryouhou" => {
            is_free => 'non-free',
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'license';
          is $l->{key}, "-ddsd-jp-sokuryouhou";
          is $l->{is_free}, 'non-free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'non-free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 16, name => 'non-free because of jp law, 2';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
    },
    {
      "https://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
          notes => q{測量法に基づく申請が必要},
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          bbb => {
            is_free => "free",
          },
          "-ddsd-jp-sokuryouhou" => {
            is_free => 'non-free',
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'license';
          is $l->{key}, "-ddsd-jp-sokuryouhou";
          is $l->{is_free}, 'non-free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'non-free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 16, name => 'non-free because of jp law, 3';


Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
    },
    {
      "https://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
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
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          bbb => {
            is_free => "free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
          },
          ABC => {
            conditional => [
              {type => "fallback_license", key => "ABC1"},
              {type => "fallback_license", key => "ABC2"},
            ],
          },
          ABC1 => {
            alt => [{type => "license", key => "X"}],
          },
          ABC2 => {
            alt => [{type => "license", key => "X"}],
          },
          X => {
            is_free => 'sometimes',
          },
        },
      },
      "https://hoge/$key/license" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "ABC";
          is $l->{is_free}, 'unknown';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'free';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 16, name => 'free and conditional alt site, 1';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
    },
    {
      "https://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
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
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          bbb => {
            is_free => "unknown",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
          },
          ABC => {
            conditional => [
              {type => "fallback_license", key => "ABC1"},
              {type => "fallback_license", key => "ABC2"},
            ],
          },
          ABC1 => {
            alt => [{type => "license", key => "X"}],
          },
          ABC2 => {
            alt => [{type => "license", key => "X"}],
          },
          X => {
            is_free => 'sometimes',
          },
        },
      },
      "https://hoge/$key/license" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'unknown';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "ABC";
          is $l->{is_free}, 'unknown';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 16, name => 'free and conditional alt site, 2';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    {
      foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
    },
    {
      "https://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          organization => {"title" => "\x{5000}"},
          resources => [],
          license_id => "foo",
          license_url => "bar",
          license_title => "abc",
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
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {id => "foo", url => "bar", title => "abc", is => "bbb"},
        ],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          bbb => {
            is_free => "sometimes",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
          },
          ABC => {
            conditional => [
              {type => "fallback_license", key => "ABC1"},
              {type => "fallback_license", key => "ABC2"},
            ],
          },
          ABC1 => {
            alt => [{type => "license", key => "X"}],
          },
          ABC2 => {
            alt => [{type => "license", key => "X"}],
          },
          X => {
            is_free => 'sometimes',
          },
        },
      },
      "https://hoge/$key/license" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is 0+@{$item->{legal}}, 3;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'license';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'sometimes';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "ABC";
          is $l->{is_free}, 'unknown';
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[2];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'sometimes';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 16, name => 'free and conditional alt site, 3';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    {
      foo => {type => 'packref', url => "https://hoge/$key/packref.json"},
    },
    {
      "https://hoge/$key/packref.json" => {
        json => {
          type => 'packref',
          terms_url => "https://hoge/$key/license.html",
          source => {type => 'files'},
        },
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
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
          },
          ABC => {
            alt => [{type => "license", key => "X"}],
          },
          X => {
            is_free => 'free',
          },
        },
      },
      "https://hoge/$key/license" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
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
          is $l->{key}, "ABC";
          is $l->{is_free}, 'unknown';
          is $l->{source_type}, 'packref';
          is $l->{source_url}, "https://hoge/$key/license.html";
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'free';
      }
    } $current->c;
  });
} n => 12, name => 'alt license from packref';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    {
      foo => {type => 'packref', url => "https://hoge/$key/packref.json"},
    },
    {
      "https://hoge/$key/packref.json" => {
        json => {
          type => 'packref',
          terms_url => "https://hoge/$key/license.html",
          source => {type => 'files'},
        },
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
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
          },
          ABC => {
            alt => [{type => "fallback_license", key => "X"}],
          },
          X => {
            is_free => 'free',
          },
        },
      },
      "https://hoge/$key/license" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
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
    return $current->run ('legal', additional => ['foo', '--json'], jsonl => 1);
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
          is $l->{key}, "ABC";
          is $l->{is_free}, 'unknown';
          is $l->{source_type}, 'packref';
          is $l->{source_url}, "https://hoge/$key/license.html";
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'free';
      }
    } $current->c;
  });
} n => 12, name => 'alt fallback license from packref';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
