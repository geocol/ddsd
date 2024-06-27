use strict;
use warnings;
use Path::Tiny;
BEGIN { $ENV{TEST_MAX_CONCUR} = 1 }
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare ({
    foo => {type => 'ckansite', url => "https://hoge/$key/"},
  }, {
    "https://hoge/$key/" => {
      text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/" xxx="">},
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
} n => 12, name => 'no legal';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare ({
    foo => {type => 'ckansite', url => "https://hoge/$key/"},
  }, {
    "https://hoge/$key/" => {
      text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/"><a href="//foo/$key/license">利用規約</a>},
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
          is $l->{key}, '-ddsd-unknown';
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
} n => 13, name => 'no info';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare ({
    foo => {type => 'ckansite', url => "https://hoge/$key/"},
  }, {
    "https://hoge/$key/" => {
      text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/"><a href="//foo/$key/license">利用規約</a>},
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
} n => 13, name => 'has data';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare ({
    foo => {type => 'ckansite', url => "https://hoge/$key/"},
  }, {
    "https://hoge/$key/" => {
      text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/"><a href="//foo/$key/license">利用規約</a>},
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
} n => 13, name => 'has data but legal remote broken';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare ({
    foo => {type => 'ckansite', url => "https://hoge/$key/"},
  }, {
    "https://hoge/$key/" => {
      text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/"><a href="javascript://foo/$key/license">利用規約</a>},
    },
    $current->legal_url_prefix . 'websites.json' => {
      json => [
        {
          terms_url => "javascript://foo/$key/license",
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
          is $l->{type}, 'license';
          is $l->{key}, "-ddsd-unknown";
          is $l->{source_type}, 'sniffer';
          is $l->{source_url}, undef;
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
} n => 13, name => 'legal URL bad';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare ({
    foo => {type => 'ckansite', url => "https://hoge/$key/"},
  }, {
    "https://hoge/$key/" => {
      redirect => q<foo>,
    },
    "https://hoge/$key/foo" => {
      text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/"><a href="//foo/$key/license">利用規約</a>},
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
} n => 13, name => 'index redirected';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare ({
    foo => {type => 'ckansite', url => "https://hoge/$key/"},
  }, {
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
          is $l->{type}, 'license';
          is $l->{key}, "-ddsd-unknown";
          is $l->{source_type}, 'sniffer';
          is $l->{source_url}, undef;
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
} n => 13, name => 'index not found';


Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare ({
    foo => {type => 'ckansite', url => "https://hoge/$key/"},
  }, {
    "https://hoge/$key/" => {
      text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/">},
    },
    $current->legal_url_prefix . 'websites.json' => {
      json => [
        {
          url_prefix => "https://hoge/$key/",
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
          is $l->{source_type}, 'site_legal';
          is $l->{source_url}, undef;
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
} n => 13, name => 'has external data';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare ({
    foo => {type => 'ckansite', url => "https://hoge/$key/"},
  }, {
    "https://hoge/$key/" => {
      text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/"><a href="//foo/$key/license">当市オープンデータ 利用規約</a>},
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
} n => 13, name => 'has terms link, 1';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
