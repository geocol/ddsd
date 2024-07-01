use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {},
    {
      "https://hoge/$key/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'files',
            files => {
              "file:r:sparql" => {
                url => "https://hoge/$key/sparqlep",
                set_type => 'sparql',
              },
            },
          },
        },
      },
      (map {
        ("https://hoge/$key/sparqlep?query=SELECT%20%2A%20WHERE%20%7B%20%20%3Fs%20%3Fp%20%3Fo%20.%20%20FILTER%20(STRSTARTS(SUBSTR(MD5(STR(%3Fs)),%201,%202),%20%22".$_."%22))%20%7D" => {
          text => $_,
        });
      } 0..9, 'a'..'f'),
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key/pack.json", "--name", "foo"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('export', additional => ['mirrorzip', 'foo', 'foo.zip']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "foo.zip", zip => sub {
         my $files = shift;
         ok $files->{"index.json"}->{size};
         ok $files->{"LICENSE"}->{size};
         is $files->{'data/18ac3e7343f016890c510e93f935261169d9e3f565436429830faf0934f4f8e4.dat'}->{size}, 1;
         is $files->{'data/19581e27de7ced00ff1ce50b2047e7a567c76b1cbaebabe5ef03f7c3017bb5b7.dat'}->{size}, 1;
         is 0+(grep { m{^data/} } keys %$files), 17;
       }},
    ]);
  });
} n => 8, name => 'sparql';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
