use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "https://hoge/" . $key . "/r3"},
              {id => "r4", url => "https://hoge/" . $key . "/r4"},
              {id => "r5", url => "https://hoge/" . $key . "/r5"},
              {id => "r6", url => "https://hoge/" . $key . "/r6"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {
        text => "r1",
        headers => {'content-disposition' => 'inline; filename=foo.txt'},
      },
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {
        text => "r3",
        headers => {'content-disposition' => 'attachment; filename=r3.txt'},
      },
      "https://hoge/" . $key . "/r4" => {
        text => "r4",
        headers => {'content-disposition' => 'attachment;FILENAME=r4.txt'},
      },
      "https://hoge/" . $key . "/r5" => {
        text => "r5",
        headers => {'content-disposition' => 'xyz;notfilename=abc;filename=r5.txt;abc'},
      },
      "https://hoge/" . $key . "/r6" => {
        text => "r6",
        headers => {'content-disposition' => 'attachment;filename="r6.txt"'},
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         {
           my $item = $json->{items}->{'file:id:r1'};
           is $item->{rev}->{mime_filename}, 'foo.txt';
         }
         {
           my $item = $json->{items}->{'file:id:r2'};
           is $item->{rev}->{mime_filename}, undef;
         }
       }},
      {path => 'local/data/foo/files/r1', is_none => 1},
      {path => 'local/data/foo/files/foo.txt', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3.txt', text => "r3"},
      {path => 'local/data/foo/files/r4.txt', text => "r4"},
      {path => 'local/data/foo/files/r5.txt', text => "r5"},
      {path => 'local/data/foo/files/r6.txt', text => "r6"},
    ]);
  });
} n => 10, name => 'filename specified';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "https://hoge/" . $key . "/r3"},
              {id => "r4", url => "https://hoge/" . $key . "/r4"},
              {id => "r5", url => "https://hoge/" . $key . "/r5"},
              {id => "r6", url => "https://hoge/" . $key . "/r6"},
              {id => "r7", url => "https://hoge/" . $key . "/r7"},
              {id => "r8", url => "https://hoge/" . $key . "/r8"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {
        text => "r1",
        headers => {'content-disposition' => 'inline; filename=foo.txt'},
      },
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {
        text => "r3",
        headers => {'content-disposition' => 'attachment; filename='},
      },
      "https://hoge/" . $key . "/r4" => {
        text => "r4",
        headers => {'content-disposition' => 'attachment; filename=ho\\ge'},
      },
      "https://hoge/" . $key . "/r5" => {
        text => "r5",
        headers => {'content-disposition' => 'attachment; filename=fo"fo'},
      },
      "https://hoge/" . $key . "/r6" => {
        text => "r6",
        headers => {'content-disposition' => 'attachment;filename=a/b/c'},
      },
      "https://hoge/" . $key . "/r7" => {
        text => "r7",
        headers => {'content-disposition' => 'attachment;filename=;'},
      },
      "https://hoge/" . $key . "/r8" => {
        text => "r8",
        headers => {'content-disposition' => 'attachment;filename=""'},
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         {
           my $item = $json->{items}->{'file:id:r1'};
           is $item->{rev}->{mime_filename}, 'foo.txt';
         }
         {
           my $item = $json->{items}->{'file:id:r2'};
           is $item->{rev}->{mime_filename}, undef;
         }
         {
           my $item = $json->{items}->{'file:id:r4'};
           is $item->{rev}->{mime_filename}, 'ho';
         }
         {
           my $item = $json->{items}->{'file:id:r5'};
           is $item->{rev}->{mime_filename}, 'fo';
         }
         {
           my $item = $json->{items}->{'file:id:r6'};
           is $item->{rev}->{mime_filename}, 'a/b/c';
         }
       }},
      {path => 'local/data/foo/files/r1', is_none => 1},
      {path => 'local/data/foo/files/foo.txt', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', text => "r3"},
      {path => 'local/data/foo/files/r4', is_none => 1},
      {path => 'local/data/foo/files/ho', text => "r4"},
      {path => 'local/data/foo/files/r5', is_none => 1},
      {path => 'local/data/foo/files/fo', text => "r5"},
      {path => 'local/data/foo/files/r6', is_none => 1},
      {path => 'local/data/foo/files/c', text => "r6"},
      {path => 'local/data/foo/files/r7', text => "r7"},
      {path => 'local/data/foo/files/r8', text => "r8"},
    ]);
  });
} n => 15, name => 'bad filename specified';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1",
               name => "abc\x{4000}.zip"},
              {id => "r2", url => "https://hoge/" . $key . "/r2",
               name => "abc\x{4000}.ZIP"},
              {id => "r3", url => "https://hoge/" . $key . "/r3",
               name => "abc\x{4000}.zip"},
              {id => "r4", url => "https://hoge/" . $key . "/r4",
               name => "abc/def.zip"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {
        text => "r1",
        headers => {'content-disposition' => 'inline; filename=foo.txt'},
        mime => 'application/zip',
      },
      "https://hoge/" . $key . "/r2" => {
        text => "r2",
        mime => 'application/zip',
      },
      "https://hoge/" . $key . "/r3" => {
        text => "r3",
        mime => 'text/css',
      },
      "https://hoge/" . $key . "/r4" => {
        text => "r4",
        mime => 'application/zip',
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/files/foo.txt', text => "r1"},
      {path => "local/data/foo/files/abc\x{4000}.ZIP", text => "r2"},
      {path => 'local/data/foo/files/r3', text => "r3"},
      {path => 'local/data/foo/files/def.zip', text => "r4"},
    ]);
  });
} n => 6, name => 'filename in ckan title';

