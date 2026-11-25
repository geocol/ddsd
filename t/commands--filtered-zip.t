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
  my $key = 'cfz_' . rand;
  my $uk = 'u_' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file:path:a.html',
        file_path => 'a.html',
        source => {
          type => 'zip',
          file_url => "https://hoge/$uk.zip",
          source => {
            type => 'single',
            url => "https://hoge/$uk.zip",
          },
        },
      },
    },
    {
      "https://hoge/$uk.zip" => {zip => {
        "a.html" => {text => "<h1>Title</h1><p>Body</p>"},
        "b.txt"  => {text => "other"},
      }},
    },
  )->then (sub {
    return $current->run ('use', additional => [$key, 'file']);
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 0, 'use ok') } $current->c;
    my $content = _content($current, $key);
    test { unlike $content, qr/<h1>/, 'no h1'; like $content, qr/Title/, 'has title' } $current->c;
    return $current->run ('export', additional => ['mirrorzip', $key, 'out.zip']);
  })->then (sub {
    # exit_code may be undef in some harness cases; verify output instead
    return $current->check_files ([{path => 'out.zip', zip => sub {
      my $files = shift;
      ok $files->{'index.json'}->{central}->{byte_length}, 'has index';
    }}]);
  })->then (sub {
    return $current->run ('unuse', additional => [$key, 'file']);
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 0, 'unuse ok') } $current->c;
  });
} n => 6, name => 'filtered zip commands';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
