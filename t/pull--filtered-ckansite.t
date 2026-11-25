use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = 'fcs_' . rand;
  my $uk = rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file:package_list.json',
        source => {
          type => 'ckansite',
          url => "https://hoge/$uk/",
        },
      },
    },
    {
      "https://hoge/$uk/api/action/package_list" => {
        json => {
          success => \1,
          result => ["<b>abc</b>", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 12, 'pull ok') } $current->c;
    my $root = $current->app_path(0)->child('local');
    my @idx;
    $root->visit(sub { push @idx, $_ if $_->basename eq 'index.json' and $_->stringify =~ /\Q$key\E/ }, {recurse=>1});
    my $content = '';
    for my $p (@idx) {
      my $x = eval { json_bytes2perl $p->slurp };
      next unless ref $x eq 'HASH' and $x->{items}->{file};
      my $dp = $p->parent->child($x->{items}->{file}->{files}->{data});
      $content = $dp->slurp_utf8 if -f $dp;
    }
    test {
      like $content, qr/abc/, 'has abc';
      unlike $content, qr/<b>/, 'no b tag';
      like $content, qr/def/, 'has def';
    } $current->c;
  });
} n => 4, name => 'pull filtered ckansite';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
