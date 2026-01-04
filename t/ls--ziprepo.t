use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc.dat" => {text => "abc", timestamp => 1766901800},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
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
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{file}, undef;
        is $item->{path}, undef, "not exposed in local/data";
        is $item->{package_item}->{mime}, 'application/zip';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, undef;
        is $item->{package_item}->{org}, undef;
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is $item->{package_item}->{file_time}, 1766901872;
        is $item->{package_item}->{legal}, undef;
        ok $item->{package_item}->{snapshot_hash};
        is $item->{package_item}->{file_name}, undef;
        is $item->{archive_meta}, undef;
        is $item->{rev}->{url}, "https://hoge/$key.zip";
        is $item->{rev}->{original_url}, "https://hoge/$key.zip";
        ok $item->{rev}->{length};
        ok $item->{rev}->{http_date};
        is $item->{rev}->{http_content_type}, 'application/zip';
        is $item->{rev}->{http_last_modified}, 1766901872;
        ok $item->{rev}->{sha256};
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, 'file:abc.dat';
        is $item->{file}, undef;
        is $item->{path}, undef;
        is $item->{package_item}->{mime}, 'application/octet-stream';
        is $item->{package_item}->{title}, "";
        is $item->{package_item}->{file_time}, 1766901800;
        is $item->{package_item}->{legal}, undef;
        is $item->{package_item}->{file_name}, "abc.dat";
        is $item->{rev}, undef;
        is $item->{archive_item}, undef;
      }
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{file}, undef;
        is $item->{path}, undef, "not exposed in local/data";
        is $item->{package_item}->{mime}, 'application/zip';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, undef;
        is $item->{package_item}->{org}, undef;
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is $item->{package_item}->{file_time}, 1766901872;
        is $item->{package_item}->{legal}, undef;
        ok $item->{package_item}->{snapshot_hash};
        is $item->{archive_meta}->{comment}, '';
        is $item->{archive_meta}->{comment_encoding}, 'ibm437';
        is $item->{rev}->{url}, "https://hoge/$key.zip";
        is $item->{rev}->{original_url}, "https://hoge/$key.zip";
        ok $item->{rev}->{length};
        ok $item->{rev}->{http_date};
        is $item->{rev}->{http_content_type}, 'application/zip';
        is $item->{rev}->{http_last_modified}, 1766901872;
        ok $item->{rev}->{sha256};
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, 'file:abc.dat';
        is $item->{file}, undef;
        is $item->{path}, undef;
        is $item->{package_item}->{mime}, 'application/octet-stream';
        is $item->{package_item}->{title}, "";
        is $item->{package_item}->{file_time}, 1766901800;
        is $item->{package_item}->{legal}, undef;
        is $item->{rev}, undef;
        is $item->{archive_item}->{path}, "abc.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc.dat";
        is $item->{archive_item}->{central}->{byte_length}, 3;
        is $item->{archive_item}->{mtime}, 1766901800;
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
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{file}, undef;
        is $item->{path}, undef, "not exposed in local/data";
        is $item->{package_item}->{mime}, 'application/zip';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, undef;
        is $item->{package_item}->{org}, undef;
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is $item->{package_item}->{file_time}, 1766901872;
        is $item->{package_item}->{legal}, undef;
        ok $item->{package_item}->{snapshot_hash};
        is $item->{archive_item}, undef;
        is $item->{rev}->{url}, "https://hoge/$key.zip";
        is $item->{rev}->{original_url}, "https://hoge/$key.zip";
        ok $item->{rev}->{length};
        ok $item->{rev}->{http_date};
        is $item->{rev}->{http_content_type}, 'application/zip';
        is $item->{rev}->{http_last_modified}, 1766901872;
        ok $item->{rev}->{sha256};
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, 'file:abc.dat';
        is $item->{file}, undef;
        like $item->{path}, qr{files/abc.dat$};
        is $item->{package_item}->{mime}, 'application/octet-stream';
        is $item->{package_item}->{title}, "";
        is $item->{package_item}->{file_time}, 1766901800;
        is $item->{package_item}->{legal}, undef;
        is $item->{rev}->{url}, undef;
        is $item->{rev}->{original_url}, undef;
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{rev}->{length}, 3;
        is $item->{rev}->{http_date}, undef;
        is $item->{rev}->{http_content_type}, undef;
        is $item->{rev}->{http_last_modified}, undef;
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
        is $item->{archive_item}, undef;
      }
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{file}, undef;
        is $item->{path}, undef, "not exposed in local/data";
        is $item->{package_item}->{mime}, 'application/zip';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, undef;
        is $item->{package_item}->{org}, undef;
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is $item->{package_item}->{file_time}, 1766901872;
        is $item->{package_item}->{legal}, undef;
        ok $item->{package_item}->{snapshot_hash};
        is $item->{archive_item}, undef;
        is $item->{rev}->{url}, "https://hoge/$key.zip";
        is $item->{rev}->{original_url}, "https://hoge/$key.zip";
        ok $item->{rev}->{length};
        ok $item->{rev}->{http_date};
        is $item->{rev}->{http_content_type}, 'application/zip';
        is $item->{rev}->{http_last_modified}, 1766901872;
        ok $item->{rev}->{sha256};
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, 'file:abc.dat';
        is $item->{file}, undef;
        like $item->{path}, qr{files/abc.dat$};
        is $item->{package_item}->{mime}, 'application/octet-stream';
        is $item->{package_item}->{title}, "";
        is $item->{package_item}->{file_time}, 1766901800;
        is $item->{package_item}->{legal}, undef;
        is $item->{rev}->{url}, undef;
        is $item->{rev}->{original_url}, undef;
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{rev}->{length}, 3;
        is $item->{rev}->{http_date}, undef;
        is $item->{rev}->{http_content_type}, undef;
        is $item->{rev}->{http_last_modified}, undef;
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
        is $item->{archive_item}->{path}, "abc.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc.dat";
        is $item->{archive_item}->{path_encoding}, 'ibm437';
        is $item->{archive_item}->{mtime}, 1766901800;
      }
    } $current->c;
  });
} n => 171, name => 'ok';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc\x{4000}.dat" => {text => "abc", timestamp => 1766901800},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{file}, undef;
        is $item->{path}, undef, "not exposed in local/data";
        is $item->{package_item}->{mime}, 'application/zip';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, undef;
        is $item->{package_item}->{org}, undef;
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is $item->{package_item}->{file_time}, 1766901872;
        is $item->{package_item}->{legal}, undef;
        ok $item->{package_item}->{snapshot_hash};
        is $item->{rev}->{url}, "https://hoge/$key.zip";
        is $item->{rev}->{original_url}, "https://hoge/$key.zip";
        ok $item->{rev}->{length};
        ok $item->{rev}->{http_date};
        is $item->{rev}->{http_content_type}, 'application/zip';
        is $item->{rev}->{http_last_modified}, 1766901872;
        ok $item->{rev}->{sha256};
        is $item->{archive_item}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc\x{4000}.dat";
        is $item->{file}, undef;
        like $item->{path}, qr{files/abc\x{4000}.dat$};
        is $item->{package_item}->{mime}, 'application/octet-stream';
        is $item->{package_item}->{title}, "";
        is $item->{package_item}->{file_time}, 1766901800;
        is $item->{package_item}->{legal}, undef;
        is $item->{rev}->{url}, undef;
        is $item->{rev}->{original_url}, undef;
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc䀀.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{rev}->{length}, 3;
        is $item->{rev}->{http_date}, undef;
        is $item->{rev}->{http_content_type}, undef;
        is $item->{rev}->{http_last_modified}, undef;
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
        is $item->{archive_item}->{path}, "abc\x{4000}.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc䀀.dat";
        is $item->{archive_item}->{path_encoding}, undef;
        is $item->{archive_item}->{mtime}, 1766901800;
      }
    } $current->c;
  });
} n => 50, name => 'utf8';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc䀀.dat" => {text => "abc", timestamp => 1766901800,
                        byte_file_name => 1},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{file}, undef;
        is $item->{path}, undef, "not exposed in local/data";
        is $item->{package_item}->{mime}, 'application/zip';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, undef;
        is $item->{package_item}->{org}, undef;
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is $item->{package_item}->{file_time}, 1766901872;
        is $item->{package_item}->{legal}, undef;
        ok $item->{package_item}->{snapshot_hash};
        is $item->{rev}->{url}, "https://hoge/$key.zip";
        is $item->{rev}->{original_url}, "https://hoge/$key.zip";
        ok $item->{rev}->{length};
        ok $item->{rev}->{http_date};
        is $item->{rev}->{http_content_type}, 'application/zip';
        is $item->{rev}->{http_last_modified}, 1766901872;
        ok $item->{rev}->{sha256};
        is $item->{archive_item}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc\x{4000}.dat";
        is $item->{file}, undef;
        like $item->{path}, qr{files/abc\x{4000}.dat$};
        is $item->{package_item}->{mime}, 'application/octet-stream';
        is $item->{package_item}->{title}, "";
        is $item->{package_item}->{file_time}, 1766901800;
        is $item->{package_item}->{legal}, undef;
        is $item->{rev}->{url}, undef;
        is $item->{rev}->{original_url}, undef;
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc䀀.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{rev}->{length}, 3;
        is $item->{rev}->{http_date}, undef;
        is $item->{rev}->{http_content_type}, undef;
        is $item->{rev}->{http_last_modified}, undef;
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
        is $item->{archive_item}->{path}, "abc\x{4000}.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc䀀.dat";
        is $item->{archive_item}->{path_encoding}, "utf-8";
        is $item->{archive_item}->{mtime}, 1766901800;
      }
    } $current->c;
  });
} n => 50, name => 'utf8 unflagged';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc䀀.dat" => {text => "abc", timestamp => 1766901800,
                        byte_file_name => 1},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip", '--forced-encoding', 'iBm437']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{file}, undef;
        is $item->{path}, undef, "not exposed in local/data";
        is $item->{package_item}->{mime}, 'application/zip';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, undef;
        is $item->{package_item}->{org}, undef;
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is $item->{package_item}->{file_time}, 1766901872;
        is $item->{package_item}->{legal}, undef;
        ok $item->{package_item}->{snapshot_hash};
        is $item->{rev}->{url}, "https://hoge/$key.zip";
        is $item->{rev}->{original_url}, "https://hoge/$key.zip";
        ok $item->{rev}->{length};
        ok $item->{rev}->{http_date};
        is $item->{rev}->{http_content_type}, 'application/zip';
        is $item->{rev}->{http_last_modified}, 1766901872;
        ok $item->{rev}->{sha256};
        is $item->{archive_item}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc\x{03A3}\x{C7}\x{C7}.dat";
        is $item->{file}, undef;
        like $item->{path}, qr{files/abc\x{03A3}\x{C7}\x{C7}.dat$};
        is $item->{package_item}->{mime}, 'application/octet-stream';
        is $item->{package_item}->{title}, "";
        is $item->{package_item}->{file_time}, 1766901800;
        is $item->{package_item}->{legal}, undef;
        is $item->{rev}->{url}, undef;
        is $item->{rev}->{original_url}, undef;
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc䀀.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{rev}->{length}, 3;
        is $item->{rev}->{http_date}, undef;
        is $item->{rev}->{http_content_type}, undef;
        is $item->{rev}->{http_last_modified}, undef;
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
        is $item->{archive_item}->{path}, "abc\x{03A3}\x{C7}\x{C7}.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc䀀.dat";
        is $item->{archive_item}->{path_encoding}, "ibm437";
        is $item->{archive_item}->{mtime}, 1766901800;
      }
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
        my ($json, $path) = @_;
        my $item = $json->{$key};
        is $item->{forced_encoding}, "iBm437";
      }},
    ]);
  });
} n => 52, name => 'forced encoding';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x9A\xA2.dat" => {text => "abc", timestamp => 1766901800,
                              byte_file_name => 1},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{file}, undef;
        is $item->{path}, undef, "not exposed in local/data";
        is $item->{package_item}->{mime}, 'application/zip';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, undef;
        is $item->{package_item}->{org}, undef;
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is $item->{package_item}->{file_time}, 1766901872;
        is $item->{package_item}->{legal}, undef;
        ok $item->{package_item}->{snapshot_hash};
        is $item->{package_item}->{tzoffset}, 9*60*60;
        is $item->{rev}->{url}, "https://hoge/$key.zip";
        is $item->{rev}->{original_url}, "https://hoge/$key.zip";
        ok $item->{rev}->{length};
        ok $item->{rev}->{http_date};
        is $item->{rev}->{http_content_type}, 'application/zip';
        is $item->{rev}->{http_last_modified}, 1766901872;
        ok $item->{rev}->{sha256};
        is $item->{archive_item}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{5713}.dat";
        is $item->{file}, undef;
        like $item->{path}, qr{files/abc\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{5713}.dat$};
        is $item->{package_item}->{mime}, 'application/octet-stream';
        is $item->{package_item}->{title}, "";
        is $item->{package_item}->{file_time}, 1766901800 -9*60*60;
        is $item->{package_item}->{legal}, undef;
        is $item->{rev}->{url}, undef;
        is $item->{rev}->{original_url}, undef;
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x9A\xA2.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{rev}->{length}, 3;
        is $item->{rev}->{http_date}, undef;
        is $item->{rev}->{http_content_type}, undef;
        is $item->{rev}->{http_last_modified}, undef;
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
        is $item->{package_item}->{file_name}, "abc\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{5713}.dat";
        is $item->{archive_item}->{path}, "abc\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{5713}.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x9A\xA2.dat";
        is $item->{archive_item}->{path_encoding}, "shift_jis";
        is $item->{archive_item}->{mtime}, 1766901800 -9*60*60;
        is $item->{package_item}->{tzoffset}, 9*60*60;
      }
    } $current->c;
  });
} n => 53, name => 'sjis';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc/def.dat" => {text => "abc", timestamp => 1766901800},
        "abc/xyz/a.dat" => {text => "abc", timestamp => 1766901800},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 3;
      $r->{jsonl} = [sort { $a->{key} cmp $b->{key} } @{$r->{jsonl}}];
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc/def.dat";
        is $item->{file}, undef;
        like $item->{path}, qr{files/def.dat$};
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc/def.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "abc/def.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc/def.dat";
        is $item->{archive_item}->{path_encoding}, 'ibm437';
        is $item->{package_item}->{desc}, "";
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc/xyz/a.dat";
        is $item->{file}, undef;
        like $item->{path}, qr{files/a.dat$};
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc/xyz/a.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "abc/xyz/a.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc/xyz/a.dat";
        is $item->{archive_item}->{path_encoding}, 'ibm437';
      }
    } $current->c;
  });
} n => 25, name => 'directoried';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc/def\x{4000}.dat" => {text => "abc", timestamp => 1766901800,
                                  comment => "abc\x{6000}"},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc/def\x{4000}.dat";
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc/def䀀.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "abc/def\x{4000}.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc/def䀀.dat";
        is $item->{archive_item}->{path_encoding}, undef;
        is $item->{archive_item}->{comment}, "abc\x{6000}";
        is $item->{archive_item}->{comment_encoding}, undef;
        is $item->{archive_item}->{central}->{raw_comment}, "abc\xe6\x80\x80";
        is $item->{package_item}->{desc}, "abc\x{6000}";
      }
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc/def\x{4000}.dat";
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc/def䀀.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}, undef;
        is $item->{package_item}->{desc}, "abc\x{6000}";
      }
    } $current->c;
  });
} n => 25, name => 'file comment utf-8 flagged';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc/def一.dat" => {text => "abc", timestamp => 1766901800,
                            byte_file_name => 1, comment => "abc\x{6000}"},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc/def\x{4E00}.dat";
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc/def\xe4\xb8\x80.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "abc/def\x{4E00}.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc/def\xe4\xb8\x80.dat";
        is $item->{archive_item}->{path_encoding}, "utf-8";
        is $item->{archive_item}->{comment}, "abc\x{6000}";
        is $item->{archive_item}->{comment_encoding}, "utf-8";
        is $item->{archive_item}->{central}->{raw_comment}, "abc\xe6\x80\x80";
        is $item->{package_item}->{desc}, "abc\x{6000}";
      }
    } $current->c;
  });
} n => 16, name => 'file comment utf-8 unflagged';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "\x{FEFF}abc/def\x{4000}.dat" => {text => "abc",
                                          comment => "\x{FEFF}abc\x{6000}"},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:\x{FEFF}abc/def\x{4000}.dat";
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "\xEF\xBB\xBFabc/def䀀.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "\x{FEFF}abc/def\x{4000}.dat";
        is $item->{archive_item}->{central}->{raw_path}, "\xEF\xBB\xBFabc/def䀀.dat";
        is $item->{archive_item}->{path_encoding}, undef;
        is $item->{archive_item}->{comment}, "\x{FEFF}abc\x{6000}";
        is $item->{archive_item}->{comment_encoding}, undef;
        is $item->{archive_item}->{central}->{raw_comment}, "\xEF\xBB\xBFabc\xe6\x80\x80";
        is $item->{package_item}->{desc}, "\x{FEFF}abc\x{6000}";
      }
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:\x{FEFF}abc/def\x{4000}.dat";
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "\xEF\xBB\xBFabc/def䀀.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}, undef;
        is $item->{package_item}->{desc}, "\x{FEFF}abc\x{6000}";
      }
    } $current->c;
  });
} n => 25, name => 'file comment utf-8 with BOM';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "\xEF\xBB\xBFabc/def一.dat" => {text => "abc", timestamp => 1766901800,
                                        byte_file_name => 1, byte_comment => 1,
                                        comment => "\xEF\xBB\xBFabc\xe6\x80\x80"},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:\x{FEFF}abc/def\x{4E00}.dat";
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "\xEF\xBB\xBFabc/def\xe4\xb8\x80.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "\x{FEFF}abc/def\x{4E00}.dat";
        is $item->{archive_item}->{central}->{raw_path}, "\xEF\xBB\xBFabc/def\xe4\xb8\x80.dat";
        is $item->{archive_item}->{path_encoding}, "utf-8";
        is $item->{archive_item}->{comment}, "\x{FEFF}abc\x{6000}";
        is $item->{archive_item}->{comment_encoding}, "utf-8";
        is $item->{archive_item}->{central}->{raw_comment}, "\xEF\xBB\xBFabc\xe6\x80\x80";
        is $item->{package_item}->{desc}, "\x{FEFF}abc\x{6000}";
      }
    } $current->c;
  });
} n => 16, name => 'file comment utf-8 unflagged with BOM';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
      }, comment => "\x{FEFF}abc\x{6000}\x{0300}"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
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
        is $item->{archive_meta}, undef;
        is $item->{package_item}->{desc}, "\x{FEFF}abc\x{6000}\x{0300}";
      }
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 1;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{archive_meta}->{comment}, "\x{FEFF}abc\x{6000}\x{0300}";
        is $item->{archive_meta}->{comment_encoding}, "utf-8";
        is $item->{archive_meta}->{raw_comment}, "\xEF\xBB\xBFabc怀̀";
        is $item->{package_item}->{desc}, "\x{FEFF}abc\x{6000}\x{0300}";
      }
    } $current->c;
  });
} n => 11, name => 'zip comment utf-8';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
      }, comment => "abc\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x9A\xA2", byte_comment => 1},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('add', additional => ["https://hoge/$key.zip", '--forced-encoding', "ISo-8859-1"]);
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
        is $item->{archive_meta}, undef;
        is $item->{package_item}->{desc}, "abc\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{5713}";
      }
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 1;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{archive_meta}->{comment}, "abc\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{5713}";
        is $item->{archive_meta}->{comment_encoding}, "shift_jis";
        is $item->{archive_meta}->{raw_comment}, "abc\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x9A\xA2";
        is $item->{package_item}->{desc}, "abc\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{5713}";
      }
    } $current->c;
    return $current->run ('ls', additional => ["$key-2", '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 1;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{archive_meta}->{comment}, "abc\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{0161}\xA2";
        is $item->{archive_meta}->{comment_encoding}, "windows-1252";
        is $item->{archive_meta}->{raw_comment}, "abc\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x9A\xA2";
        is $item->{package_item}->{desc}, "abc\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{0161}\xA2";
      }
    } $current->c;
  });
} n => 18, name => 'zip comment sjis';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc/def.dat" => {text => "abc", timestamp => 1766901800},
        "abc/xyz/" => {is_directory => 1},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      $r->{jsonl} = [sort { $a->{key} cmp $b->{key} } @{$r->{jsonl}}];
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc/def.dat";
        is $item->{file}, undef;
        like $item->{path}, qr{files/def.dat$};
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc/def.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "abc/def.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc/def.dat";
        is $item->{archive_item}->{path_encoding}, 'ibm437';
      }
    } $current->c;
  });
} n => 14, name => 'has directory';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "ab\\c.dat" => {text => "abc", timestamp => 1766901800},
        "b/con/con.dat" => {text => "abc", timestamp => 1766901800},
        "c//" => {text => "abc", timestamp => 1766901800},
        "d\x00" => {text => "abc", timestamp => 1766901800},
        "eF" => {text => "abc", timestamp => 1766901800},
        "ef" => {text => "abc", timestamp => 1766901800},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 7;
      $r->{jsonl} = [sort { $a->{key} cmp $b->{key} } @{$r->{jsonl}}];
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'file';
        is $item->{key}, "file:ab\\c.dat";
        like $item->{path}, qr{files/c.dat$};
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "ab\\c.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "ab\\c.dat";
        is $item->{archive_item}->{central}->{raw_path}, "ab\\c.dat";
        is $item->{archive_item}->{path_encoding}, 'ibm437';
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:b/con/con.dat";
        is $item->{file}, undef;
        like $item->{path}, qr{files/[0-9]+$};
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "b/con/con.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "b/con/con.dat";
        is $item->{archive_item}->{central}->{raw_path}, "b/con/con.dat";
        is $item->{archive_item}->{path_encoding}, 'ibm437';
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'file';
        is $item->{key}, "file:c//";
        is $item->{file}, undef;
        like $item->{path}, qr{files/[0-9]+$};
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "c//";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "c//";
        is $item->{archive_item}->{central}->{raw_path}, "c//";
        is $item->{archive_item}->{path_encoding}, 'ibm437';
      }
      {
        my $item = $r->{jsonl}->[3];
        is $item->{type}, 'file';
        is $item->{key}, "file:d\x00";
        is $item->{file}, undef;
        like $item->{path}, qr{files/d_$};
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "d\x00";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "d\x00";
        is $item->{archive_item}->{central}->{raw_path}, "d\x00";
        is $item->{archive_item}->{path_encoding}, 'ibm437';
      }
      {
        my $item = $r->{jsonl}->[4];
        is $item->{type}, 'file';
        is $item->{key}, "file:eF";
        is $item->{file}, undef;
        like $item->{path}, qr{files/eF-[0-9]+$};
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "eF";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "eF";
        is $item->{archive_item}->{central}->{raw_path}, "eF";
        is $item->{archive_item}->{path_encoding}, 'ibm437';
      }
      {
        my $item = $r->{jsonl}->[5];
        is $item->{type}, 'file';
        is $item->{key}, "file:ef";
        is $item->{file}, undef;
        like $item->{path}, qr{files/ef-[0-9]+$};
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "ef";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{archive_item}->{path}, "ef";
        is $item->{archive_item}->{central}->{raw_path}, "ef";
        is $item->{archive_item}->{path_encoding}, 'ibm437';
      }
    } $current->c;
  });
} n => 63, name => 'stupid file names';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "http://hoge/$key.zip" => {zip => {
        "abc\x{4000}.dat" => {text => "abc", timestamp => 1766901800},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["http://hoge/$key.zip"], insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{file}, undef;
        is $item->{path}, undef, "not exposed in local/data";
        is $item->{package_item}->{mime}, 'application/zip';
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, undef;
        is $item->{package_item}->{org}, undef;
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        is $item->{package_item}->{file_time}, 1766901872;
        is $item->{package_item}->{legal}, undef;
        ok $item->{package_item}->{snapshot_hash};
        is $item->{rev}->{url}, "http://hoge/$key.zip";
        is $item->{rev}->{original_url}, "http://hoge/$key.zip";
        ok $item->{rev}->{length};
        ok $item->{rev}->{http_date};
        is $item->{rev}->{http_content_type}, 'application/zip';
        is $item->{rev}->{http_last_modified}, 1766901872;
        ok $item->{rev}->{sha256};
        ok $item->{rev}->{insecure};
        is $item->{archive_item}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc\x{4000}.dat";
        is $item->{file}, undef;
        like $item->{path}, qr{files/abc\x{4000}.dat$};
        is $item->{package_item}->{mime}, 'application/octet-stream';
        is $item->{package_item}->{title}, "";
        is $item->{package_item}->{file_time}, 1766901800;
        is $item->{package_item}->{legal}, undef;
        is $item->{rev}->{url}, undef;
        is $item->{rev}->{original_url}, undef;
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc䀀.dat";
        is $item->{rev}->{path_encoding}, undef;
        is $item->{rev}->{length}, 3;
        is $item->{rev}->{http_date}, undef;
        is $item->{rev}->{http_content_type}, undef;
        is $item->{rev}->{http_last_modified}, undef;
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
        ok $item->{rev}->{insecure};
        is $item->{archive_item}->{path}, "abc\x{4000}.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc䀀.dat";
        is $item->{archive_item}->{path_encoding}, undef;
        is $item->{archive_item}->{mtime}, 1766901800;
      }
    } $current->c;
    return $current->check_files ([
      {path => $current->repo_path ('single', "http://hoge/$key.zip")->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'single';
         ok my $key = $json->{urls}->{"http://hoge/$key.zip"};
         {
           my $item = $json->{items}->{$key};
           is $item->{type}, 'file';
           ok $item->{files}->{data};
           ok $item->{files}->{"archive-zip"};

           my $dir_path = $path->parent->child ($item->{files}->{"archive-zip"});
           my $json_path = $dir_path->child ('index.json');
           my $json = json_bytes2perl $json_path->slurp;
           {
             my $item = $json->{items}->{"file:abc\x{4000}.dat"};
             ok $item->{rev}->{insecure};
           }
         }
       }},
    ]);
  });
} n => 59, name => 'insecure';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "a1.dat" => {text => "abc", timestamp => 1766901900},
        "a2.dat" => {text => "abc", timestamp => 1766901901},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      $r->{jsonl} = [sort { $a->{key} cmp $b->{key} } @{$r->{jsonl}}];
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'file';
        is $item->{key}, "file:a1.dat";
        is $item->{package_item}->{file_time}, 1766901900;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, 1766901900;
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536962720;
        is $item->{archive_item}->{tzoffset}, undef;
        is $item->{package_item}->{tzoffset}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:a2.dat";
        is $item->{package_item}->{file_time}, 1766901900;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, 1766901900;
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536962720;
        is $item->{archive_item}->{tzoffset}, undef;
        is $item->{package_item}->{tzoffset}, undef;
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{file_time}, 1766901900;
        is $item->{rev}->{http_last_modified}, 1766901872;
        is $item->{package_item}->{tzoffset}, undef;
      }
    } $current->c;
  });
} n => 24, name => 'local-time only';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "a1.dat" => {text => "abc", timestamp => 1766901900},
        "a2.dat" => {text => "abc", timestamp => 1766901901},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip", '--forced-tzoffset', -63464]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      $r->{jsonl} = [sort { $a->{key} cmp $b->{key} } @{$r->{jsonl}}];
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'file';
        is $item->{key}, "file:a1.dat";
        is $item->{package_item}->{file_time}, 1766901900 - -63464;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, 1766901900 - -63464;
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536962720;
        is $item->{archive_item}->{tzoffset}, -63464;
        is $item->{package_item}->{tzoffset}, -63464;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:a2.dat";
        is $item->{package_item}->{file_time}, 1766901900 - -63464;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, 1766901900 - -63464;
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536962720;
        is $item->{archive_item}->{tzoffset}, -63464;
        is $item->{package_item}->{tzoffset}, -63464;
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'package';
        is $item->{key}, 'package';            
        is $item->{package_item}->{file_time}, 1766901900 - -63464;
        is $item->{rev}->{http_last_modified}, 1766901872;
        is $item->{package_item}->{tzoffset}, -63464;
      }
    } $current->c;
  });
} n => 24, name => 'local-time only with forced_tzoffset';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "a1.dat" => {text => "abc", timestamp => 1766901900,
                     tzoffset => 3600},
        "a2.dat" => {text => "abc", timestamp => 1766901901,
                     tzoffset => -3600},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      $r->{jsonl} = [sort { $a->{key} cmp $b->{key} } @{$r->{jsonl}}];
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'file';
        is $item->{key}, "file:a1.dat";
        is $item->{package_item}->{file_time}, 1766901900;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, 1766901900;
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536964768;
        is $item->{archive_item}->{tzoffset}, 3600;
        is $item->{package_item}->{tzoffset}, 3600;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:a2.dat";
        is $item->{package_item}->{file_time}, 1766901901;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, 1766901901;
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536960672;
        is $item->{archive_item}->{tzoffset}, -3600;
        is $item->{package_item}->{tzoffset}, -3600;
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{file_time}, 1766901901;
        is $item->{rev}->{http_last_modified}, 1766901872;
        is abs $item->{package_item}->{tzoffset}, 3600;
      }
    } $current->c;
  });
} n => 24, name => 'has unixtime';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "a1.dat" => {text => "abc", timestamp => 1766901900,
                     tzoffset => 3600},
        "a2.dat" => {text => "abc", timestamp => 1766901901,
                     tzoffset => -3600},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip", '--forced-tzoffset', "+24554"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      $r->{jsonl} = [sort { $a->{key} cmp $b->{key} } @{$r->{jsonl}}];
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'file';
        is $item->{key}, "file:a1.dat";
        is $item->{package_item}->{file_time}, 1766901900;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, 1766901900;
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536964768;
        is $item->{archive_item}->{tzoffset}, 24554;
        is $item->{package_item}->{tzoffset}, 24554;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:a2.dat";
        is $item->{package_item}->{file_time}, 1766901901;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, 1766901901;
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536960672;
        is $item->{archive_item}->{tzoffset}, 24554;
        is $item->{package_item}->{tzoffset}, 24554;
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{file_time}, 1766901901;
        is $item->{rev}->{http_last_modified}, 1766901872;
        is $item->{package_item}->{tzoffset}, 24554;
      }
    } $current->c;
  });
} n => 24, name => 'has unixtime with tzoffset';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "a1.dat" => {text => "abc", timestamp => '1766901900.123456700',
                     tzoffset => 3600, ntfs => 1},
        "a2.dat" => {text => "abc", timestamp => 1766901689,
                     tzoffset => -3600, ntfs => 1,
                     birthtime => '135356660.123456700'},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1, stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      $r->{jsonl} = [sort { $a->{key} cmp $b->{key} } @{$r->{jsonl}}];
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'file';
        is $item->{key}, "file:a1.dat";
        is $item->{package_item}->{file_time}, '1766901900.1234567';
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, '1766901900.1234567';
        like $r->{stdout}, qr{"1766901900.1234567"};
        unlike $r->{stdout}, qr{:1766901900};
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536964768;
        is $item->{archive_item}->{tzoffset}, 3600;
        is $item->{package_item}->{tzoffset}, 3600;
        is $item->{archive_item}->{birthtime}, undef;
        is $item->{archive_item}->{central}->{zip_ntfs_mtime}, "134113755001234567";
        like $r->{stdout}, qr{"134113755001234567"};
        unlike $r->{stdout}, qr{:134113755001234567};
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:a2.dat";
        is $item->{package_item}->{file_time}, 1766901689;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, 1766901689;
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536960558;
        is $item->{archive_item}->{tzoffset}, -3600;
        is $item->{package_item}->{tzoffset}, -3600;
        is $item->{archive_item}->{birthtime}, '135356660.1234567';
        like $r->{stdout}, qr{"135356660.1234567"};
        unlike $r->{stdout}, qr{:135356660};
        is $item->{archive_item}->{central}->{zip_ntfs_birthtime}, "117798302601234567";
        like $r->{stdout}, qr{"117798302601234567"};
        unlike $r->{stdout}, qr{:117798302601234567};
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{file_time}, '1766901900.1234567';
        is $item->{rev}->{http_last_modified}, 1766901872;
        is abs $item->{package_item}->{tzoffset}, 3600;
      }
    } $current->c;
  });
} n => 36, name => 'has ntfstime';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "a1.dat" => {text => "abc", timestamp => '1766901900.123456700',
                     tzoffset => 3600, ntfs => 1},
        "a2.dat" => {text => "abc", timestamp => 1766901689, ntfs => 1},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1, stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      $r->{jsonl} = [sort { $a->{key} cmp $b->{key} } @{$r->{jsonl}}];
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'file';
        is $item->{key}, "file:a1.dat";
        is $item->{package_item}->{file_time}, '1766901900.1234567';
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, '1766901900.1234567';
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536964768;
        is $item->{archive_item}->{tzoffset}, 3600;
        is $item->{package_item}->{tzoffset}, 3600;
        is $item->{archive_item}->{birthtime}, undef;
        is $item->{archive_item}->{central}->{zip_ntfs_mtime}, "134113755001234567";
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:a2.dat";
        is $item->{package_item}->{file_time}, 1766901688 -3600;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, 1766901688 -3600;
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536962606;
        is $item->{archive_item}->{tzoffset}, 3600;
        is $item->{package_item}->{tzoffset}, 3600;
        is $item->{archive_item}->{birthtime}, undef;
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{file_time}, '1766901900.1234567';
        is $item->{rev}->{http_last_modified}, 1766901872;
        is $item->{package_item}->{tzoffset}, 3600;
      }
    } $current->c;
  });
} n => 27, name => 'tzoffset implied';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "a1.dat" => {text => "abc", timestamp => '1766901900.123456700',
                     tzoffset => 3600, ntfs => 1},
        "a2.dat" => {text => "abc", timestamp => 1766901689, ntfs => 1},
      }, timestamp => 1766901872},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip", '--forced-tzoffset', -12445]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => [$key, '--all'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('ls', additional => [$key, '--jsonl', '--with-source-meta'], jsonl => 1, stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      $r->{jsonl} = [sort { $a->{key} cmp $b->{key} } @{$r->{jsonl}}];
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'file';
        is $item->{key}, "file:a1.dat";
        is $item->{package_item}->{file_time}, '1766901900.1234567';
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, '1766901900.1234567';
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536964768;
        is $item->{archive_item}->{tzoffset}, -12445;
        is $item->{package_item}->{tzoffset}, -12445;
        is $item->{archive_item}->{birthtime}, undef;
        is $item->{archive_item}->{central}->{zip_ntfs_mtime}, "134113755001234567";
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:a2.dat";
        is $item->{package_item}->{file_time}, 1766901688 - -12445;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{mtime}, 1766901688 - -12445;
        is $item->{archive_item}->{central}->{zip_raw_last_mod_file_date_time}, 1536962606;
        is $item->{archive_item}->{tzoffset}, -12445;
        is $item->{package_item}->{tzoffset}, -12445;
        is $item->{archive_item}->{birthtime}, undef;
      }
      {
        my $item = $r->{jsonl}->[2];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{file_time}, 1766901688 - -12445;
        is $item->{rev}->{http_last_modified}, 1766901872;
        is $item->{package_item}->{tzoffset}, -12445;
      }
    } $current->c;
  });
} n => 27, name => 'tzoffset implied but forced';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x9A\xA2.dat" => {text => "abc", timestamp => 1766901800,
                              byte_file_name => 1},
      }, timestamp => 1766900000},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip", '--name', "a1", '--forced-tzoffset', 12345]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('add', additional => ["https://hoge/$key.zip", '--name', "a2", '--forced-encoding', 'windows-1252']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('use', additional => ['a1', '--all'], jsonl => 1);
  })->then (sub {
    return $current->run ('use', additional => ['a2', '--all'], jsonl => 1);
  })->then (sub {
    return $current->run ('ls', additional => ["a1", '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{file_time}, 1766900000;
        is $item->{rev}->{http_last_modified}, 1766900000;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{5713}.dat";
        like $item->{path}, qr{files/abc\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{5713}.dat$}, $item->{path};
        is $item->{package_item}->{file_time}, 1766901800 -12345;
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x9A\xA2.dat";
        is $item->{rev}->{path_encoding}, undef;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{path}, "abc\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{3044}\x{5713}.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x9A\xA2.dat";
        is $item->{archive_item}->{path_encoding}, "shift_jis";
        is $item->{archive_item}->{mtime}, 1766901800 -12345;
        is $item->{package_item}->{tzoffset}, 12345;
      }
    } $current->c;
    return $current->run ('ls', additional => ["a2", '--jsonl', '--with-source-meta'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 2;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{type}, 'package';
        is $item->{key}, 'package';
        is $item->{package_item}->{file_time}, 1766901800;
        is $item->{rev}->{http_last_modified}, 1766900000;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, "file:abc\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{0161}\xA2.dat";
        like $item->{path}, qr{files/abc\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{0161}\xA2.dat$}, $item->{path};
        is $item->{package_item}->{file_time}, 1766901800;
        is $item->{rev}->{path}, undef;
        is $item->{rev}->{raw_path}, "abc\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x9A\xA2.dat";
        is $item->{rev}->{path_encoding}, undef;
        ok $item->{rev}->{timestamp};
        is $item->{archive_item}->{path}, "abc\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{201A}\xA2\x{0161}\xA2.dat";
        is $item->{archive_item}->{central}->{raw_path}, "abc\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x82\xA2\x9A\xA2.dat";
        is $item->{archive_item}->{path_encoding}, "windows-1252";
        is $item->{archive_item}->{mtime}, 1766901800;
        is $item->{package_item}->{tzoffset}, undef;
      }
    } $current->c;
  });
} n => 40, name => 'different options';

Run;

=head1 LICENSE

Copyright 2025-2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
