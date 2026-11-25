use strict;
use warnings;
use Path::Tiny;
use Digest::SHA qw(sha256_hex);
BEGIN { $ENV{TEST_MAX_CONCUR} = 1 }
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $dskey = 'abc123def456abc123def456abc123de';
  my $ds_id = "https://www.arcgis.com/home/item.html?id=$dskey";
  my $feed_url = "https://hoge/api/feed/dcat-us/1.1.json";
  my $dist_url = "https://hoge/data/page.html";
  my $fkey = 'fd_' . rand;
  return $current->prepare (
    {
      $fkey => {
        type => 'filtered',
        filter => 'strip_tags',
        upstream_file_key => "file:url:$dist_url",
        source => {
          type => 'dcatus',
          id => $ds_id,
          source => {
            type => 'single',
            url => $feed_url,
          },
        },
      },
    },
    {
      "https://hoge/documents/$dskey" => {text => "<html></html>", mime => "text/html"},
      $feed_url => {
        json => {
          dataset => [
            {
              identifier => $ds_id,
              landingPage => "https://hoge/documents/$dskey",
              title => 'Test Dataset',
              distribution => [
                {
                  title => 'Data file',
                  format => 'CSV',
                  mediaType => 'text/csv',
                  downloadURL => $dist_url,
                },
              ],
            },
          ],
        },
      },
      $dist_url => {text => "<html><body><p>DCAT</p><script>x</script></body></html>", mime => "text/html"},
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
        if ($p->stringify =~ /\Q$fkey\E/ || $p->stringify =~ /filtered/) { $j=$x;$jpath=$p; last }
        $j||=$x; $jpath||=$p;
      }
    }
    my $content = '';
    if ($j && $jpath && $j->{items}->{file}->{files}->{data}) {
      $content = $jpath->parent->child($j->{items}->{file}->{files}->{data})->slurp_utf8;
    }
    test {
      ok $j, 'found index';
      unlike $content, qr/<p>/, 'no p';
      like $content, qr/DCAT/, 'has text';
    } $current->c;
  });
} n => 4, name => 'pull filtered dcatus';

Run;


=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
