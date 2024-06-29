use strict;
use warnings;
use utf8;
use Path::Tiny;
BEGIN { $ENV{TEST_MAX_CONCUR} = 1 }
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = rand;
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
    "https://hoge/$key/index.json" => {
      json => {
        type => 'packref',
        source => {type => 'files'},
      },
    },
  })->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key/index.json"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data', is_none => 1},
      {path => 'local/ddsd/data/legal/index.json', json => sub {
         my $json = shift;
         is 0+keys %{$json->{items}}, 1;
         is $json->{items}->{'file:r:ckan.json'}->{files}->{data}, 'files/abc';
       }},
      {path => 'local/ddsd/data/legal/files/abc', text => 'ABC'},
    ]);
  });
} n => 4, name => 'legal';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (undef, {
    "https://hoge/$key/dataset/" . $key => {
      text => q{<meta name="generator" content="ckan 1.2.3">},
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
    "https://hoge/$key/api/action/package_show?id=" . $key => {
      json => {success => \1, result => {
      }},
      etag => '"abc"',
    },
    "https://hoge/$key/dataset/activity/" . $key => {
      text => qq{<a href="/$key/license">オープンデータ利用規約</a>},
    },
  })->then (sub {
    $current->set_o (time1 => time);
    return $current->run ('add', additional => ["https://hoge/$key/dataset/$key"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         
         is 0+keys %{$json->{items}}, 2;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         ok $json->{items}->{$file_key}->{files}->{log};

         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp} > $current->o ('time1');
           is $v->{legal_key}, "$key-license";
           is $v->{legal_source_key}, "package:activity.html";
           is $v->{legal_source_url}, "https://hoge/$key/license";
         }
       }},
    ]);
  });
} n => 9, name => 'legal from package:activity.html';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (undef, {
    "https://hoge/$key/dataset/" . $key => {
      text => q{<meta name="generator" content="ckan 1.2.3">},
    },
    $current->legal_url_prefix . 'websites.json' => {
      json => [{
        url_prefix => "https://hoge/$key/",
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
    "https://hoge/$key/api/action/package_show?id=" . $key => {
      json => {success => \1, result => {
      }},
      etag => '"abc"',
    },
  })->then (sub {
    $current->set_o (time1 => time);
    return $current->run ('add', additional => ["https://hoge/$key/dataset/$key"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         
         is 0+keys %{$json->{items}}, 1;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         ok $json->{items}->{$file_key}->{files}->{log};

         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp} > $current->o ('time1');
           is $v->{legal_key}, "$key-license";
           is $v->{legal_source_key}, undef;
           is $v->{legal_source_url}, undef;
         }
       }},
    ]);
  });
} n => 9, name => 'legal from site legal';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
