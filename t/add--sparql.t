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
          mime => 'text/turtle',
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
    return $current->run ('use', additional => ["foo", "--all"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 17;
         {
           my $item = $json->{items}->{'part:sparql[file:r:sparql]:0'};
           is $item->{files}->{data}, 'files/sparqlep/part-0.ttl';
           is $item->{rev}->{url}, "https://hoge/$key/sparqlep?query=SELECT%20%2A%20WHERE%20%7B%20%20%3Fs%20%3Fp%20%3Fo%20.%20%20FILTER%20(STRSTARTS(SUBSTR(MD5(STR(%3Fs)),%201,%202),%20%220%22))%20%7D";
           is $item->{type}, 'part';
         }
         ok $json->{items}->{'part:sparql[file:r:sparql]:1'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:2'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:3'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:4'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:5'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:6'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:7'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:8'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:9'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:a'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:b'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:c'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:d'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:e'};
         ok $json->{items}->{'part:sparql[file:r:sparql]:f'};
       }},
      {path => "local/data/foo/files/sparqlep/part-0.ttl", text => "0"},
      {path => "local/data/foo/files/sparqlep/part-f.ttl", text => "f"},
      {path => "local/data/foo/package/packref.json", json => sub { }},
    ]);
  })->then (sub {
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 19;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
      } 
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'meta';
      } 
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'dataset';
        is $item->{set_type}, 'sparql';
        ok $item->{set_expanded};
        is $item->{package_item}->{mime}, undef;
      }
      {
        my $item = $r->{jsonl}->[3];
        is $item->{type}, 'part';
        is $item->{set_type}, undef;
        ok ! $item->{set_expanded};
        is $item->{package_item}->{mime}, 'text/turtle';
      }
    } $current->c;
  });
} n => 38, name => 'sparql';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
