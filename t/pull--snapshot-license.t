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
          {id => "foo", url => "bar", title => "abc", is => "a-x"},
          {id => "foo2", url => "bar", title => "abc", is => "b-x"},
        ],
      },
      $current->legal_url_prefix . 'websites.json' => {
        json => [{
          url_prefix => "https://hoge/$key/",
          source => {type => 'packref', url => "https://hoge/$key/license.json"},
          legal_key => "$key-license",
        }],
      },
      $current->legal_url_prefix . 'info.json' => {
        json => {
          "$key-license" => {
            label => "\x{3000} $key License",
          },
        },
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
    return $current->check_files ([
      {path => 'local/data/foo/LICENSE', text => sub {
         my $text = shift;
         like $text, qr{"a-x"};
         like $text, qr{\Qhttps://hoge/$key/api/action/package_show?id=$key\E};
         like $text, qr{\x{3000}\Q $key License\E};
         like $text, qr{Disclaimer};
       }},
    ]);
  })->then (sub {
    return $current->prepare (undef, {
      "https://hoge/$key/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [],
          license_id => "foo2",
          license_url => "bar",
          license_title => "abc",
        }},
      },
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/LICENSE', text => sub {
         my $text = shift;
         unlike $text, qr{"a-x"};
         like $text, qr{"b-x"};
         like $text, qr{\Qhttps://hoge/$key/api/action/package_show?id=$key\E};
         like $text, qr{\x{3000}\Q $key License\E};
         like $text, qr{Disclaimer};
       }},
    ]);
  });
} n => 13, name => 'legal generated';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
