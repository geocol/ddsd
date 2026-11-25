use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $uk = 'u_' . rand;
  my $name = 'my-filtered-' . int(rand 100000);
  return $current->prepare (
    undef,
    {
      "https://hoge/$uk" => {text => "<p>Hello</p>", mime => "text/html"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$uk", '--single-file', '--filter=strip_tags', "--name=$name"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0, 'add ok';
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         test {
           ok $json->{$name}, 'package key is specified name';
           if ($json->{$name}) {
             is $json->{$name}->{type}, 'filtered';
             is $json->{$name}->{filter}, 'strip_tags';
             is $json->{$name}->{source}->{type}, 'single';
           }
         } $current->c;
       }},
    ]);
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0, 'pull ok' } $current->c;
    return $current->run ('ls', additional => [$name, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0, 'ls ok';
      my @files = grep { $_->{type} eq 'file' } @{$r->{jsonl}};
      is 0+@files, 1, 'one file';
      if (@files) {
        is $files[0]->{package_item}->{file_name}, 'file.txt', 'default file_name';
        is $files[0]->{package_item}->{mime}, 'text/plain', 'mime';
      }
    } $current->c;
  });
} n => 11, name => 'add --filter with --name and ls file_name';

Run;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
