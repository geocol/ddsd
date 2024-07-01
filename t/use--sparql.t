use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare ({
    abc => {
      type => 'packref',
      url => "https://hoge/$key/empty.json",
    },
  }, {
    "https://hoge/$key/empty.json" => {
      json => {
        type => 'packref',
        source => {
          type => 'files',
        },
      },
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->prepare ({
      foo => {
        type => 'packref',
        url => "https://hoge/$key/pack.json",
      },
    }, {
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
    });
  })->then (sub {
    return $current->run ('unuse', additional => ['foo', 'file:r:sparql']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         ok $json->{foo}->{files}->{"file:r:sparql"}->{skip};
       }},
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => "local/data/foo/files/sparqlep", is_none => 1},
    ]);
  })->then (sub {
    return $current->run ('use', additional => ['foo', 'file:r:sparql']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         ok ! $json->{foo}->{files}->{"file:r:sparql"}->{skip};
       }},
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
    ]);
  })->then (sub {
    return $current->run ('unuse', additional => ['foo', 'file:r:sparql']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         ok $json->{foo}->{files}->{"file:r:sparql"}->{skip};
       }},
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => "local/data/foo/files/sparqlep", is_none => 1},
    ]);
  });
} n => 38, name => 'sparql';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
