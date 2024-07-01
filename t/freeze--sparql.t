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
    return $current->run ('freeze', additional => ["foo"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         is 0+keys %{$json->{foo}->{files}}, 19;
         {
           my $item = $json->{foo}->{files}->{'file:r:sparql'};
           is $item->{name}, undef;
           is $item->{sha256}, undef;
         }
         {
           my $item = $json->{foo}->{files}->{'part:sparql[file:r:sparql]:0'};
           is $item->{name}, undef;
           is $item->{sha256}, '5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9';
         }
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
