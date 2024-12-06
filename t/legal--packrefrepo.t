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
  return $current->prepare (
    {
      foo => {type => 'packref', url => "https://hoge/$key/packref.json"},
    },
    {
      "https://hoge/$key/packref.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'files',
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
          is $l->{key}, '-ddsd-unknown';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
      }
    } $current->c;
  });
} n => 7, name => 'no legal info';

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
          source => {
            type => 'files',
          },
          terms_url => "//hoge/$key/license",
        },
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
          is $l->{is_free}, 'unknown';
          ok $l->{timestamps}->[0];
          is $l->{source_url}, "https://hoge/$key/license";
          is $l->{source_type}, 'packref';
        }
      }
    } $current->c;
    return $current->get_access_count ("https://hoge/$key/license.json");
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 1;
    } $current->c;
  });
} n => 10, name => 'terms_url specified';

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
          source => {
            type => 'files',
            files => {
              "file:r:1" => {url => "https://hoge/$key/1"},
            },
          },
          terms_url => "https://hoge:a/$key/license",
        },
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          terms_url => "https://hoge:a/$key/license",
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
      "https://hoge/$key/1" => {
        text => q{a},
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
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
          is $l->{type}, 'license';
          is $l->{key}, '-ddsd-unknown';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
      }
    } $current->c;
    return $current->get_access_count ("https://hoge/$key/1");
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 0;
       }},
      {path => "local/data/foo/files/1", is_none => 1},
    ]);
  });
} n => 12, name => 'broken terms_url';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'packref', url => "https://hoge/$key/packref.json"},
    },
    {
      "https://hoge/$key/packref.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'files',
            files => {
              "file:r:1" => {url => "https://hoge/$key/1"},
            },
          },
          terms_url => "https://hoge/$key/license",
          packref_license => "unknown",
        },
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
      "https://hoge/$key/1" => {
        text => q{a},
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
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
          is $l->{type}, 'license';
          is $l->{key}, '-ddsd-unknown';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
      }
    } $current->c;
    return $current->get_access_count ("https://hoge/$key/1");
  })->then (sub {
    my $count = $_[0];
    test {
      is $count, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 0;
       }},
      {path => "local/data/foo/files/1", is_none => 1},
    ]);
  });
} n => 12, name => 'bad packref_license';

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
          source => {
            type => 'files',
          },
          packref_license => "CC0-1.0",
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
          is $l->{key}, '-ddsd-unknown';
          is $l->{source_type}, 'sniffer';
          is $l->{is_free}, 'unknown';
        }
      }
    } $current->c;
  });
} n => 7, name => 'packref_license';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {type => 'packref', url => "https://hoge/$key/dataset/$key"},
    },
    {
      "https://hoge/$key/dataset/$key" => {
        json => {
          type => 'packref',
          source => {type => 'files'},
          terms_url => "https://hoge/$key/terms",
        },
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          terms_url => "https://hoge/$key/terms",
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
        like $r->{stdout}, qr{\x{7000}\{title\}, \{holder\}, \Qhttps://hoge/$key/dataset/$key\E, \{modified_by\}\.\{foo\}};
        unlike $r->{stdout}, qr{Web::URL};
      }
    } $current->c;
  });
} n => 4, name => 'template url';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
