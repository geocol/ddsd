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
    $key => {
      type => 'zip',
      file_key => "file",
      source => {
        type => 'single',
        url => "https://hoge/$key.zip",
      },
    },
  },
  {
    "https://hoge/$key.zip" => {zip => {
      "abc.txt" => {text => "abc", timestamp => 1766890774},
      "xyz.txt" => {text => "xyz"},
    }},
    $current->legal_url_prefix . 'websites.json' => {
      json => [
        {
          url_prefix => "https://hoge/$key.zip",
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
    return $current->run ('legal', additional => [$key, '--json'], jsonl => 1);
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
          ok 0+@{$l->{timestamps}};
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
} n => 14, name => 'has external data';

Run;

=head1 LICENSE

Copyright 2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