for (
  ['hoge fuga.txt' => 'hoge_fuga.txt'],
  ['hoge/fu$ga.txt' => 'fu_ga.txt'],
  ['hoge fuga.TXT' => 'hoge_fuga.TXT'],
) {
  my ($in_name, $out_name) = @$_;
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare ({
      $key => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    }, {
      "https://hoge/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://hoge/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1",
               name => $in_name},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1", mime => 'text/plain'},
    })->then (sub {
      return $current->run ('pull');
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => "config/ddsd/packages.json", json => sub {
           my $json = shift;
           is $json->{$key}->{files}->{"file:id:r1"}->{name}, undef;
         }},
        {path => "local/data/$key/files/$in_name", is_none => 1},
        {path => "local/data/$key/files/$out_name", is_none => 1},
      ]);
    })->then (sub {
      return $current->run ('use', additional => [$key, 'file:id:r1']);
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 0;
      } $current->c;
      return $current->check_files ([
        {path => "config/ddsd/packages.json", json => sub {
           my $json = shift;
           is $json->{$key}->{files}->{"file:id:r1"}->{name}, $out_name;
         }},
        {path => "local/data/$key/files/$in_name", is_none => 1},
        {path => "local/data/$key/files/$out_name", text => "r1"},
      ]);
    });
  } n => 7, name => ['replaced name', $in_name];
}

