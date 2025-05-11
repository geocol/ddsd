use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/" . $key => {text => "r1"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key", '--single-file', '--min']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         {
           my $file = $json->{items}->{file};
           is $file->{type}, 'file';
           is $file->{files}->{data}, "files/$key";
           is $file->{rev}->{original_url}, "https://hoge/$key";
           is $file->{rev}->{url}, "https://hoge/$key";
           ok $file->{rev}->{sha256};
           ok $file->{rev}->{timestamp};
           ok ! $file->{rev}->{insecure};
         }
       }},
      {path => "local/data/$key/files/$key", text => "r1"},
    ]);
  });
} n => 14, name => '--min then all';

Run;

=head1 LICENSE

Copyright 2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
