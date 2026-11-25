use strict;
use warnings;
use Path::Tiny;
BEGIN { $ENV{TEST_MAX_CONCUR} = 1 }
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $uk = rand;
  my $fkey = 'lfi_' . rand;
  return $current->prepare ({
    $fkey => {
      type => 'filtered',
      filter => 'strip_tags',
      upstream_file_key => 'file',
      source => { type => 'single', url => "https://hoge/$uk/" },
    },
  }, {
    "https://hoge/$uk/" => {text => "<p>ab</p>"},
    $current->legal_url_prefix . 'websites.json' => {
      json => [
        {
          url_prefix => "https://hoge/$uk/",
          source => {type => 'packref', url => "https://hoge/$uk/license.json"},
          legal_key => "$uk-license",
        },
      ],
    },
    "https://hoge/$uk/license.json" => {
      json => {
        type => 'packref',
        source => {type => 'files'},
      },
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->run ('legal', additional => [$fkey, '--json'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      my $item = $r->{jsonl}->[0];
      is 0+@{$item->{legal}}, 2;
      {
        my $l = $item->{legal}->[0];
        is $l->{type}, 'site_terms';
        is $l->{key}, "$uk-license";
        is $l->{source_type}, 'site_legal';
      }
      {
        my $l = $item->{legal}->[1];
        is $l->{type}, 'disclaimer';
        is $l->{key}, '-ddsd-disclaimer';
        is $l->{source_type}, 'sniffer';
      }
    } $current->c;
  });
} n => 8, name => 'filtered inherits upstream legal';

Run;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
