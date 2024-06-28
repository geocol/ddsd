use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

for my $args (
  [],
  ['foo'],
  ['foo', 'bar'],
  ['a', 'b', 'c', 'd'],
  ['unknown', 'a', 'b'],
  ['mirrorzip', '', 'out.zip'],
  ['mirrorzip', 'norepo', 'out.zip'],
) {
  Test {
    my $current = shift;
    my $key = rand;
    return $current->prepare (undef, {})->then (sub {
      return $current->run ('export', additional => $args);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'config', is_none => 1},
        {path => 'local', is_none => 1},
      ]);
    });
  } n => 3, name => ['bad args', @$args];
}

Test {
  my $current = shift;
  my $key = "0geEGr42rewe44t24442";
  return $current->prepare ({
    hoge => {
      type => 'ckan',
      url => "https://hoge/dataset/$key",
    },
  }, {
    "https://hoge/dataset/$key" => {
      text => "x",
    },
    "https://hoge/dataset/activity/$key" => {
      text => "y",
    },
    "https://hoge/api/action/package_show?id=$key" => {
      text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc.txt"}]}} },
    },
    "https://hoge/$key/abc.txt" => {
      text => "abc",
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->run ('export', additional => ['mirrorzip', 'hoge', 'foo.zip']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "foo.zip", zip => sub {
         my $files = shift;
         ok $files->{"index.json"}->{size};
         ok $files->{"LICENSE"}->{size};
         is $files->{'data/0a22797ed8f2d36d6f31b5f55874223e7ff098496b211551d8b729b93ba864f0.dat'}->{size}, 100;
         is $files->{'data/a1fce4363854ff888cff4b8e7875d600c2682390412a8cf79b37d0b11148b0fa.dat'}->{size}, 1;
       }},
      {path => ["foo.zip", "index.json"], json => sub {
         my $json = shift;
         is $json->{type}, 'mirrorzip';
         is 0+keys %{$json->{items}}, 3;
         is $json->{items}->{package}->{files}->{data}, "data/0a22797ed8f2d36d6f31b5f55874223e7ff098496b211551d8b729b93ba864f0.dat";
         like $json->{items}->{package}->{files}->{meta}, qr{^meta/.+\.json$};
         is $json->{items}->{"package:activity.html"}->{files}->{data}, "data/a1fce4363854ff888cff4b8e7875d600c2682390412a8cf79b37d0b11148b0fa.dat";
         like $json->{items}->{"package:activity.html"}->{files}->{meta}, qr{^meta/.+\.json$};
         is $json->{items}->{"file:index:0"}->{files}->{data}, "data/ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad.dat";
         like $json->{items}->{"file:index:0"}->{files}->{meta}, qr{^meta/.+\.json$};
         is $json->{items}->{"file:index:0"}->{rev}->{url}, "https://hoge/$key/abc.txt";
         is 0+@{$json->{legal}->{legal}}, 2;
         is $json->{legal}->{is_free}, 'unknown';
         is $json->{legal}->{legal}->[0]->{key}, '-ddsd-unknown';
         is $json->{legal}->{legal}->[1]->{key}, '-ddsd-disclaimer';
       }},
      {path => ["foo.zip", "data/ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad.dat"], text => "abc"},
    ]);
  });
} n => 20, name => 'zip created';

