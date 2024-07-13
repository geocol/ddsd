use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

for my $in_name (
  "nul",
  "NUL",
  "CON",
  "CON.TXT",
  "desktop.ini",
  "Thumbs.db",
  "autorun.inf",
  "LPT\xB2",
  "COM0",
  "CON.nul",
  "NUL.tar.gz",
  "CVS",
  "META-INF",

  'hoge fuga.txt',
  'hoge/fu$ga.txt',
  'hoge fuga.TXT',
  "foo.bar.\x{4000}",
  "fo~o.bar.\x{4000}.txt",
  "foo.",
  ".foo",
  #"hoge\x00foo",
  "hoge.lnk",
  "foo.hoge.lnk",
  "foo.hoge.pif",
  "foo.hoge.scf",
  "foo.hoge.url",
  "foo.hoge.LNK",
  "hoge\x{035C}\x{035C}",
  "hoge\x{035D}\x{035D}",
  "hoge\x{035E}\x{035E}",
  "hoge\x{035F}\x{035F}",
  "hoge\x{0360}\x{0360}",
  "hoge\x{0361}\x{0361}",
  "hoge\x{0362}\x{0362}",
  "hoge\x{1DFC}\x{1DFC}",
  "\x{035C}\x{0360}a",
  "a\x{0362}.abc",
  "x\x{FFFF}y\x{E000}c",
  "ab c\x{2028}\x{2066}",
  "f\x{FE00}oo\x{034F}\x{200D}b\x{0600}",

) {
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (undef, {
      "https://hoge/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://hoge/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
    })->then (sub {
      return $current->run ('add', additional => ["https://hoge/dataset/$key", "--name", $in_name]);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => "config/ddsd/packages.json", is_none => 1},
        {path => "local/data/$key", is_none => 1},
      ]);
    });
  } n => 3, name => ['bad name 1', $in_name];
}

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
