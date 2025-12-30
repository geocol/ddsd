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
      $key => {
        type => 'single',
        url => "https://hoge/$key",
      },
    },
    {
      "https://hoge/" . $key => {text => "r1"},
    },
  )->then (sub {
    return $current->run ('pull', additional => []);
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
      {path => "local/data/$key/files/$key", text => "r1"},
    ]);
  });
} n => 13, name => 'pull';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'single',
        url => "https://hoge/$key",
      },
    },
    {
      "https://hoge/" . $key => {text => "r1"},
    },
  )->then (sub {
    return $current->run ('pull', additional => []);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare (
      undef,
      {
        "https://hoge/" . $key => {text => "r2"},
      },
    );
  })->then (sub {
    return $current->run ('pull', additional => []);
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
      {path => "local/data/$key/files/$key", text => "r2"},
    ]);
  });
} n => 14, name => 'repull';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'single',
        url => "https://hoge/$key",
      },
    },
    {
      "https://hoge/" . $key => {text => "r1", etag => rand},
    },
  )->then (sub {
    return $current->run ('pull', additional => []);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare (
      undef,
      {
        "https://hoge/" . $key => {text => "r2", status => 304},
      },
    );
  })->then (sub {
    return $current->run ('pull', additional => []);
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
      {path => "local/data/$key/files/$key", text => "r1"},
    ]);
  });
} n => 14, name => 'repull 304';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'single',
        url => "https://hoge/$key",
      },
    },
    {
      "https://hoge/" . $key => {text => "r1", status => 304},
    },
  )->then (sub {
    return $current->run ('pull', additional => []);
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
} n => 5, name => 'bad 304';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'single',
        url => "https://hoge/$key/abc.txt",
        files => {
          "file" => {
            sha256 => "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
          },
        },
      },
    },
    {
      "https://hoge/$key/abc.txt" => {text => "abc"},
    },
  )->then (sub {
    return $current->run ('pull', additional => []);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/files/abc.txt", text => "abc"},
    ]);
  })->then (sub {
    return $current->prepare (
      undef, {
        "https://hoge/$key/abc.txt" => {text => "xyz"},
      },
    );
  })->then (sub {
    return $current->run ('pull', additional => []);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/files/abc.txt", text => "abc"},
    ]);
  });
} n => 6, name => 'sha256 limited';

Run;

=head1 LICENSE

Copyright 2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