Test {
  my $current = shift;
  my $key = "0geEGr42rewe44t24445";
  return $current->prepare ({
    hoge => {
      type => 'ckan',
      url => "https://hoge/dataset/$key",
    },
  }, {
    "https://hoge/dataset/$key" => {
      text => "x",
    },
    "https://hoge/dataset/activity/$key" => {
      text => "y",
    },
    "https://hoge/api/action/package_show?id=$key" => {
      text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc.txt"}]}} },
    },
    "https://hoge/$key/abc.txt" => {
      text => "abc",
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->run ('export', additional => ['mirrorzip', 'hoge', 'foo.zip', '--json'], json => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      ok $r->{json}->{length};
      ok $r->{json}->{sha256};
    } $current->c;
    return $current->check_files ([
      {path => "foo.zip", zip => sub {
         my $files = shift;
         ok $files->{"index.json"}->{size};
         ok $files->{"LICENSE"}->{size};
       }},
      {path => ["foo.zip", "index.json"], json => sub {
         my $json = shift;
         is $json->{type}, 'mirrorzip';
         is 0+keys %{$json->{items}}, 3;
         is $json->{items}->{"file:index:0"}->{rev}->{url}, "https://hoge/$key/abc.txt";
         is 0+@{$json->{legal}->{legal}}, 2;
         is $json->{legal}->{is_free}, 'unknown';
         is $json->{legal}->{legal}->[0]->{key}, '-ddsd-unknown';
         is $json->{legal}->{legal}->[1]->{key}, '-ddsd-disclaimer';
       }},
    ]);
  });
} n => 10, name => 'zip created, --json';

Test {
  my $current = shift;
  my $key = "0geEGr42rewe44t2ge4442";
  return $current->prepare ({
    hoge => {
      type => 'ckan',
      url => "https://hoge/dataset/$key",
    },
  }, {
    "https://hoge/dataset/$key" => {
      text => "x",
    },
    "https://hoge/dataset/activity/$key" => {
      text => "y",
    },
    "https://hoge/api/action/package_show?id=$key" => {
      text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc.txt"}]}} },
    },
    "https://hoge/$key/abc.txt" => {
      text => "abc",
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->run ('export', additional => ['mirrorzip', 'hoge', '']);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
      isnt $r->{exit_code}, 12;
    } $current->c;
  });
} n => 2, name => 'bad export file';

Test {
  my $current = shift;
  my $key = "0geEGr42rewe44t2444223";
  return $current->prepare ({
    hoge => {
      type => 'ckan',
      url => "https://hoge/dataset/$key",
    },
  }, {
    "https://hoge/dataset/$key" => {
      text => "x",
    },
    "https://hoge/dataset/activity/$key" => {
      text => "y",
    },
    "https://hoge/api/action/package_show?id=$key" => {
      text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc.txt"}]}} },
    },
    "https://hoge/$key/abc.txt" => {
      text => "abc",
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->run ('export', additional => ['mirrorzip', 'hoge', 'foo/bar.zip']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "foo/bar.zip", zip => sub {
         my $files = shift;
         ok $files->{"index.json"}->{size};
         ok $files->{"LICENSE"}->{size};
       }},
    ]);
  });
} n => 4, name => 'new directory';

Test {
  my $current = shift;
  my $key = "0geEGr42rewe4464Gee4442";
  return $current->prepare ({
    hoge => {
      type => 'ckan',
      url => "https://hoge/dataset/$key",
    },
    hoge2 => {
      type => 'ckan',
      url => "https://hoge/dataset/2$key",
    },
  }, {
    "https://hoge/dataset/$key" => {
      text => "x",
    },
    "https://hoge/dataset/activity/$key" => {
      text => "y",
    },
    "https://hoge/api/action/package_show?id=$key" => {
      text => qq{ {"success": true, "result": {"resources": [{"url": "https://hoge/$key/abc.txt"}]}} },
    },
    "https://hoge/api/action/package_show?id=2$key" => {
      text => qq{ {"success": true, "result": {} }},
    },
    "https://hoge/$key/abc.txt" => {
      text => "abc",
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->run ('export', additional => ['mirrorzip', 'hoge2', 'foo/bar.zip']);
  })->then (sub {
    return $current->run ('export', additional => ['mirrorzip', 'hoge', 'foo/bar.zip']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "foo/bar.zip", zip => sub {
         my $files = shift;
         ok $files->{"index.json"}->{size};
         ok $files->{"LICENSE"}->{size};
         is $files->{'data/a1fce4363854ff888cff4b8e7875d600c2682390412a8cf79b37d0b11148b0fa.dat'}->{size}, 1;
       }},
    ]);
  });
} n => 5, name => 'override';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