for (
  ['hoge fuga.txt' => 'hoge_fuga.txt'],
  ['hoge/fu$ga.txt' => 'hoge_fu_ga.txt'],
  ['hoge fuga.TXT' => 'hoge_fuga.TXT'],
  ["foo.bar.\x{4000}" => "foo_bar_\x{4000}"],
  ["fo~o.bar.\x{4000}.txt" => "fo_o.bar.\x{4000}.txt"],
  ["foo." => "foo_"],
  [".foo" => "_foo"],
  ["hoge\x00foo" => "hoge_foo"],
  ["hoge.lnk" => "hoge_lnk"],
  ["foo.hoge.lnk" => "foo_hoge_lnk"],
  ["foo.hoge.pif" => "foo_hoge_pif"],
  ["foo.hoge.scf" => "foo_hoge_scf"],
  ["foo.hoge.url" => "foo_hoge_url"],
  ["foo.hoge.LNK" => "foo_hoge_LNK"],
  ["hoge\x{035C}\x{035C}" => "hoge\x{035C}_"],
  ["hoge\x{035D}\x{035D}" => "hoge\x{035D}_"],
  ["hoge\x{035E}\x{035E}" => "hoge\x{035E}_"],
  ["hoge\x{035F}\x{035F}" => "hoge\x{035F}_"],
  ["hoge\x{0360}\x{0360}" => "hoge\x{0360}_"],
  ["hoge\x{0361}\x{0361}" => "hoge\x{0361}_"],
  ["hoge\x{0362}\x{0362}" => "hoge\x{0362}_"],
  ["hoge\x{1DFC}\x{1DFC}" => "hoge\x{1DFC}_"],
  ["\x{035C}\x{0360}a" => "_\x{0360}a"],
  ["a\x{0362}.abc" => "a_.abc"],
  ["x\x{FFFF}y\x{E000}c" => "x_y_c"],
  ["ab c\x{2028}\x{2066}" => "ab_c__"],
  ["f\x{FE00}oo\x{034F}\x{200D}b\x{0600}" => "f\x{FE00}oo__b\x{0600}"],
) {
  my ($in_name, $out_name) = @$_;
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare ({
      $key => {
        type => 'packref',
        url => "https://hoge/$key.json",
      },
    }, {
      "https://hoge/$key.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/dataset/$key",
          },
        },
      },
      "https://hoge/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://hoge/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/" . percent_encode_c $in_name},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/" . (percent_encode_c $in_name) => {text => "r1", mime => 'text/plain'},
    })->then (sub {
      return $current->run ('pull');
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => "config/ddsd/packages.json", json => sub {
           my $json = shift;
           is $json->{$key}->{files}->{"file:id:r1"}->{name}, undef;
         }},
        {path => "local/data/$key/files/$in_name", is_none => 1},
        {path => "local/data/$key/files/$out_name", is_none => 1},
      ]);
    })->then (sub {
      return $current->run ('use', additional => [$key, 'file:id:r1']);
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 0;
      } $current->c;
      return $current->check_files ([
        {path => "config/ddsd/packages.json", json => sub {
           my $json = shift;
           is $json->{$key}->{files}->{"file:id:r1"}->{name}, $out_name;
         }},
        {path => "local/data/$key/files/$in_name", is_none => 1},
        {path => "local/data/$key/files/$out_name", text => "r1"},
      ]);
    });
  } n => 7, name => ['replaced name 2', $in_name];
}

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
) {
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare ({
      $key => {
        type => 'packref',
        url => "https://hoge/$key.json",
      },
    }, {
      "https://hoge/$key.json" => {
        json => {
          type => 'packref',
          source => {
            type => 'ckan',
            url => "https://hoge/dataset/$key",
          },
        },
      },
      "https://hoge/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://hoge/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/" . percent_encode_c $in_name},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/" . (percent_encode_c $in_name) => {text => "r1", mime => 'text/plain'},
    })->then (sub {
      return $current->run ('pull');
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => "config/ddsd/packages.json", json => sub {
           my $json = shift;
           is $json->{$key}->{files}->{"file:id:r1"}->{name}, undef;
         }},
        {path => "local/data/$key/files/$in_name", is_none => 1},
        {path => "local/data/$key/files/1", is_none => 1},
        {path => "local/data/$key/files/r1", is_none => 1},
      ]);
    })->then (sub {
      return $current->run ('use', additional => [$key, 'file:id:r1']);
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 0;
      } $current->c;
      return $current->check_files ([
        {path => "config/ddsd/packages.json", json => sub {
           my $json = shift;
           is $json->{$key}->{files}->{"file:id:r1"}->{name}, "1";
         }},
        {path => "local/data/$key/files/$in_name", is_none => 1},
        {path => "local/data/$key/files/1", text => "r1"},
      ]);
    });
  } n => 7, name => ['bad name 1', $in_name];
}

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
  "hoge\x00foo",
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
    return $current->prepare ({
      $in_name => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    }, {
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
      return $current->run ('pull');
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => "local/data/$in_name", is_none => 1},
      ]);
    });
  } n => 2, name => ['bad name 2', $in_name];
}

