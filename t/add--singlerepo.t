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
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         {
           my $file = $json->{items}->{file};
           is $file->{type}, 'file';
           is $file->{files}->{data}, "files/$key";
           is $file->{rev}->{original_url}, "https://hoge/$key";
           is $file->{rev}->{url}, "https://hoge/$key";
           ok $file->{rev}->{sha256};
           ok $file->{rev}->{timestamp};
           ok ! $file->{rev}->{insecure};
         }
       }},
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         ok $json->{$key};
         {
           my $item = $json->{$key};
           is $item->{type}, 'single';
           is $item->{url}, "https://hoge/$key";
         }
       }},
      {path => "local/data/$key/files/$key", text => "r1"},
    ]);
  });
} n => 16, name => 'ok';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/" . $key . "/" => {text => "r1"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key/", '--single-file']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         {
           my $file = $json->{items}->{file};
           is $file->{type}, 'file';
           is $file->{files}->{data}, "files/1";
           is $file->{rev}->{original_url}, "https://hoge/$key/";
           is $file->{rev}->{url}, "https://hoge/$key/";
           ok $file->{rev}->{sha256};
           ok $file->{rev}->{timestamp};
           ok ! $file->{rev}->{insecure};
         }
       }},
      {path => "local/data/$key/files/1", text => "r1"},
      {path => "local/data/$key/files/$key", is_none => 1},
    ]);
  });
} n => 13, name => 'directory';

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
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 0;
       }},
      {path => "local/data/$key/files/$key", is_none => 1},
    ]);
  });
} n => 5, name => 'file not found';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/" . $key => {text => "r1"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key", '--single-file', '--min']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 0;
       }},
      {path => "local/data/$key/files/$key", is_none => 1},
    ]);
  });
} n => 5, name => '--min';

Test {
  my $current = shift;
  my $key = '' . rand;
  my $key2 = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/" . $key => {text => "r1"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key", '--single-file', '--name', "$key2"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key2/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         {
           my $file = $json->{items}->{file};
           is $file->{type}, 'file';
           is $file->{files}->{data}, "files/$key";
           is $file->{rev}->{original_url}, "https://hoge/$key";
           is $file->{rev}->{url}, "https://hoge/$key";
           ok $file->{rev}->{sha256};
           ok $file->{rev}->{timestamp};
           ok ! $file->{rev}->{insecure};
         }
       }},
      {path => "local/data/$key2/files/$key", text => "r1"},
    ]);
  });
} n => 13, name => '--name';

Run;

=head1 LICENSE

Copyright 2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
