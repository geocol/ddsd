use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = 'fc_' . rand;
  my $ukey = 'u_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file:id:abc',
        file_url => "https://hoge/$ukey/abc.html",
        source => {
          type => 'ckan',
          url => "https://hoge/$ukey/dataset/package-name",
        },
      },
    },
    {
      "https://hoge/$ukey/api/action/package_show?id=package-name" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "abc", url => "https://hoge/$ukey/abc.html"},
            ],
          },
        },
      },
      "https://hoge/$ukey/abc.html" => {
        text => "<div><b>CKAN</b></div>",
        mime => "text/html",
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is $r->{exit_code}, 0, 'pull ok' } $current->c;
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
    my $content = '';
    if ($j && $jpath && $j->{items}->{file}->{files}->{data}) {
      $content = $jpath->parent->child($j->{items}->{file}->{files}->{data})->slurp_utf8;
    }
    test { ok $j, 'found index'; unlike $content, qr/<b>/, 'no b'; like $content, qr/CKAN/, 'has text' } $current->c;
  });
} n => 4, name => 'pull filtered ckan';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
