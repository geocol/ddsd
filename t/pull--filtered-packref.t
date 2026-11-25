use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = 'fp_' . rand;
  my $upkey = 'up_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file',
        file_url => "https://hoge/$upkey.html",
        source => {
          type => 'packref',
          url => "https://hoge/$upkey/pack.json",
        },
      },
    },
    {
      "https://hoge/$upkey/pack.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'single',
            url => "https://hoge/$upkey.html",
          },
        },
      },
      "https://hoge/$upkey.html" => {
        text => "<html><body><p>Hello</p><script>x()</script></body></html>",
        mime => "text/html; charset=utf-8",
      },
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
    # find filtered data
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
      unlike $content, qr/<p>/, 'no p tag';
      unlike $content, qr/<script/, 'no script';
      like $content, qr/Hello/, 'has text';
    } $current->c;
  });
} n => 6, name => 'pull filtered packref single';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
