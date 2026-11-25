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
  my $key = 'cfp_' . rand;
  my $uk = rand;
  return $current->prepare (
    {
      $key => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => 'file',
        file_url => "https://hoge/$uk.html",
        source => {
          type => 'packref',
          url => "https://hoge/$uk/pack.json",
        },
      },
    },
    {
      "https://hoge/$uk/pack.json" => {
        json => {
          type => 'packref',
          source => { type => 'single', url => "https://hoge/$uk.html" },
        },
      },
      "https://hoge/$uk.html" => {text => "<p>A1</p><script>x</script>", mime => "text/html; charset=utf-8"},
    },
  )->then (sub {
    return $current->run ('use', additional => [$key, 'file']);
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 0, 'use ok') } $current->c;
    my $content = _content($current, $key);
    test { like $content, qr/A1/, 'has A1'; unlike $content, qr/<p>/, 'no p' } $current->c;
    return $current->run ('legal', additional => [$key]);
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 0, 'legal ok') } $current->c;
    return $current->run ('export', additional => ['mirrorzip', $key, 'out.zip']);
  })->then (sub {
    my $r=$_[0];
    test { is $r->{exit_code}, 0, 'export ok' } $current->c;
    return $current->check_files ([{path => 'out.zip', zip => sub {
      my $files = shift;
      ok $files->{'index.json'}->{central}->{byte_length}, 'has index';
      ok $files->{'LICENSE'}->{central}->{byte_length}, 'has LICENSE';
    }}]);
  })->then (sub {
    return $current->run ('unuse', additional => [$key, 'file']);
  })->then (sub {
    my $r = $_[0];
    test { is($r->{exit_code}, 12, 'unuse ok') } $current->c;
  });
} n => 9, name => 'filtered packref commands';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
