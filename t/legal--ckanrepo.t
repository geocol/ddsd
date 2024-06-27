use strict;
use warnings;
use Path::Tiny;
BEGIN { $ENV{TEST_MAX_CONCUR} = 1 }
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare ({
    foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
  }, {
    "https://hoge/$key/dataset/$key" => {
      text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/">},
    },
    "https://hoge/$key/api/action/package_show?id=$key" => {
      json => {success => \1, result => {
      }},
    },
    "https://hoge/$key/" => {
      text => qq{<a href="//foo/$key/license">利用規約</a>},
    },
    $current->legal_url_prefix . 'websites.json' => {
      json => [
        {
          terms_url => "https://foo/$key/license",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "$key-license",
        },
      ],
    },
    "https://hoge/$key/license.json" => {
      json => {
        type => 'packref',
        source => {type => 'files'},
      },
    },
  })->then (sub {
    return $current->run ('pull');
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
          is $l->{type}, 'site_terms';
          is $l->{key}, "$key-license";
          is $l->{source_type}, 'site';
          is $l->{source_url}, "https://foo/$key/license";
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
} n => 13, name => 'has root data';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare ({
    foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
  }, {
    "https://hoge/$key/dataset/$key" => {
      text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/">},
    },
    "https://hoge/$key/api/action/package_show?id=$key" => {
      json => {success => \1, result => {
      }},
    },
    "https://hoge/$key/" => {
      text => qq{<a href="//foo/$key/license">利用規約</a>},
    },
    $current->legal_url_prefix . 'websites.json' => {
      json => [
        {
          terms_url => "https://foo/$key/license",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "$key-license",
        },
      ],
    },
  })->then (sub {
    return $current->run ('pull');
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
          is $l->{type}, 'site_terms';
          is $l->{key}, "-ddsd-unknown";
          is $l->{source_type}, 'site';
          is $l->{source_url}, "https://foo/$key/license";
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
} n => 13, name => 'has root data but broken';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare ({
    foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
  }, {
    "https://hoge/$key/dataset/$key" => {
      text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/">},
    },
    "https://hoge/$key/api/action/package_show?id=$key" => {
      json => {success => \1, result => {
      }},
    },
    "https://hoge/$key/" => {
      text => qq{<a href="//foo/$key/license#abc">利用規約</a>},
    },
    $current->legal_url_prefix . 'websites.json' => {
      json => [
        {
          terms_url => "https://foo/$key/license#abc",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "$key-license",
        },
      ],
    },
    "https://hoge/$key/license.json" => {
      json => {
        type => 'packref',
        source => {type => 'files'},
      },
    },
  })->then (sub {
    return $current->run ('pull');
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
          is $l->{type}, 'site_terms';
          is $l->{key}, "$key-license";
          is $l->{source_type}, 'site';
          is $l->{source_url}, "https://foo/$key/license#abc";
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
} n => 13, name => 'flagmented url';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare ({
    foo => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
  }, {
    "https://hoge/$key/dataset/$key" => {
      text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/">},
    },
    "https://hoge/$key/api/action/package_show?id=$key" => {
      json => {success => \1, result => {
      }},
    },
    "https://hoge/$key/" => {
      text => qq{<a href="//foo/$key/license">利用規約</a>},
      etag => '"foo"',
    },
    $current->legal_url_prefix . 'websites.json' => {
      json => [
        {
          terms_url => "https://foo/$key/license",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "$key-license",
        },
      ],
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->prepare (undef, {
      "https://hoge/$key/" => {
        text => qq{<a href="//foo/$key/license">利用規約</a>},
        if_etag => '"foo"',
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
    });
  })->then (sub {
    $current->set_o (time1 => time);
    return $current->run ('pull', additional => ['--now', time+200*60*60]);
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
          is $l->{type}, 'site_terms';
          is $l->{key}, "$key-license";
          is $l->{source_type}, 'site';
          is $l->{source_url}, "https://foo/$key/license";
          is $l->{is_free}, 'unknown';
          is 0+@{$l->{timestamps}}, 1;
          ok $l->{timestamps}->[0] > $current->o ('time1');
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
} n => 15, name => 'site root index 304';

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
          notes => q{また、本サイト利用規約のほか、},
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
          is $l->{key}, "-ddsd-ckan-package";
          is $l->{is_free}, 'unknown';
          is $l->{notes}, q{また、本サイト利用規約のほか、};
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
} n => 17, name => 'non-free in CKAN notes';

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
          notes => qq{abc\x0D\x0Aファイルライセンス：CC BY-NC-ND 4.0\x0D\x0Adef},
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
          'CC-BY-NC-ND-4.0' => {
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
          is $l->{key}, "CC-BY-NC-ND-4.0";
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
} n => 16, name => 'non-free in CKAN notes 2';

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
          notes => qq{abc\x0D\x0Aファイルライセンス：CC BY-NC-ND 4.0?\x0D\x0Adef},
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
          'CC-BY-NC-ND-4.0' => {
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
          is $l->{key}, "-ddsd-ckan-package";
          is $l->{is_free}, 'unknown';
          is $l->{notes}, qq{abc\x0D\x0Aファイルライセンス：CC BY-NC-ND 4.0?\x0D\x0Adef};
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
} n => 17, name => 'non-free in CKAN notes 3';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
