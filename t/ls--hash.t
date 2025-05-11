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
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           'd9a99d0df763959cc1f09f963cf319f858666cd439212eab4f5728c34684a7e1';
      }
    } $current->c;
    return $current->run ('ls', additional => [$key], stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      like $r->{stdout}, qr{d9a99d0df763959cc1f09f963cf319f858666cd439212eab4f5728c34684a7e1};
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
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           'd9a99d0df763959cc1f09f963cf319f858666cd439212eab4f5728c34684a7e1';
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
      is 0+@{$r->{jsonl}}, 4;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           'd5fbe691954fa5dc2e43600990283268dcb51f7632f69f90f3e9ce896727a044';
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
      is 0+@{$r->{jsonl}}, 4;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           'd5fbe691954fa5dc2e43600990283268dcb51f7632f69f90f3e9ce896727a044';
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
      is 0+@{$r->{jsonl}}, 4;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           '79de22405251b49ae854f488220069b8d68ae0c081ded8d6c23472c4e41d9230';
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
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           'd9a99d0df763959cc1f09f963cf319f858666cd439212eab4f5728c34684a7e1';
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
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           'abbc47bda7962ec96bfab7cbebd9730368f1e637216af3a15c9db560ff74f597';
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{rev}, undef;
        is $item->{path}, undef;
        is $item->{file}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{mime}, undef;
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
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           '6362ecb0c9fc59ccc70b9f30a5d195cfaacbd087d633947e01d6444ebf6f2f27';
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
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           '231ee48135777b3246e5f1e3fc2a6836689168eadc740fb992a79815889f93e5';
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
      is 0+@{$r->{jsonl}}, 3;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           '6362ecb0c9fc59ccc70b9f30a5d195cfaacbd087d633947e01d6444ebf6f2f27';
      }
    } $current->c;
  });
} n => 23, name => 'packrefrepo';

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
      is 0+@{$r->{jsonl}}, 4;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{package_item}->{snapshot_hash},
           'c9ca9c78fc7c9f6a90caadb4a5d32151cc195c214bcfed5d6cc31331f35bc95e';
      }
    } $current->c;
  });
} n => 4, name => 'packrefrepo with ckanrepo';

Run;

=head1 LICENSE

Copyright 2024-2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
