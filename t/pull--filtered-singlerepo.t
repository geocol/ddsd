use strict;
use warnings;
use Path::Tiny;
use JSON::PS;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = 'filtered_' . rand;
  my $upkey = 'up_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file',
        source => {
          type => 'single',
          url => "https://hoge/$upkey",
        },
      },
    },
    {
      "https://hoge/$upkey" => {text => "<html><body><p>hi</p><script>x</script></body></html>", mime => "text/html; charset=utf-8"},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0, 'pull exit 0';
    } $current->c;
    return $current->run ('ls', additional => [$key]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0, 'ls exit 0';
    } $current->c;
    # find filtered index.json (own or nested storage)
    my $root = $current->app_path(0)->child('local');
    my @idx;
    $root->visit(sub { push @idx, $_ if $_->basename eq 'index.json' }, {recurse => 1});
    my ($j, $jpath);
    for my $p (@idx) {
      my $x = eval { json_bytes2perl $p->slurp }; next unless ref $x eq 'HASH';
      if ($x->{items} && $x->{items}->{file} && ($x->{items}->{file}->{type}||'') eq 'file') {
        # prefer own-storage index for this key
        if ($p->stringify =~ /\Q$key\E/) { $j = $x; $jpath = $p; last; }
        $j ||= $x; $jpath ||= $p;
      }
    }
    test {
      ok $j, 'found filtered index with file item';
      ok(($j && $j->{items}->{file} && $j->{items}->{file}->{files}->{data}), 'has data file ref');
    } $current->c;
    if ($j && $jpath && $j->{items}->{file} && $j->{items}->{file}->{files}->{data}) {
      my $dpath = $jpath->parent->child($j->{items}->{file}->{files}->{data});
      my $content = $dpath->slurp_utf8;
      test {
        ok -f $dpath, 'filtered data file exists';
        ok index($content, '<p>') < 0, 'no <p> tag';
        ok index($content, '<script') < 0, 'no <script tag';
        like $content, qr/hi/;
      } $current->c;
    } else {
      test { ok 0, 'data file'; ok 0, 'no p'; ok 0, 'no script'; ok 0, 'hi' } $current->c;
    }
    return;
  });
} n => 8, name => 'pull+ls filtered single';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
