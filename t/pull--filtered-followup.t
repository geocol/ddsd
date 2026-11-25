use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = 'ff_' . rand;
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
    { "https://hoge/$uk" => {text => "<p>V1</p>", mime => "text/html"} },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0, 'pull 1 ok' } $current->c;
    my $content = _content($current, $key);
    test { like $content, qr/V1/, 'v1 content' } $current->c;
    return $current->prepare (undef, {
      "https://hoge/$uk" => {text => "<p>V2</p><script>x</script>", mime => "text/html"},
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0, 'pull 2 ok' } $current->c;
    my $content = _content($current, $key);
    test {
      like $content, qr/V2/, 'v2 content';
      unlike $content, qr/V1/, 'v1 gone';
      unlike $content, qr/<script/, 'no script';
    } $current->c;
  });
} n => 6, name => 'filtered follows upstream change';

sub _content {
  my ($current, $key) = @_;
  my $root = $current->app_path(0)->child('local');
  my @idx;
  $root->visit(sub { push @idx, $_ if $_->basename eq 'index.json' and $_->stringify =~ /\Q$key\E/ }, {recurse=>1});
  for my $p (@idx) {
    my $x = eval { json_bytes2perl $p->slurp };
    next unless ref $x eq 'HASH' and $x->{items}->{file};
    my $dp = $p->parent->child($x->{items}->{file}->{files}->{data});
    return $dp->slurp_utf8 if -f $dp;
  }
  return '';
}



Test {
  my $current = shift;
  my $key = 'ff_' . rand;
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
    { "https://hoge/$uk" => {text => "<p>Same</p>", mime => "text/html"} },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0]; test { is $r->{exit_code}, 0, 'pull 1 ok' } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0]; test { is $r->{exit_code}, 0, 'pull 2 ok' } $current->c;
    my $content = _content($current, $key);
    test { like $content, qr/Same/, 'content still there'; unlike $content, qr/<p>/, 'still stripped' } $current->c;
  });
} n => 4, name => 'filtered idempotent pull';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
