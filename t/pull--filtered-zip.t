use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = 'fz_' . rand;
  my $upkey = 'up_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file:path:page.html',
        source => {
          type => 'zip',
          file_url => "https://hoge/$upkey.zip",
          source => {
            type => 'single',
            url => "https://hoge/$upkey.zip",
          },
        },
      },
    },
    {
      "https://hoge/$upkey.zip" => {zip => {
        "page.html" => {text => "<html><body><h1>Title</h1><p>Body</p></body></html>", timestamp => 1766890774, tzoffset => 0},
        "other.txt" => {text => "other"},
      }},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0, 'pull ok' } $current->c;
    return $current->run ('ls', additional => [$key]);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0, 'ls ok' } $current->c;
    my $root = $current->app_path(0)->child('local');
    my @idx;
    $root->visit(sub { push @idx, $_ if $_->basename eq 'index.json' }, {recurse => 1});
    my ($j,$jpath);
    for my $p (@idx) {
      my $x = eval { json_bytes2perl $p->slurp }; next unless ref $x eq 'HASH';
      if ($x->{items} && $x->{items}->{file} && ($x->{items}->{file}->{type}||'') eq 'file') {
        if ($p->stringify =~ /\Q$key\E/ || $p->stringify =~ /filtered/) { $j=$x;$jpath=$p; last }
        $j||=$x; $jpath||=$p;
      }
    }
    test { ok $j, 'found index' } $current->c;
    my $content = '';
    if ($j && $jpath && $j->{items}->{file}->{files}->{data}) {
      $content = $jpath->parent->child($j->{items}->{file}->{files}->{data})->slurp_utf8;
    }
    test {
      unlike $content, qr/<h1>/, 'no h1';
      unlike $content, qr/<p>/, 'no p';
      like $content, qr/Title/, 'has title';
      like $content, qr/Body/, 'has body';
    } $current->c;
  });
} n => 7, name => 'pull filtered zip';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
