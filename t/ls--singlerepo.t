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
      "https://hoge/" . $key => {text => "r1"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key", '--single-file']);
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
        is $item->{rev}, undef;
        is $item->{path}, undef;
        is $item->{package_item}->{mime}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, '';
        is $item->{package_item}->{org}, '';
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        ok $item->{package_item}->{file_time};
        is ref $item->{package_item}->{legal}, 'ARRAY';
        is 0+@{$item->{package_item}->{legal}}, 0;
        is $item->{source}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, 'file';
        is $item->{file}, undef;
        ok $item->{path};
        is $item->{package_item}->{mime}, 'application/octet-stream';
        is $item->{package_item}->{title}, "";
        ok $item->{rev}->{http_date};
        ok $item->{rev}->{length};
        ok $item->{rev}->{sha256};
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{url}, "https://hoge/$key";
        is $item->{rev}->{original_url}, $item->{rev}->{url};
        is $item->{source}, undef;
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
        is $item->{rev}, undef;
        is $item->{path}, undef;
        is $item->{package_item}->{mime}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, '';
        is $item->{package_item}->{org}, '';
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        ok $item->{package_item}->{file_time};
        is ref $item->{package_item}->{legal}, 'ARRAY';
        is 0+@{$item->{package_item}->{legal}}, 0;
        is $item->{source}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, 'file';
        is $item->{file}, undef;
        ok $item->{path};
        is $item->{package_item}->{mime}, 'application/octet-stream';
        is $item->{package_item}->{title}, "";
        ok $item->{rev}->{http_date};
        ok $item->{rev}->{length};
        ok $item->{rev}->{sha256};
        ok $item->{rev}->{timestamp};
        is $item->{rev}->{url}, "https://hoge/$key";
        is $item->{rev}->{original_url}, $item->{rev}->{url};
        is $item->{source}->{url}, "https://hoge/$key";
      }
    } $current->c;
  });
} n => 65, name => 'ok';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key", '--single-file']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
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
        is $item->{rev}, undef;
        is $item->{path}, undef;
        is $item->{package_item}->{mime}, undef;
        is $item->{package_item}->{title}, '';
        is $item->{package_item}->{desc}, '';
        is $item->{package_item}->{author}, '';
        is $item->{package_item}->{org}, '';
        is $item->{package_item}->{lang}, '';
        is $item->{package_item}->{dir}, 'auto';
        is $item->{package_item}->{writing_mode}, 'horizontal-tb';
        ok $item->{package_item}->{file_time};
        is ref $item->{package_item}->{legal}, 'ARRAY';
        is 0+@{$item->{package_item}->{legal}}, 0;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{key}, 'file';
        is $item->{file}, undef;
        is $item->{path}, undef;
        is $item->{package_item}->{mime}, 'application/octet-stream';
        is $item->{package_item}->{title}, '';
        is $item->{rev}, undef;
      }
    } $current->c;
  });
} n => 26, name => 'missing file';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/" . $key => {text => "r1", mime => 'text/CSS'},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key", '--single-file']);
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
        is $item->{package_item}->{mime}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{package_item}->{mime}, 'text/css';
        is $item->{rev}->{http_content_type}, 'text/CSS';
      }
    } $current->c;
  });
} n => 8, name => 'mime 1';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.png" => {text => "r1"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.png", '--single-file', '--name', $key]);
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
        is $item->{package_item}->{mime}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{package_item}->{mime}, 'image/png';
        is $item->{rev}->{http_content_type}, undef;
      }
    } $current->c;
  });
} n => 8, name => 'mime 2';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.png" => {text => "r1", mime_filename => "hoge.js"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.png", '--single-file', '--name', $key]);
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
        is $item->{package_item}->{mime}, undef;
      }
      {
        my $item = $r->{jsonl}->[1];
        is $item->{type}, 'file';
        is $item->{package_item}->{mime}, 'text/javascript';
        is $item->{rev}->{http_content_type}, undef;
      }
    } $current->c;
  });
} n => 8, name => 'mime 3';

Run;

=head1 LICENSE

Copyright 2025-2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
