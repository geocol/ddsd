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
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key") . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, "$key-license";
           is $v->{legal_source_key}, "file:index.html";
           is $v->{legal_source_url}, "https://foo/$key/license";
           is $v->{legal_packref_url}, undef;
           is $v->{additionals}, undef;
         }
       }},
    ]);
  });
} n => 21, name => 'has root data';

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
          notes => q{コンテンツ利用に当たっては、[また別の利用規約](https://host/path/terms)に同意したものとみなします。},
        }},
      },
      $current->legal_url_prefix . 'ckan.json' => {
        json => [
          {extracted_url => "https://host/path/terms", is => "bbb"},
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
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'site_terms';
          is $l->{key}, "-ddsd-unknown";
          is $l->{is_free}, 'unknown';
          is $l->{extracted_url}, "https://host/path/terms";
          is $l->{notes}, q{コンテンツ利用に当たっては、[また別の利用規約](https://host/path/terms)に同意したものとみなします。};
          ok ! $l->{insecure};
          ok $l->{timestamps}->[0];
          is $l->{source_type}, 'site';
          is $l->{source_url}, "https://host/path/terms";
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key") . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, "-ddsd-unknown";
           is $v->{legal_source_key}, undef;
           is $v->{legal_source_url}, "https://host/path/terms";
           is $v->{legal_packref_url}, undef;
           is $v->{additionals}, undef;
         }
       }},
    ]);
  });
} n => 25, name => 'linked in notes extracted, def found but failed';

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
          notes => qq{コンテンツ利用に当たっては、[また別の利用規約](https://foo/$key/license)に同意したものとみなします。},
        }},
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "$key-license" => {
            is_free => "free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
          },
        },
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
          is $l->{key}, "$key-license";
          is $l->{is_free}, 'free';
          is $l->{extracted_url}, "https://foo/$key/license";
          is $l->{notes}, qq{コンテンツ利用に当たっては、[また別の利用規約](https://foo/$key/license)に同意したものとみなします。};
          ok ! $l->{insecure};
          ok $l->{timestamps}->[0];
          is $l->{source_type}, 'site';
          is $l->{source_url}, "https://foo/$key/license";
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'free';
        ok ! $item->{insecure};
      }
    } $current->c;
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key") . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, "$key-license";
           is $v->{legal_source_key}, undef;
           is $v->{legal_source_url}, "https://foo/$key/license";
           is $v->{legal_packref_url}, undef;
           is $v->{additionals}, undef;
         }
       }},
    ]);
  });
} n => 25, name => 'linked in notes extracted, def found and licensed';

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
          notes => q{地番マスターコンテンツ利用に当たっては、[また別の利用規約](https://www.digital.go.jp/path/terms)に同意したものとみなします。},
        }},
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          bbb => {
            is_free => "free",
          },
          bbb2 => {
            is_free => "non-free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
          },
        },
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [
          {
            terms_url => "https://www.digital.go.jp/path/terms",
            source => {type => 'packref', url => "https://hoge/$key/license.json"},
            legal_key => "bbb",
          },
          {
            terms_url => "https://www.geospatial.jp/ckan/dataset/houmusyouchizu-riyoukiyaku/resource/47871bf1-4c85-48f7-a8fe-b27c6643c1c5",
            source => {type => 'packref', url => "https://hoge/$key/license2.json"},
            legal_key => "bbb2",
          },
        ],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      "https://hoge/$key/license2.json" => {
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
          is $l->{type}, 'site_terms';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          is $l->{extracted_url}, "https://www.digital.go.jp/path/terms";
          is $l->{notes}, q{地番マスターコンテンツ利用に当たっては、[また別の利用規約](https://www.digital.go.jp/path/terms)に同意したものとみなします。};
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "bbb2";
          is $l->{is_free}, 'non-free';
          is $l->{extracted_url}, "https://www.geospatial.jp/ckan/dataset/houmusyouchizu-riyoukiyaku/resource/47871bf1-4c85-48f7-a8fe-b27c6643c1c5";
          is $l->{notes}, q{地番マスターコンテンツ利用に当たっては、[また別の利用規約](https://www.digital.go.jp/path/terms)に同意したものとみなします。};
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
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key") . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, "bbb";
           is $v->{legal_source_key}, undef;
           is $v->{legal_source_url}, "https://www.digital.go.jp/path/terms";
           is $v->{legal_packref_url}, undef;
           is 0+@{$v->{additionals}}, 1;
           {
             my $v = $v->{additionals}->[0];
             ok $v->{timestamp};
             is $v->{legal_key}, "bbb2";
             is $v->{legal_source_key}, undef;
             is $v->{legal_source_url}, "https://www.geospatial.jp/ckan/dataset/houmusyouchizu-riyoukiyaku/resource/47871bf1-4c85-48f7-a8fe-b27c6643c1c5";
             is $v->{legal_packref_url}, undef;
             is $v->{additionals}, undef;
           }
         }
       }},
    ]);
  });
} n => 34, name => 'linked in notes extracted, chiban';

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
          notes => q{地番マスターコンテンツ利用に当たっては、[また別の利用規約](https://www.digital.go.jp/path/terms)に同意したものとみなします。},
        }},
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          bbb => {
            is_free => "free",
          },
          bbb2 => {
            is_free => "non-free",
          },
          "-ddsd-disclaimer" => {
            is_free => 'neutral',
          },
        },
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [
          {
            terms_url => "https://www.digital.go.jp/path/terms",
            source => {type => 'packref', url => "https://hoge/$key/license.json"},
            legal_key => "bbb",
          },
        ],
      },
      "https://hoge/$key/license.json" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
        },
      },
      "https://hoge/$key/license2.json" => {
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
          is $l->{type}, 'site_terms';
          is $l->{key}, "bbb";
          is $l->{is_free}, 'free';
          is $l->{extracted_url}, "https://www.digital.go.jp/path/terms";
          is $l->{notes}, q{地番マスターコンテンツ利用に当たっては、[また別の利用規約](https://www.digital.go.jp/path/terms)に同意したものとみなします。};
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'site_terms';
          is $l->{key}, "-ddsd-unknown";
          is $l->{is_free}, 'unknown';
          is $l->{extracted_url}, "https://www.geospatial.jp/ckan/dataset/houmusyouchizu-riyoukiyaku/resource/47871bf1-4c85-48f7-a8fe-b27c6643c1c5";
          is $l->{notes}, q{地番マスターコンテンツ利用に当たっては、[また別の利用規約](https://www.digital.go.jp/path/terms)に同意したものとみなします。};
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
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key") . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, "bbb";
           is $v->{legal_source_key}, undef;
           is $v->{legal_source_url}, "https://www.digital.go.jp/path/terms";
           is $v->{legal_packref_url}, undef;
           is 0+@{$v->{additionals}}, 1;
           {
             my $v = $v->{additionals}->[0];
             ok $v->{timestamp};
             is $v->{legal_key}, "-ddsd-unknown";
             is $v->{legal_source_key}, undef;
             is $v->{legal_source_url}, "https://www.geospatial.jp/ckan/dataset/houmusyouchizu-riyoukiyaku/resource/47871bf1-4c85-48f7-a8fe-b27c6643c1c5";
             is $v->{legal_packref_url}, undef;
             is $v->{additionals}, undef;
           }
         }
       }},
    ]);
  });
} n => 34, name => 'linked in notes extracted, chiban, no data';

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
          notes => q{コンテンツ利用に当たっては、[また別の利用規約](https://host/path/terms)に同意したものとみなします。},
        }},
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
        is 0+@{$item->{legal}}, 2;
        {
          my $l = $item->{legal}->[0];
          is $l->{type}, 'site_terms';
          is $l->{key}, "-ddsd-unknown";
          is $l->{is_free}, 'unknown';
          is $l->{extracted_url}, "https://host/path/terms";
          is $l->{notes}, q{コンテンツ利用に当たっては、[また別の利用規約](https://host/path/terms)に同意したものとみなします。};
          ok ! $l->{insecure};
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'unknown';
        ok ! $item->{insecure};
      }
    } $current->c;
  });
} n => 14, name => 'linked in notes extracted, def not found';

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
          organization => {"title" => "--"},
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
            notice => {
              need_holder => 1,
            },
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
        {
          my $l = $item->{legal}->[0];
          is $l->{notice}->{holder}->{value}, undef;
        }
      }
    } $current->c;
  });
} n => 3, name => 'organization -- 1';

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
          author => "hoge",
          organization => {"title" => "--"},
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
            notice => {
              need_holder => 1,
            },
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
        {
          my $l = $item->{legal}->[0];
          is $l->{notice}->{holder}->{value}, 'hoge';
        }
      }
    } $current->c;
  });
} n => 3, name => 'organization -- 2';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
