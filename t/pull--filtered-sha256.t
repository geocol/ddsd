use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;
use JSON::PS;

sub _content_and_sha {
  my ($current, $key) = @_;
  my $root = $current->app_path(0)->child('local');
  my @idx;
  $root->visit(sub { push @idx, $_ if $_->basename eq 'index.json' and $_->stringify =~ /\Q$key\E/ }, {recurse=>1});
  for my $p (@idx) {
    my $x = eval { json_bytes2perl $p->slurp };
    next unless ref $x eq 'HASH' and $x->{items}->{file};
    my $dp = $p->parent->child($x->{items}->{file}->{files}->{data});
    return ($dp->slurp_utf8, $x->{items}->{file}->{rev}->{sha256}) if -f $dp;
  }
  return (undef, undef);
}

Test {
  my $current = shift;
  my $key = 'fsh_' . rand;
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
    test { is($r->{exit_code}, 0, 'pull ok') } $current->c;
    my ($c, $sha) = _content_and_sha($current, $key);
    test { like $c, qr/V1/, 'v1'; ok $sha, 'has sha' } $current->c;
    my $pkg_path = $current->app_path(0)->child('config/ddsd/packages.json');
    my $pkg = json_bytes2perl $pkg_path->slurp;
    $pkg->{$key}->{files}->{file}->{sha256} = $sha;
    $pkg_path->spew(perl2json_bytes_for_record $pkg);
    return $current->prepare (undef, {
      "https://hoge/$uk" => {text => "<p>V2</p>", mime => "text/html"},
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 12, 'mismatch gives error') } $current->c;
    my ($c, $sha2) = _content_and_sha($current, $key);
    test { like $c, qr/V1/, 'old content kept'; unlike $c, qr/V2/, 'v2 not stored' } $current->c;
  });
} n => 6, name => 'filtered sha256 pinned mismatch';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
