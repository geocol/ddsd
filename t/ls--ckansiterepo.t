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
      "https://hoge/$key/" => {
        text => qq{<meta name="generator" content="ckan 1.2.3"><body data-site-root="https://hoge/$key/" xxx="">},
        mime => 'text/html',
      },
      "https://hoge/$key/about" => {
        text => qq{xyz},
        mime => 'text/css',
      },
      "https://hoge/$key/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key/", '--name', 'hoge']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => ["hoge", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is $item->{package_item}->{mime}, undef;
        is $item->{rev}, undef;
        is $item->{path}, undef;
        is $item->{parsed}, undef;
        is $item->{source}, undef;
        is $item->{ckan_package}, undef;
        is $item->{ckan_resource}, undef;
        is $item->{file}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, 'file:index.html';
        is $item->{file}->{directory}, 'files';
        is $item->{file}->{name}, 'index.html';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{mime}, 'text/html';
        like $item->{path}, qr{^/.+/local/data/hoge/files/index.html$}; # XXX platform
        ok $item->{rev}->{http_date};
        ok $item->{rev}->{length};
        ok $item->{rev}->{sha256};
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{url}, "https://hoge/$key/";
        is $item->{rev}->{original_url}, $item->{rev}->{url};
        is $item->{parsed}, undef;
        is $item->{source}, undef;
        is $item->{ckan_package}, undef;
        is $item->{ckan_resource}, undef;
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'file';
        is $item->{key}, 'file:about.html';
        is $item->{file}->{directory}, 'files';
        is $item->{file}->{name}, 'about.html';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{mime}, 'text/css';
        like $item->{path}, qr{^/.+/local/data/hoge/files/about.html$}; # XXX platform
        ok $item->{rev}->{http_date};
        ok $item->{rev}->{length};
        ok $item->{rev}->{sha256};
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{url}, "https://hoge/$key/about";
        is $item->{rev}->{original_url}, $item->{rev}->{url};
        is $item->{parsed}, undef;
        is $item->{source}, undef;
        is $item->{ckan_package}, undef;
        is $item->{ckan_resource}, undef;
      }
      {
        my $item = $r->{jsonl}->[3];
        is $item->{type}, 'file';
        is $item->{key}, 'file:package_list.json';
        is $item->{file}->{directory}, 'files';
        is $item->{file}->{name}, 'package_list.json';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{mime}, 'application/json';
        like $item->{path}, qr{^/.+/local/data/hoge/files/package_list.json$}; # XXX platform
        ok $item->{rev}->{http_date};
        ok $item->{rev}->{length};
        ok $item->{rev}->{sha256};
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{url}, "https://hoge/$key/api/action/package_list";
        is $item->{rev}->{original_url}, $item->{rev}->{url};
        is $item->{parsed}, undef;
        is $item->{source}, undef;
        is $item->{ckan_package}, undef;
        is $item->{ckan_resource}, undef;
      }
    } $current->c;
  });
} n => 68, name => 'ls --jsonl';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckansite',
        url => "https://hoge/$key/",
      },
    },
    {
      "https://hoge/$key/about" => {
        mime => 'text/html',
        text => q{<html lang="en_GB">
                  <link rel="stylesheet" type="text/css" href="/foo/bar/main-rtl.min.css" />},
      },
      "https://hoge/$key/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{lang}, 'en-gb';
        is $item->{package_item}->{dir}, 'rtl';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
      }
    } $current->c;
  });
} n => 9, name => 'lang 1';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckansite',
        url => "https://hoge/$key/",
      },
    },
    {
      "https://hoge/$key/about" => {
        mime => 'text/html',
        text => q{<html lang="es">
                  <link rel="stylesheet" type="text/css" href="/foo/bar/main.min.css" />},
      },
      "https://hoge/$key/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{lang}, 'es';
        is $item->{package_item}->{dir}, 'ltr';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
      }
    } $current->c;
  });
} n => 9, name => 'lang 2';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    {
      foo => {
        type => 'ckansite',
        url => "https://hoge/$key/",
      },
    },
    {
      "https://hoge/$key/" => {
        redirect => q<foo>,
      },
      "https://hoge/$key/foo" => {
        text => q{
          <title>
題名。
</title>
          <a href="/policy">ご利用について</a>
        },
      },
      "https://hoge/$key/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{title}, '題名。';
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{parsed}->{site_terms_url}, "https://hoge/policy";
      }
    } $current->c;
  });
} n => 7, name => 'legal 1';

Test {
  my $current = shift;
  my $key = rand;
  use utf8;
  return $current->prepare (
    {
      foo => {
        type => 'ckansite',
        url => "https://hoge/$key/",
      },
    },
    {
      "https://hoge/$key/" => {
        redirect => q<foo>,
      },
      "https://hoge/$key/foo" => {
        text => q{
          <title>
題名。
</title>
          <a href="terms">利用規約</a>
        },
      },
      "https://hoge/$key/api/action/package_list" => {
        json => {
          success => \1,
          result => ["abc", "def"],
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{title}, '題名。';
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{parsed}->{site_terms_url}, "https://hoge/$key/terms";
      }
    } $current->c;
  });
} n => 7, name => 'legal 2';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckansite',
        url => "https://hoge/$key/",
      },
    },
    {
      "https://hoge/$key/" => {
        redirect => q<foo>,
      },
      "https://hoge/$key/foo" => {
        text => q{ abc },
      },
      "https://hoge/$key/api/action/package_list" => {
        text => q{ {"success": true, "result": []} },
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 4;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{snapshot_hash}, '2a47d22ddccf1598f545df46c845e43bcb04de7ffc8a1b2cdc4edf25671ebde1';
      }
    } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      {
        my $item = $r->{jsonl}->[0];
        is $item->{key}, 'package';
        is $item->{package_item}->{snapshot_hash}, '2a47d22ddccf1598f545df46c845e43bcb04de7ffc8a1b2cdc4edf25671ebde1';
      }
    } $current->c, name => 'again';
    return $current->prepare (undef, {
      "https://hoge/$key/api/action/package_list" => {
        text => q{ {"success": true, "result": []}  },
      },
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      {
        my $item = $r->{jsonl}->[0];
        is $item->{key}, 'package';
        is $item->{package_item}->{snapshot_hash}, '0b639a37f4563c06dcebfde31bda42a7882500cd0710ba6b2d12946d44377ff4';
      }
    } $current->c, name => 'changed';
    return $current->prepare (undef, {
      "https://hoge/$key/" => {
        text => "abc",
      },
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 2;
    } $current->c;
    return $current->run ('ls', additional => ["foo", '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      {
        my $item = $r->{jsonl}->[0];
        is $item->{key}, 'package';
        is $item->{package_item}->{snapshot_hash}, '5feda9ccfa4807962c1daee7975d5d9075c1625e2a46b06c53fb546508c1ef54';
      }
    } $current->c, name => 'changed 2';
  });
} n => 15, name => 'snapshot_hash 1';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