for (
  ["abc.txt", "ABC.TXT"],
  #["abc\x{0130}.txt", "abci.txt"],
  ["abc\x{0131}.txt", "abcI.txt"],
  #["\x{0131}", "\x{0130}"],
  ["\x{00D9}.png", "U\x{0300}.png"],
  ["\x{00D9}.jpg", "\x{00F9}.jpg"],
  ["\x{304C}\x{304E}.png", "\x{304B}\x{3099}\x{304D}\x{3099}.png"],
  ["\x{212A}\x{03a9}", "k\x{2126}"],
  ["\x{212A}\x{03c9}\x{00E5}", "k\x{2126}\x{212b}"],
  ["\x{01F3}", "\x{01f2}"],
  ["\x{01F3}", "\x{01f1}"],
  ["\x{01F1}", "\x{01f2}"],
  #["\x{01F3}", "dz"],
  #["\x{00df}", "ss"],
  ["\x{00df}", "\x{1e9e}"],
  #["ss", "\x{1e9e}"],
  ["\x{0345}", "\x{03b9}"],
  ["\x{0345}", "\x{0399}"],
  ["\x{03a3}", "\x{03c3}"],
  ["\x{03a3}", "\x{03c2}"],
) {
  my ($name1, $name2) = @$_;
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare ({
      $key => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    }, {
      "https://hoge/dataset/" . $key => {
        text => q{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://hoge/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/" . (percent_encode_c $name1)},
              {id => "r2", url => "https://hoge/" . $key . "/" . (percent_encode_c $name2)},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/" . (percent_encode_c $name1) => {text => "r1"},
      "https://hoge/" . $key . "/" . (percent_encode_c $name2) => {text => "r2"},
    })->then (sub {
      return $current->run ('pull');
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => "local/data/files/$name1", is_none => 1},
        {path => "local/data/files/$name2", is_none => 1},
      ]);
    });
  } n => 2, name => ['dup name', $name1, $name2];
}

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare ({
    hoge => {
      type => 'ckan',
      url => "https://hoge/dataset/$key.1",
    },
    HOGE => {
      type => 'ckan',
      url => "https://hoge/dataset/$key.2",
    },
  }, {
    "https://hoge/dataset/$key.1" => {
      text => q{<meta name="generator" content="ckan 1.2.3">},
    },
    "https://hoge/dataset/$key.2" => {
      text => q{<meta name="generator" content="ckan 1.2.3">},
    },
    "https://hoge/api/action/package_show?id=$key.1" => {
      json => {
        success => \1,
        result => {
          resources => [
            {id => "r1", url => "https://hoge/" . $key . "/r1"},
          ],
        },
      },
    },
    "https://hoge/api/action/package_show?id=$key.2" => {
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
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my ($json, $path) = @_;
         my @c = $path->parent->parent->parent->child ('local/data/')->children;
         is @c, 1;
       }},
    ]);
  });
} n => 3, name => "duplicate data package keys 1";

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare ({
    "hoge\x{03a3}" => {
      type => 'ckan',
      url => "https://hoge/dataset/$key.1",
    },
    "hoge\x{03c3}" => {
      type => 'ckan',
      url => "https://hoge/dataset/$key.2",
    },
  }, {
    "https://hoge/dataset/$key.1" => {
      text => q{<meta name="generator" content="ckan 1.2.3">},
    },
    "https://hoge/dataset/$key.2" => {
      text => q{<meta name="generator" content="ckan 1.2.3">},
    },
    "https://hoge/api/action/package_show?id=$key.1" => {
      json => {
        success => \1,
        result => {
          resources => [
            {id => "r1", url => "https://hoge/" . $key . "/r1"},
          ],
        },
      },
    },
    "https://hoge/api/action/package_show?id=$key.2" => {
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
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my ($json, $path) = @_;
         my @c = $path->parent->parent->parent->child ('local/data/')->children;
         is @c, 1;
       }},
    ]);
  });
} n => 3, name => "duplicate data package keys 2";

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
