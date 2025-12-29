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
      "https://hoge/$key.zip" => {zip => {
        "abc.txt" => {text => "abc\x{4e00}", timestamp => 4194819466},
        "xyz.txt" => {bytes => "\x00AB\x80"},
      }},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip", '--min']);
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
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{"file:xyz.txt"};
         {
           my $x = $json->{items}->{"file:abc.txt"};
           is $x->{files}->{data}, "files/abc.txt";
           is $x->{rev}->{length}, 6;
           is $x->{rev}->{path}, "abc.txt";
           is $x->{rev}->{raw_path}, "abc.txt";
           is $x->{rev}->{sha256}, 'c778006564571afe966b248a8c8bda7cf00232157408c0759920e0272ec6b773';
           is $x->{rev}->{timestamp}, 4194819466;
         }
       }},
      {path => "local/data/$key/LICENSE", file => 1},
      {path => "local/data/$key/files/abc.txt", text => "abc\x{4e00}"},
      {path => "local/data/$key/files/xyz.txt", bytes => "\x00AB\x80"},
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         ok $json->{$key};
         {
           my $item = $json->{$key};
           is $item->{type}, 'zip';
           is $item->{source}->{type}, 'single';
           is $item->{source}->{url}, "https://hoge/$key.zip";
           is $item->{file_key}, 'file';
           is 0+keys %{$item->{files}}, 2;
           ok $item->{files}->{"file:abc.txt"};
           ok $item->{files}->{"file:xyz.txt"};
           ok ! $item->{files}->{"file:abc.txt"}->{skip};
           ok ! $item->{files}->{"file:xyz.txt"}->{skip};
         }
       }},
    ]);
  });
} n => 26, name => '--min then all';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc.txt" => {text => "abc\x{4e00}", timestamp => 4194819466},
        "xyz.txt" => {bytes => "\x00AB\x80"},
      }},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip", '--min']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, "file:abc.txt"]);
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
           my $x = $json->{items}->{"file:abc.txt"};
           is $x->{files}->{data}, "files/abc.txt";
           is $x->{rev}->{length}, 6;
           is $x->{rev}->{path}, "abc.txt";
           is $x->{rev}->{raw_path}, "abc.txt";
           is $x->{rev}->{sha256}, 'c778006564571afe966b248a8c8bda7cf00232157408c0759920e0272ec6b773';
           is $x->{rev}->{timestamp}, 4194819466;
         }
       }},
      {path => "local/data/$key/LICENSE", file => 1},
      {path => "local/data/$key/files/abc.txt", text => "abc\x{4e00}"},
      {path => "local/data/$key/files/xyz.txt", is_none => 1},
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         ok $json->{$key};
         {
           my $item = $json->{$key};
           is $item->{type}, 'zip';
           is $item->{source}->{type}, 'single';
           is $item->{source}->{url}, "https://hoge/$key.zip";
           is $item->{file_key}, 'file';
           is 0+keys %{$item->{files}}, 2;
           ok $item->{files}->{"file:abc.txt"};
           ok ! $item->{files}->{"file:abc.txt"}->{skip};
           ok $item->{files}->{"file:xyz.txt"}->{skip};
         }
       }},
    ]);
  });
} n => 23, name => 'use single';

Run;

=head1 LICENSE

Copyright 2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
