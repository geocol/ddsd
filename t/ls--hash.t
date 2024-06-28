use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = '3e6ee01f6467e919818d9cb5';
  return $current->prepare (
    undef,
    {
      "https://hoge/dataset/$key" => {
        text => qq{<meta name="generator" content="ckan 1.2.3">},
      },
      "https://hoge/api/action/package_show?id=$key" => {
        text => q{
          {"success": true, "result": {}}
        },
      },
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/dataset/$key"]);
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
      is 0+@{$r->{jsonl}}, 1;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           '9319ede5d2cc93438aae538ffed46623f8d875de03eaf0edbfbc8ac74b08c5d7';
      }
    } $current->c;
    return $current->run ('ls', additional => [$key], stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      like $r->{stdout}, qr{9319ede5d2cc93438aae538ffed46623f8d875de03eaf0edbfbc8ac74b08c5d7};
    } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0, 'unchanged';
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 1;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           '9319ede5d2cc93438aae538ffed46623f8d875de03eaf0edbfbc8ac74b08c5d7';
      }
    } $current->c;
    return $current->prepare (
      undef,
      {
        "https://hoge/api/action/package_show?id=$key" => {
          text => qq{
            {"success": true, "result": {"resources":[
              {"url":"https://hoge/$key/a"}
            ]}}
          },
        },
        "https://hoge/$key/a" => {text => "A"},
      },
    );
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0, 'changed';
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           '04154ea5284641fbf42bbf2d5a118ab4ddc1ebbacb01e3c09e1178d84c37ce42';
      }
    } $current->c;
    return $current->prepare (
      undef,
      {
        "https://hoge/$key/a" => {text => "B", status => 404},
      },
    );
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12, 'error, unchanged';
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           '04154ea5284641fbf42bbf2d5a118ab4ddc1ebbacb01e3c09e1178d84c37ce42';
      }
    } $current->c;
    return $current->run ('unuse', additional => [$key, 'file:index:0']);
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
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           '04154ea5284641fbf42bbf2d5a118ab4ddc1ebbacb01e3c09e1178d84c37ce42';
      }
    } $current->c;
    return $current->prepare (undef, {
      "https://hoge/api/action/package_show?id=$key" => {
        text => q{
          {"success": true, "result": {}}
        },
      },
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0, 'reverted to first';
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 1;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           '9319ede5d2cc93438aae538ffed46623f8d875de03eaf0edbfbc8ac74b08c5d7';
      }
    } $current->c;
  });
} n => 26, name => 'ckanrepo';

Test {
  my $current = shift;
  my $key = '1d7aaf18469e1e5c60185';
  return $current->prepare (
    {
      $key => {type => 'packref', url => "https://hoge/$key/index.json"},
    },
    {
      "https://hoge/$key/index.json" => {
        text => q{
          {"type": "packref", "source": {
            "type": "files",
            "files": {
            }
          }}
        },
      },
    },
  )->then (sub {
    return $current->run ('pull');
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
      is 0+@{$r->{jsonl}}, 1;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{lang}, '';
        is $item->{dir}, 'auto';
        is $item->{writing_mode}, 'horizontal-tb';
        is $item->{rev}, undef;
        is $item->{path}, undef;
        is $item->{file}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{mime}, undef;
        is $item->{url}, "https://hoge/$key/index.json";
      }
    } $current->c;
    return $current->prepare (undef, {
      "https://hoge/$key/index.json" => {
        text => q{
          {"type": "packref", "source": {
            "type": "files",
            "files": {
              "file:r:a": {"url": "a.txt"}
            }
          }}
        },
      },
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12, 'file missing';
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      }
    } $current->c;
    return $current->prepare (undef, {
      "https://hoge/$key/a.txt" => {
        text => q{abc},
      },
    });
  })->then (sub {
    return $current->run ('pull');
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
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           '25ed921b4fd74af727275dc83a02590cfe605e2876dae9ec4b9db6dc33dc183d';
      }
    } $current->c;
    return $current->run ('unuse', additional => [$key, 'file:r:a']);
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
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      }
    } $current->c;
  });
} n => 27, name => 'packrefrepo';

Test {
  my $current = shift;
  my $key = '55356e1d7aaf18469e1e5c601';
  return $current->prepare (
    {
      $key => {type => 'packref', url => "https://hoge/$key/index.json"},
    },
    {
      "https://hoge/$key/index.json" => {
        text => qq{
          {"type": "packref", "source": {
            "type": "ckan",
            "url": "https://hoge/dataset/$key",
            "files": {
              "file:r:a": {"url": "a.json"}
            }
          }}
        },
      },
      "https://hoge/$key/a.json" => {text => "A"},
      "https://hoge/api/action/package_show?id=$key" => {
        text => qq{
          {"success": true, "result": {"resources": [{"url":"https://hoge/$key/b.json"}]}}
        },
      },
      "https://hoge/$key/b.json" => {text => "B"},
    },
  )->then (sub {
    return $current->run ('pull');
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
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           'c12ea051243993a7a5ee10ba3bbcb13dfc01e8836b8f6ccd9a93fc850403d85b';
      }
    } $current->c;
  });
} n => 4, name => 'packrefrepo with ckanrepo';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
