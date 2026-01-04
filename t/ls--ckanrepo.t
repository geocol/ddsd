use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/dataset/package-name-$key" => {
        text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/" xxx="">},
      },
      "https://hoge/dataset/activity/package-name-$key" => {text => " "},
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
          ],
          extras => [{}],
        }},
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/dataset/package-name-$key"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["package-name-$key", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{title}, '';
        ok $item->{package_item}->{legal};
        is 0+@{$item->{package_item}->{legal}}, 0;
        ok $item->{package_item}->{snapshot_hash};
        is $item->{package_item}->{mime}, undef;
        is $item->{package_item}->{page_url}, "https://hoge/dataset/package-name-$key";
        is $item->{package_item}->{ckan_api_url}, "https://hoge/api/action/package_show?id=package-name-$key";
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is $item->{rev}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:ckan.json';
        is $item->{file}, undef;
        like $item->{path}, qr{/local/data/package-name-$key/package/package.ckan.json$};
        is $item->{package_item}->{title}, '';
        ok $item->{package_item}->{file_time};
        is $item->{package_item}->{mime}, 'application/json';
        ok $item->{rev}->{timestamp};
        ok $item->{rev}->{http_date};
        ok $item->{rev}->{length};
        is $item->{rev}->{url}, "https://hoge/api/action/package_show?id=package-name-$key";
        is $item->{rev}->{original_url}, "https://hoge/api/action/package_show?id=package-name-$key";
        ok $item->{rev}->{sha256};
        ok ! $item->{rev}->{insecure};
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'meta';
        is $item->{key}, 'meta:activity.html';
        is $item->{file}, undef;
        like $item->{path}, qr{/local/data/package-name-$key/package/activity.html$};
        is $item->{package_item}->{title}, '';
        ok $item->{package_item}->{file_time};
        is $item->{package_item}->{mime}, 'text/html;charset=utf-8';
        ok $item->{rev}->{timestamp};
        ok $item->{rev}->{http_date};
        ok $item->{rev}->{length};
        is $item->{rev}->{url}, "https://hoge/dataset/activity/package-name-$key";
        is $item->{rev}->{original_url}, "https://hoge/dataset/activity/package-name-$key";
        ok $item->{rev}->{sha256};
        ok ! $item->{rev}->{insecure};
      }
    } $current->c;
  });
} n => 44, name => 'lang not known';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/dataset/package-name-$key" => {
        text => qq{<html lang="ja_FR"><link rel="stylesheet" type="text/css" href="/foo/bar/main-rtl.min.css" /><meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/" xxx="">},
      },
      "https://hoge/dataset/activity/package-name-$key" => {
        text => qq{<html lang="ja_FR"><link rel="stylesheet" type="text/css" href="/foo/bar/main-rtl.min.css" /><meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/" xxx="">},
      },
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
          ],
          extras => 1,
        }},
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/dataset/package-name-$key"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["package-name-$key", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{lang}, 'ja-fr';
        is $item->{package_item}->{dir}, 'rtl';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
      }
    } $current->c;
  });
} n => 6, name => 'lang from page';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/dataset/package-name-$key" => {
        text => qq{<html lang="ja_FR"><link rel="stylesheet" type="text/css" href="/foo/bar/main.min.css" /><meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/" xxx="">},
      },
      "https://hoge/dataset/activity/package-name-$key" => {
        text => qq{<html lang="ja_FR"><link rel="stylesheet" type="text/css" href="/foo/bar/main.min.css" /><meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/" xxx="">},
      },
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
          ],
          extras => [
            {key => 'language', value => 'Japanese'},
          ],
        }},
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/dataset/package-name-$key"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["package-name-$key", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{lang}, 'ja';
        is $item->{package_item}->{dir}, 'ltr';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
      }
    } $current->c;
  });
} n => 6, name => 'lang from package, 1';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    undef,
    {
      "https://hoge/dataset/package-name-$key" => {
        text => qq{<html lang="ja_FR"><link rel="stylesheet" type="text/css" href="/foo/bar/main.min.css" /><meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/" xxx="">},
      },
      "https://hoge/dataset/activity/package-name-$key" => {
        text => qq{<html lang="ja_FR"><link rel="stylesheet" type="text/css" href="/foo/bar/main.min.css" /><meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/" xxx="">},
      },
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
          ],
          extras => [
            {key => '言語', value => 'ja'},
          ],
        }},
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/dataset/package-name-$key"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["package-name-$key", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{lang}, 'ja';
        is $item->{package_item}->{dir}, 'ltr';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
      }
    } $current->c;
  });
} n => 6, name => 'lang from package, 2';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/dataset/package-name-$key" => {
        text => qq{<html lang="ja_FR"><link rel="stylesheet" type="text/css" href="/foo/bar/main-rtl.min.css" /><meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/" xxx="">},
      },
      "https://hoge/dataset/activity/package-name-$key" => {
        text => qq{abc},
      },
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        text => q{ {"success":true, "result": {}} },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/dataset/package-name-$key"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["package-name-$key", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
            '30bb85ee73f6254ecc260a00cbdc81d23289bf806736634f53708aed9e36d646';
      }
    } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["package-name-$key", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
            '30bb85ee73f6254ecc260a00cbdc81d23289bf806736634f53708aed9e36d646';
      }
    } $current->c, name => 'unchanged';
    return $current->prepare (undef, {
      "https://hoge/dataset/activity/package-name-$key" => {
        text => rand,
      },
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["package-name-$key", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
            '30bb85ee73f6254ecc260a00cbdc81d23289bf806736634f53708aed9e36d646';
      }
    } $current->c, name => 'unchanged again';
    return $current->prepare (undef, {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        text => q{ {"success":true, "result": {}}  },
      },
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["package-name-$key", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        isnt $item->{package_item}->{snapshot_hash}, '4f719d099bbcdded7e4393c9c43758ae5e98d2aecc5cf6ee08428f7f1baac96a';
      }
    } $current->c, name => 'changed';
  });
} n => 13, name => 'snapshot_hash 1';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    undef,
    {
      "https://hoge/dataset/$key" => {
        text => qq{<html lang="ja_FR"><link rel="stylesheet" type="text/css" href="/foo/bar/main-rtl.min.css" /><meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/" xxx="">},
      },
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [
            {url => "https://hoge/$key.1/"},
            {url => "https://hoge/$key.2/"},
            {url => "https://hoge/$key.3/", name => "abc.html", mimetype => "image/png"},
            {url => "https://hoge/$key.4/", name => "abc.html"},
            {url => "https://hoge/$key.5/", name => "abc.html", mimetype => "text/html"},
            {url => "https://hoge/$key.6/", name => "abc.html", mimetype => "text/html"},
          ],
        }},
      },
      "https://hoge/$key.1/" => {text => 1},
      "https://hoge/$key.2/" => {text => 1, mime_filename => "abc.txt"},
      "https://hoge/$key.3/" => {text => 1},
      "https://hoge/$key.4/" => {text => 1, mime => "text/html"},
      "https://hoge/$key.5/" => {text => 1},
      "https://hoge/$key.6/" => {text => 1, mime_filename => "foo.html"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/dataset/$key", '--min']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3+6;
      for (3..4) {
        my $item = $r->{jsonl}->[$_];
        is $item->{package_item}->{file_name}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{rev}, undef;
      }
      {
        my $item = $r->{jsonl}->[5];
        is $item->{package_item}->{file_name}, undef;
        is $item->{package_item}->{title}, 'abc.html';
        is $item->{rev}, undef;
      }
      for (6..8) {
        my $item = $r->{jsonl}->[$_];
        is $item->{package_item}->{file_name}, 'abc.html';
        is $item->{package_item}->{title}, 'abc.html';
        is $item->{rev}, undef;
      }
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3+6;
      for (3..4) {
        my $item = $r->{jsonl}->[$_];
        is $item->{package_item}->{file_name}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{rev}, undef;
      }
      {
        my $item = $r->{jsonl}->[5];
        is $item->{package_item}->{file_name}, undef;
        is $item->{package_item}->{title}, 'abc.html';
        is $item->{rev}, undef;
      }
      for (6..8) {
        my $item = $r->{jsonl}->[$_];
        is $item->{package_item}->{file_name}, 'abc.html';
        is $item->{package_item}->{title}, 'abc.html';
        is $item->{rev}, undef;
      }
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3+6;
      {
        my $item = $r->{jsonl}->[3];
        is $item->{package_item}->{file_name}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{rev}->{mime_filename}, undef;
      }
      {
        my $item = $r->{jsonl}->[4];
        is $item->{package_item}->{file_name}, 'abc.txt';
        is $item->{package_item}->{title}, '';
        is $item->{rev}->{mime_filename}, "abc.txt";
      }
      {
        my $item = $r->{jsonl}->[5];
        is $item->{package_item}->{file_name}, undef;
        is $item->{package_item}->{title}, 'abc.html';
        is $item->{rev}->{mime_filename}, undef;
      }
      for (6, 7) {
        my $item = $r->{jsonl}->[$_];
        is $item->{package_item}->{file_name}, 'abc.html';
        is $item->{package_item}->{title}, 'abc.html';
        is $item->{rev}->{mime_filename}, undef;
      }
      {
        my $item = $r->{jsonl}->[8];
        is $item->{package_item}->{file_name}, 'foo.html';
        is $item->{package_item}->{title}, 'abc.html';
        is $item->{rev}->{mime_filename}, 'foo.html';
      }
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3+6;
      {
        my $item = $r->{jsonl}->[3];
        is $item->{package_item}->{file_name}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{rev}->{mime_filename}, undef;
      }
      {
        my $item = $r->{jsonl}->[4];
        is $item->{package_item}->{file_name}, 'abc.txt';
        is $item->{package_item}->{title}, '';
        is $item->{rev}->{mime_filename}, "abc.txt";
      }
      {
        my $item = $r->{jsonl}->[5];
        is $item->{package_item}->{file_name}, undef, 5;
        is $item->{package_item}->{title}, 'abc.html';
        is $item->{rev}->{mime_filename}, undef;
      }
      for (6..7) {
        my $item = $r->{jsonl}->[$_];
        is $item->{package_item}->{file_name}, 'abc.html';
        is $item->{package_item}->{title}, 'abc.html';
        is $item->{rev}->{mime_filename}, undef;
      }
      {
        my $item = $r->{jsonl}->[8];
        is $item->{package_item}->{file_name}, 'foo.html', 8;
        is $item->{package_item}->{title}, 'abc.html';
        is $item->{rev}->{mime_filename}, 'foo.html';
      }
    } $current->c;
  });
} n => 82, name => 'file names';

Run;

=head1 LICENSE

Copyright 2024-2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
