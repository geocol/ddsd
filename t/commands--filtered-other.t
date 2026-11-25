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

# filtered over DCAT-US
Test {
  my $current = shift;
  my $key = 'cfd_' . rand;
  my $uk = rand;
  my $ds_id = "https://hoge/dataset/$uk";
  my $feed_url = "https://hoge/feed_$uk.json";
  my $dist_url = "https://hoge/dist_$uk.html";
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => "file:url:$dist_url",
        source => {
          type => 'dcatus',
          id => $ds_id,
          source => { type => 'single', url => $feed_url },
        },
      },
    },
    {
      $feed_url => {json => {
        dataset => [{
          identifier => $ds_id,
          title => 'DS',
          distribution => [{
            downloadURL => $dist_url,
            mediaType => 'text/html',
          }],
        }],
      }},
      $dist_url => {text => "<b>T</b><p>D</p>", mime => "text/html"},
    },
  )->then (sub {
    return $current->run ('use', additional => [$key, 'file']);
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 0, 'use ok') } $current->c;
    my $c = _content($current, $key);
    test { like $c, qr/T/, 'has T'; unlike $c, qr/<b>/, 'no b' } $current->c;
    return $current->run ('export', additional => ['mirrorzip', $key, 'out.zip']);
  })->then (sub {
    return $current->check_files ([{path => 'out.zip', zip => sub {
      ok $_[0]->{'index.json'}->{central}->{byte_length}, 'has index';
    }}]);
  });
} n => 5, name => 'filtered dcatus commands';

# filtered over CKAN
Test {
  my $current = shift;
  my $key = 'cfc_' . rand;
  my $uk = rand;
  my $pkg = "pkg_$uk";
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file:id:abc',
        file_url => "https://hoge/$uk/abc.html",
        source => { type => 'ckan', url => "https://hoge/dataset/$pkg" },
      },
    },
    {
      "https://hoge/api/action/package_show?id=$pkg" => {json => {
        success => \1,
        result => {
          name => $pkg,
          title => 'P',
          resources => [{id => 'abc', url => "https://hoge/$uk/abc.html", format => 'HTML'}],
        },
      }},
      "https://hoge/$uk/abc.html" => {text => "<i>Hello</i>", mime => "text/html"},
    },
  )->then (sub {
    return $current->run ('use', additional => [$key, 'file']);
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 0, 'use ok') } $current->c;
    my $c = _content($current, $key);
    test { like $c, qr/Hello/, 'has Hello'; unlike $c, qr/<i>/, 'no i' } $current->c;
  });
} n => 3, name => 'filtered ckan commands';

# unuse then pull should not error
Test {
  my $current = shift;
  my $key = 'cfu_' . rand;
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
    { "https://hoge/$uk" => {text => "<p>X</p>", mime => "text/html"} },
  )->then (sub {
    return $current->run ('use', additional => [$key, 'file']);
  })->then (sub {
    return $current->run ('unuse', additional => [$key, 'file']);
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 0, 'pull after unuse ok') } $current->c;
  });
} n => 1, name => 'filtered pull after unuse';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
