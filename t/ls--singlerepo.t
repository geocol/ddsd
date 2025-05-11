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
      }
    } $current->c;
  });
} n => 31, name => 'ok';

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
        is $item->{package_item}->{mime}, undef;
        is $item->{package_item}->{title}, undef;
        is $item->{rev}, undef;
      }
    } $current->c;
  });
} n => 26, name => 'missing file';

Run;

=head1 LICENSE

Copyright 2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
