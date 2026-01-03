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
        "abc.txt" => {text => "abc"},
      }},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
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
      {path => "local/data/$key/LICENSE", file => 1},
      {path => "local/data/$key/files/abc.txt", is_none => 1},
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         ok $json->{$key};
         {
           my $item = $json->{$key};
           is $item->{type}, 'zip';
           is $item->{source}->{type}, 'single';
           is $item->{source}->{url}, "https://hoge/$key.zip";
           is $item->{file_url}, "https://hoge/$key.zip";
           is 0+keys %{$item->{files}}, 1;
           ok $item->{files}->{"file:abc.txt"}->{skip};
         }
       }},
    ]);
  });
} n => 13, name => 'ok';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc.txt" => {text => "abc"},
      }},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip", '--min']);
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
      {path => "local/data/$key/LICENSE", file => 1},
      {path => "local/data/$key/files/abc.txt", is_none => 1},
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         ok $json->{$key};
         {
           my $item = $json->{$key};
           is $item->{type}, 'zip';
           is $item->{source}->{type}, 'single';
           is $item->{source}->{url}, "https://hoge/$key.zip";
           is $item->{file_url}, "https://hoge/$key.zip";
           is 0+keys %{$item->{files}}, 1;
           ok $item->{files}->{"file:abc.txt"}->{skip};
         }
       }},
    ]);
  });
} n => 13, name => '--min';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {text => "a", mime => "application/zip"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
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
      {path => "local/data/$key/LICENSE", file => 1},
      {path => "local/data/$key/files/abc.txt", is_none => 1},
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         ok $json->{$key};
         {
           my $item = $json->{$key};
           is $item->{type}, 'zip';
           is $item->{source}->{type}, 'single';
           is $item->{source}->{url}, "https://hoge/$key.zip";
           is $item->{file_url}, "https://hoge/$key.zip";
           is 0+keys %{$item->{files}}, 0;
         }
       }},
    ]);
  });
} n => 12, name => 'broken zip';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key" => {zip => {
        "abc.txt" => {text => "abc"},
      }},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         ok $json->{$key};
         {
           my $item = $json->{$key};
           is $item->{type}, 'zip';
           is $item->{source}->{type}, 'single';
           is $item->{source}->{url}, "https://hoge/$key";
         }
       }},
    ]);
  });
} n => 6, name => 'data_area_key 1';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key/" => {zip => {
        "abc.txt" => {text => "abc"},
      }},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key/"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         is 0+keys %$json, 1;
         {
           my $item = [values %$json]->[0];
           is $item->{type}, 'zip';
           is $item->{source}->{type}, 'single';
           is $item->{source}->{url}, "https://hoge/$key/";
         }
       }},
    ]);
  });
} n => 6, name => 'data_area_key 2';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc.txt" => {text => "abc"},
      }, mime => "application/zip; name=foo"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         ok $json->{$key};
         {
           my $item = [values %$json]->[0];
           is $item->{type}, 'zip';
           is $item->{source}->{type}, 'single';
           is $item->{source}->{url}, "https://hoge/$key.zip";
         }
       }},
    ]);
  });
} n => 6, name => 'mime type 1';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc.txt" => {text => "abc"},
      }, mime => "application/x-zip-compressed"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         ok $json->{$key};
         {
           my $item = [values %$json]->[0];
           is $item->{type}, 'zip';
           is $item->{source}->{type}, 'single';
           is $item->{source}->{url}, "https://hoge/$key.zip";
         }
       }},
    ]);
  });
} n => 6, name => 'mime type 2';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc.txt" => {text => "abc"},
      }, mime => "application/OCTET-stream"},
    },
  )->then (sub {
    return $current->run ('add', additional => ["https://hoge/$key.zip"]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         ok $json->{$key};
         {
           my $item = [values %$json]->[0];
           is $item->{type}, 'zip';
           is $item->{source}->{type}, 'single';
           is $item->{source}->{url}, "https://hoge/$key.zip";
         }
       }},
    ]);
  });
} n => 6, name => 'mime type 3';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    undef,
    {
      "https://hoge/$key.zip" => {zip => {
        "abc.txt" => {text => "abc"},
      }},
    },
  )->then (sub {
    return $current->run ('add', additional => [
      "https://hoge/$key.zip", '--min',
      '--forced-encoding', "abcEfe-ewge",
      '--forced-tzoffset', -46364.433,
    ]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "config/ddsd/packages.json", json => sub {
         my $json = shift;
         ok $json->{$key};
         {
           my $item = $json->{$key};
           is $item->{type}, 'zip';
           is $item->{forced_encoding}, "abcEfe-ewge";
           is $item->{forced_tzoffset}, -46364.433;
         }
       }},
    ]);
  });
} n => 6, name => '--forced-*';

Run;

=head1 LICENSE

Copyright 2025-2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
