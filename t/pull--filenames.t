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
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "https://hoge/" . $key . "/r3"},
              {id => "r4", url => "https://hoge/" . $key . "/r4"},
              {id => "r5", url => "https://hoge/" . $key . "/r5"},
              {id => "r6", url => "https://hoge/" . $key . "/r6"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {
        text => "r1",
        headers => {'content-disposition' => 'inline; filename=foo.txt'},
      },
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {
        text => "r3",
        headers => {'content-disposition' => 'attachment; filename=r3.txt'},
      },
      "https://hoge/" . $key . "/r4" => {
        text => "r4",
        headers => {'content-disposition' => 'attachment;FILENAME=r4.txt'},
      },
      "https://hoge/" . $key . "/r5" => {
        text => "r5",
        headers => {'content-disposition' => 'xyz;notfilename=abc;filename=r5.txt;abc'},
      },
      "https://hoge/" . $key . "/r6" => {
        text => "r6",
        headers => {'content-disposition' => 'attachment;filename="r6.txt"'},
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         {
           my $item = $json->{items}->{'file:id:r1'};
           is $item->{rev}->{mime_filename}, 'foo.txt';
         }
         {
           my $item = $json->{items}->{'file:id:r2'};
           is $item->{rev}->{mime_filename}, undef;
         }
       }},
      {path => 'local/data/foo/files/r1', is_none => 1},
      {path => 'local/data/foo/files/foo.txt', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3.txt', text => "r3"},
      {path => 'local/data/foo/files/r4.txt', text => "r4"},
      {path => 'local/data/foo/files/r5.txt', text => "r5"},
      {path => 'local/data/foo/files/r6.txt', text => "r6"},
    ]);
  });
} n => 10, name => 'filename specified';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "https://hoge/" . $key . "/r3"},
              {id => "r4", url => "https://hoge/" . $key . "/r4"},
              {id => "r5", url => "https://hoge/" . $key . "/r5"},
              {id => "r6", url => "https://hoge/" . $key . "/r6"},
              {id => "r7", url => "https://hoge/" . $key . "/r7"},
              {id => "r8", url => "https://hoge/" . $key . "/r8"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {
        text => "r1",
        headers => {'content-disposition' => 'inline; filename=foo.txt'},
      },
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {
        text => "r3",
        headers => {'content-disposition' => 'attachment; filename='},
      },
      "https://hoge/" . $key . "/r4" => {
        text => "r4",
        headers => {'content-disposition' => 'attachment; filename=ho\\ge'},
      },
      "https://hoge/" . $key . "/r5" => {
        text => "r5",
        headers => {'content-disposition' => 'attachment; filename=fo"fo'},
      },
      "https://hoge/" . $key . "/r6" => {
        text => "r6",
        headers => {'content-disposition' => 'attachment;filename=a/b/c'},
      },
      "https://hoge/" . $key . "/r7" => {
        text => "r7",
        headers => {'content-disposition' => 'attachment;filename=;'},
      },
      "https://hoge/" . $key . "/r8" => {
        text => "r8",
        headers => {'content-disposition' => 'attachment;filename=""'},
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         {
           my $item = $json->{items}->{'file:id:r1'};
           is $item->{rev}->{mime_filename}, 'foo.txt';
         }
         {
           my $item = $json->{items}->{'file:id:r2'};
           is $item->{rev}->{mime_filename}, undef;
         }
         {
           my $item = $json->{items}->{'file:id:r4'};
           is $item->{rev}->{mime_filename}, 'ho';
         }
         {
           my $item = $json->{items}->{'file:id:r5'};
           is $item->{rev}->{mime_filename}, 'fo';
         }
         {
           my $item = $json->{items}->{'file:id:r6'};
           is $item->{rev}->{mime_filename}, 'a/b/c';
         }
       }},
      {path => 'local/data/foo/files/r1', is_none => 1},
      {path => 'local/data/foo/files/foo.txt', text => "r1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', text => "r3"},
      {path => 'local/data/foo/files/r4', is_none => 1},
      {path => 'local/data/foo/files/ho', text => "r4"},
      {path => 'local/data/foo/files/r5', is_none => 1},
      {path => 'local/data/foo/files/fo', text => "r5"},
      {path => 'local/data/foo/files/r6', is_none => 1},
      {path => 'local/data/foo/files/c', text => "r6"},
      {path => 'local/data/foo/files/r7', text => "r7"},
      {path => 'local/data/foo/files/r8', text => "r8"},
    ]);
  });
} n => 15, name => 'bad filename specified';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1",
               name => "abc\x{4000}.zip"},
              {id => "r2", url => "https://hoge/" . $key . "/r2",
               name => "abc\x{4000}.ZIP"},
              {id => "r3", url => "https://hoge/" . $key . "/r3",
               name => "abc\x{4000}.zip"},
              {id => "r4", url => "https://hoge/" . $key . "/r4",
               name => "abc/def.zip"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {
        text => "r1",
        headers => {'content-disposition' => 'inline; filename=foo.txt'},
        mime => 'application/zip',
      },
      "https://hoge/" . $key . "/r2" => {
        text => "r2",
        mime => 'application/zip',
      },
      "https://hoge/" . $key . "/r3" => {
        text => "r3",
        mime => 'text/css',
      },
      "https://hoge/" . $key . "/r4" => {
        text => "r4",
        mime => 'application/zip',
      },
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/files/foo.txt', text => "r1"},
      {path => "local/data/foo/files/abc\x{4000}.ZIP", text => "r2"},
      {path => 'local/data/foo/files/r3', text => "r3"},
      {path => 'local/data/foo/files/def.zip', text => "r4"},
    ]);
  });
} n => 6, name => 'filename in ckan title';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
