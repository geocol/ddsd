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
      "https://hoge/" . $key => {text => "<p>hi</p>", mime => "text/html"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key", '--single-file', '--filter=strip_tags']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         my $found;
         for my $k (keys %$json) {
           if ($json->{$k}->{type} eq 'filtered' && $json->{$k}->{filter} eq 'strip_tags') {
             $found = $json->{$k};
             last;
           }
         }
         test {
           ok $found, 'found filtered package';
           if ($found) {
             is $found->{source}->{type}, 'single';
             is $found->{source}->{url}, "https://hoge/$key";
             is $found->{upstream_file_key}, 'file';
           }
         } $current->c;
       }},
    ]);
  });
} n => 6, name => 'add --single-file --filter=strip_tags';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
