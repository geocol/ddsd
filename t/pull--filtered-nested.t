use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

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
  my $key = 'ffn_' . rand;
  my $uk = 'u_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file',
        source => {
          type => 'filtered',
          filter => 'strip_tags',
          upstream_file_key => 'file',
          source => { type => 'single', url => "https://hoge/$uk" },
        },
      },
    },
    { "https://hoge/$uk" => {text => "<p><b>Hi</b></p><script>x</script>", mime => "text/html"} },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 0, 'pull ok') } $current->c;
    my $c = _content($current, $key);
    test { like $c, qr/Hi/, 'has Hi'; unlike $c, qr/<b>/, 'no b'; unlike $c, qr/<script/, 'no script' } $current->c;
    return $current->run ('use', additional => [$key, 'file']);
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 0, 'use ok') } $current->c;
  });
} n => 5, name => 'nested filtered pull/use';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
