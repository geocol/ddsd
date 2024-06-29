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
          is $l->{is_free}, 'free';
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
} n => 12, name => 'ok packref';

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
            is_free => 'free',
          },
        },
      },
      "https://hoge/$key/license" => {
        json => {
          type => 'packref',
          source => {
            type => 'files',
            files => {
              "file:r:404" => {url => "404"},
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
          is $l->{key}, "-ddsd-unknown";
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
        is $item->{is_free}, 'unknown';
      }
    } $current->c;
    return $current->prepare ({
      bar => {type => 'packref', url => "https://hoge/$key/packref2.json"},
    }, {
      "https://hoge/$key/packref2.json" => {
        json => {
          type => 'packref',
          terms_url => "https://hoge/$key/license.html",
          source => {type => 'files'},
        },
      },
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->run ('legal', additional => ['bar', '--json'], jsonl => 1);
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
          is $l->{source_type}, 'packref';
          is $l->{source_url}, "https://hoge/$key/license.html";
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'unknown';
      }
    } $current->c;
  });
} n => 24, name => 'packref file not found';

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
            is_free => 'free',
          },
        },
      },
      "https://hoge/$key/license" => {
        json => {
          type => 'packref',
          source => {
            type => 'files',
            files => {
              "file:r:a" => {url => "a", sha256 => "bad"},
            },
          },
        },
      },
      "https://hoge/$key/a" => {
        text => "A",
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
          is $l->{type}, 'site_terms';
          is $l->{key}, "-ddsd-unknown";
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
        is $item->{is_free}, 'unknown';
      }
    } $current->c;
    return $current->prepare ({
      bar => {type => 'packref', url => "https://hoge/$key/packref2.json"},
    }, {
      "https://hoge/$key/packref2.json" => {
        json => {
          type => 'packref',
          terms_url => "https://hoge/$key/license.html",
          source => {type => 'files'},
        },
      },
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->run ('legal', additional => ['bar', '--json'], jsonl => 1);
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
          is $l->{source_type}, 'packref';
          is $l->{source_url}, "https://hoge/$key/license.html";
        }
        {
          my $l = $item->{legal}->[1];
          is $l->{type}, 'disclaimer';
          is $l->{key}, "-ddsd-disclaimer";
          is $l->{is_free}, 'neutral';
        }
        is $item->{is_free}, 'unknown';
      }
    } $current->c;
  });
} n => 24, name => 'packref sha256 mismatch';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
