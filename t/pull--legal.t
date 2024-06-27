use strict;
use warnings;
use Path::Tiny;
BEGIN { $ENV{TEST_MAX_CONCUR} = 1 }
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->prepare (undef, {
    $current->legal_url_prefix . 'packref.json' => {
      json => {
        type => 'packref',
        source => {
          type => 'files',
          files => {
            'file:r:ckan.json' => {
              url => 'abc',
            },
          },
        },
      },
    },
    $current->legal_url_prefix . 'abc' => {
      text => 'ABC',
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config', is_none => 1},
      {path => 'local/data', is_none => 1},
      {path => 'local/ddsd/data/legal/index.json', json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 1;
         is $json->{items}->{'file:r:ckan.json'}->{files}->{data}, 'files/abc';
       }},
      {path => 'local/ddsd/data/legal/files/abc', text => 'ABC'},
      {path => $current->repo_path ('packref', $current->legal_url_prefix.'packref.json') . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{$current->legal_url_prefix . "packref.json"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, undef;
         }
       }},
    ]);
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'update skipped because repo is new';
    return $current->check_files ([
      {path => 'config', is_none => 1},
      {path => 'local/data', is_none => 1},
      {path => 'local/ddsd/data/legal/index.json', json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 1;
         is $json->{items}->{'file:r:ckan.json'}->{files}->{data}, 'files/abc';
       }},
      {path => 'local/ddsd/data/legal/files/abc', text => 'ABC'},
      {path => $current->repo_path ('packref', $current->legal_url_prefix.'packref.json') . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{$current->legal_url_prefix . "packref.json"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, undef;
           $current->set_o (time1 => $v);
         }
       }},
    ]);
  })->then (sub {
    return $current->run ('pull', additional => ['--now' => time + 100*60*60]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'config', is_none => 1},
      {path => 'local/data', is_none => 1},
      {path => 'local/ddsd/data/legal/index.json', json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 1;
         is $json->{items}->{'file:r:ckan.json'}->{files}->{data}, 'files/abc';
       }},
      {path => 'local/ddsd/data/legal/files/abc', text => 'ABC'},
      {path => $current->repo_path ('packref', $current->legal_url_prefix.'packref.json') . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{$current->legal_url_prefix . "packref.json"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 2;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, undef;
           $current->set_o (time1 => $v);
         }
         {
           my $v = json_bytes2perl $lines->[1];
           ok $v->{timestamp} > $current->o ('time1')->{timestamp};
           is $v->{legal_key}, undef;
         }
       }},
    ]);
  });
} n => 26, name => 'legal';

Test {
  my $current = shift;
  return $current->prepare (undef, {
    $current->legal_url_prefix . 'packref.json' => {
      json => {
        type => 'packref',
        source => {
          type => 'files',
          files => {
            'file:r:ckan.json' => {
              url => 'abc',
            },
          },
        },
      },
    },
    $current->legal_url_prefix . 'abc' => {
      text => 'ABC',
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare (undef, {
      $current->legal_url_prefix . 'abc' => {
        text => 'XYZ',
      },
    });
  })->then (sub {
    return $current->check_files ([
      {path => 'local/ddsd/data/legal/files/abc', text => 'ABC'},
    ]); # not updated yet
  })->then (sub {
    return $current->run ('pull', additional => ['--now', time + 100*60*60]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0, $$;
    } $current->c;
    return $current->check_files ([
      {path => 'local/ddsd/data/legal/files/abc', text => 'XYZ'},
    ]); 
  });
} n => 7, name => 'pull second';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
