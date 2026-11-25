use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = 'uf_' . rand;
  my $uk = 'u_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file',
        source => { type => 'single', url => "https://hoge/$uk" },
      },
    },
    {
      "https://hoge/$uk" => {text => "<p>Hi</p><script>x</script>", mime => "text/html; charset=utf-8"},
    },
  )->then (sub {
    return $current->run ('use', additional => [$key, 'file']);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0, 'use ok' } $current->c;
    my $root = $current->app_path(0)->child('local');
    my @idx;
    $root->visit(sub { push @idx, $_ if $_->basename eq 'index.json' and $_->stringify =~ /\Q$key\E/ }, {recurse=>1});
    my ($j,$jpath);
    for my $p (@idx) {
      my $x = eval { json_bytes2perl $p->slurp };
      next unless ref $x eq 'HASH' and $x->{items}->{file};
      $j=$x; $jpath=$p; last;
    }
    my $content = '';
    $content = $jpath->parent->child($j->{items}->{file}->{files}->{data})->slurp_utf8
        if $j && $jpath && $j->{items}->{file}->{files}->{data};
    test {
      ok $j, 'has index';
      unlike $content, qr/<p>/, 'no p';
      like $content, qr/Hi/, 'has text';
    } $current->c;
  });
} n => 4, name => 'use filtered single';

Test {
  my $current = shift;
  my $key = 'ua_' . rand;
  my $uk = 'u_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file',
        source => { type => 'single', url => "https://hoge/$uk" },
      },
    },
    {
      "https://hoge/$uk" => {text => "<p>All</p>", mime => "text/html"},
    },
  )->then (sub {
    return $current->run ('use', additional => [$key, '--all']);
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0, 'use --all ok' } $current->c;
    my $dir = $current->app_path(0)->child("local/data/$key/files");
    my @files = $dir->is_dir ? $dir->children : ();
    test { ok @files >= 1, 'has file in data area' } $current->c;
  });
} n => 2, name => 'use --all filtered single';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
