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
  my $key = 'cfcs_' . rand;
  my $uk = rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file:package_list.json',
        source => { type => 'ckansite', url => "https://hoge/$uk/" },
      },
    },
    {
      "https://hoge/$uk/api/action/package_list" => {
        json => { success => \1, result => ["<b>abc</b>", "def"] },
      },
    },
  )->then (sub {
    return $current->run ('use', additional => [$key, 'file']);
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 12, 'use ok') } $current->c;
    my $c = _content($current, $key);
    test { like $c, qr/abc/, 'has abc'; unlike $c, qr/<b>/, 'no b' } $current->c;
    return $current->run ('legal', additional => [$key]);
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 0, 'legal ok') } $current->c;
    return $current->run ('export', additional => ['mirrorzip', $key, 'out.zip']);
  })->then (sub {
    return $current->check_files ([{path => 'out.zip', zip => sub {
      ok $_[0]->{'index.json'}->{central}->{byte_length}, 'has index';
    }}]);
  })->then (sub {
    return $current->run ('unuse', additional => [$key, 'file']);
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 12, 'unuse ok') } $current->c;
  });
} n => 7, name => 'filtered ckansite commands';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
