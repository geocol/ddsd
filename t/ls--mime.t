use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  use utf8;
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      $key => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/dataset/$key" => {
        text => qq{abc},
      },
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [
            {id => "r1", url => "https://hoge/$key/r1",
             mimetype => "application/zip", format => "BVF"},
            {id => "r2", url => "https://hoge/$key/r2.ai",
             mimetype => "application/postscript",
             format => "application/postscript"},
            {id => "r3", url => "https://hoge/$key/r3.ai",
             mimetype => "application/postscript", format => "ai"},
            {id => "r4", url => "https://hoge/$key/r4.ai",
             mimetype => "application/postscript", format => "ai"},
            {id => "r5", url => "https://hoge/$key/r5",
             mimetype => "text/csv", format => "CSV"},
            {id => "r6", url => "https://hoge/$key/r6",
             mimetype => "text/csv", format => "CSV"},
            {id => "r7", url => "https://hoge/$key/r7",
             mimetype => "text/csv", format => "CSV"},
            {id => "r8", url => "https://hoge/$key/r8",
             format => "CSV"},
            {id => "r9", url => "https://hoge/$key/r9",
             mimetype => "text/csv", format => ".csv"},
            {id => "r10", url => "https://hoge/$key/r10",
             mimetype => "application/vnd.dbf", format => "dBase"},
            {id => "r11", url => "https://hoge/$key/r11",
             mimetype => "application/vnd.oma.drm.message",
             format => "application/vnd.oma.drm.message"},
            {id => "r12", url => "https://hoge/$key/r12", format => "dm"},
            {id => "r13", url => "https://hoge/$key/r13",
             format => "image/vnd.dxf"},
            {id => "r14", url => "https://hoge/$key/r14",
             format => "dxf", mimetype => "image/vnd.dxf"},
            {id => "r15", url => "https://hoge/$key/r15",
             format => "XLSX", mimetype => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"},
            {id => "r16", url => "https://hoge/$key/r16",
             format => "ｘｌｓｘ"},
            {id => "r17", url => "https://hoge/$key/r17",
             format => "XLSX", mimetype => "application/vnd.ms-excel"},
            {id => "r18", url => "https://hoge/$key/r18",
             format => "XLSX", mimetype => "application/zip"},
            {id => "r19", url => "https://hoge/$key/r19",
             format => "XLS", mimetype => "application/vnd.ms-excel"},
            {id => "r20", url => "https://hoge/$key/r20",
             format => "GeoJSON", mimetype => "application/geo+json"},
            {id => "r21", url => "https://hoge/$key/r21",
             format => "GeoJSON", mimetype => "application/json"},
            {id => "r22", url => "https://hoge/$key/r22", format => "GeoJSON"},
            {id => "r23", url => "https://hoge/$key/r23", format => "JSON"},
            {id => "r24", url => "https://hoge/$key/r24", format => "JSON"},
            {id => "r25", url => "https://hoge/$key/r25", format => "HTML"},
            {id => "r26", url => "https://hoge/$key/r26", format => "TXT"},
            {id => "r27", url => "https://hoge/$key/r27", format => "ZIP"},
            {id => "r28", url => "https://hoge/$key/r28", format => "ZIP"},
          ],
        }},
      },
      "https://hoge/$key/r1" => {
        text => "a", mime => "application/zip",
      },
      "https://hoge/$key/r2.ai" => {
        text => "a", mime => "application/postscript",
      },
      "https://hoge/$key/r3.ai" => {
        text => "a", mime => "application/postscript",
      },
      "https://hoge/$key/r4.ai" => {
        text => "a", mime => "text/html",
      },
      "https://hoge/$key/r5" => {
        text => "a", mime => "text/csv",
      },
      "https://hoge/$key/r6" => {
        text => "a", mime => "text/csv; charset=UTF-8",
      },
      "https://hoge/$key/r7" => {
        text => "a", mime => "application/octet-stream",
      },
      "https://hoge/$key/r8" => {
        text => "a", mime => "application/octet-stream",
      },
      "https://hoge/$key/r9" => {
        text => "a", mime => "application/octet-stream",
      },
      "https://hoge/$key/r10" => {
        text => "a", mime => "application/octet-stream",
      },
      "https://hoge/$key/r11" => {
        text => "a", mime => "application/vnd.oma.drm.message",
      },
      "https://hoge/$key/r12" => {
        text => "a", mime => "application/octet-stream",
      },
      "https://hoge/$key/r13" => {
        text => "a", mime => "application/octet-stream",
      },
      "https://hoge/$key/r14" => {
        text => "a", mime => "image/vnd.dxf",
      },
      "https://hoge/$key/r15" => {
        text => "a", mime => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      },
      "https://hoge/$key/r16" => {
        text => "a", mime => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      },
      "https://hoge/$key/r17" => {
        text => "a", mime => "application/octet-stream",
      },
      "https://hoge/$key/r18" => {
        text => "a", mime => "application/octet-stream",
      },
      "https://hoge/$key/r19" => {
        text => "a", mime => "application/vnd.ms-excel",
      },
      "https://hoge/$key/r20" => {
        text => "a", mime => "application/geo+json",
      },
      "https://hoge/$key/r21" => {
        text => "a", mime => "application/json",
      },
      "https://hoge/$key/r22" => {
        text => "a", mime => "application/json; charset=UTF-8",
      },
      "https://hoge/$key/r23" => {
        text => "a", mime => "application/json",
      },
      "https://hoge/$key/r24" => {
        text => "a", mime => "application/json;charset=utf-8",
      },
      "https://hoge/$key/r25" => {
        text => "a", mime => "text/html",
      },
      "https://hoge/$key/r26" => {
        text => "a", mime => "text/plain",
      },
      "https://hoge/$key/r27" => {
        text => "a", mime => "application/zip",
      },
      "https://hoge/$key/r28" => {
        text => "a", mime => "application/octet-stream",
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
      { # r1
        my $item = $r->{jsonl}->[3];
        is $item->{package_item}->{mime}, 'application/bvf+zip';
      }
      { # r2
        my $item = $r->{jsonl}->[4];
        is $item->{package_item}->{mime}, 'application/illustrator';
      }
      { # r3
        my $item = $r->{jsonl}->[5];
        is $item->{package_item}->{mime}, 'application/illustrator';
      }
      { # r4
        my $item = $r->{jsonl}->[6];
        is $item->{package_item}->{mime}, 'text/html';
      }
      { # r5
        my $item = $r->{jsonl}->[7];
        is $item->{package_item}->{mime}, 'text/csv';
      }
      { # r6
        my $item = $r->{jsonl}->[8];
        is $item->{package_item}->{mime}, 'text/csv; charset=utf-8';
      }
      { # r7
        my $item = $r->{jsonl}->[9];
        is $item->{package_item}->{mime}, 'text/csv';
      }
      { # r8
        my $item = $r->{jsonl}->[10];
        is $item->{package_item}->{mime}, 'text/csv';
      }
      { # r9
        my $item = $r->{jsonl}->[11];
        is $item->{package_item}->{mime}, 'text/csv';
      }
      { # r10
        my $item = $r->{jsonl}->[12];
        is $item->{package_item}->{mime}, 'application/vnd.dbf';
      }
      { # r11
        my $item = $r->{jsonl}->[13];
        is $item->{package_item}->{mime}, 'application/dm';
      }
      { # r12
        my $item = $r->{jsonl}->[14];
        is $item->{package_item}->{mime}, 'application/dm';
      }
      { # r13
        my $item = $r->{jsonl}->[15];
        is $item->{package_item}->{mime}, 'image/vnd.dxf';
      }
      { # r14
        my $item = $r->{jsonl}->[16];
        is $item->{package_item}->{mime}, 'image/vnd.dxf';
      }
      { # r15
        my $item = $r->{jsonl}->[17];
        is $item->{package_item}->{mime}, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }
      { # r16
        my $item = $r->{jsonl}->[18];
        is $item->{package_item}->{mime}, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }
      { # r17
        my $item = $r->{jsonl}->[19];
        is $item->{package_item}->{mime}, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }
      { # r18
        my $item = $r->{jsonl}->[20];
        is $item->{package_item}->{mime}, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }
      { # r19
        my $item = $r->{jsonl}->[21];
        is $item->{package_item}->{mime}, 'application/vnd.ms-excel';
      }
      { # r20
        my $item = $r->{jsonl}->[22];
        is $item->{package_item}->{mime}, 'application/geo+json';
      }
      { # r21
        my $item = $r->{jsonl}->[23];
        is $item->{package_item}->{mime}, 'application/geo+json';
      }
      { # r22
        my $item = $r->{jsonl}->[24];
        is $item->{package_item}->{mime}, 'application/geo+json';
      }
      { # r23
        my $item = $r->{jsonl}->[25];
        is $item->{package_item}->{mime}, 'application/json';
      }
      { # r24
        my $item = $r->{jsonl}->[26];
        is $item->{package_item}->{mime}, 'application/json';
      }
      { # r25
        my $item = $r->{jsonl}->[27];
        is $item->{package_item}->{mime}, 'text/html';
      }
      { # r26
        my $item = $r->{jsonl}->[28];
        is $item->{package_item}->{mime}, 'text/plain';
      }
      { # r27
        my $item = $r->{jsonl}->[29];
        is $item->{package_item}->{mime}, 'application/zip';
      }
      { # r28
        my $item = $r->{jsonl}->[30];
        is $item->{package_item}->{mime}, 'application/zip';
      }
    } $current->c;
  });
} n => 30, name => 'fixed mime types';

Test {
  use utf8;
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      $key => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/dataset/$key" => {
        text => qq{abc},
      },
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [
            {id => "r1", url => "https://hoge/$key/r1"},
          ],
        }},
      },
      "https://hoge/$key/r1" => {
        text => "a", mime => "application/octet-stream",
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
      { # r1
        my $item = $r->{jsonl}->[3];
        is $item->{package_item}->{mime}, 'application/octet-stream';
      }
    } $current->c;
  });
} n => 3, name => 'no mime info';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      $key => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/dataset/$key" => {
        text => qq{abc},
      },
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [
            {id => "r1", url => "https://hoge/$key/r1",
             name => "hoge.xlsx"},
          ],
        }},
      },
      "https://hoge/$key/r1" => {
        text => "a", mime => "application/octet-stream",
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
      { # r1
        my $item = $r->{jsonl}->[3];
        is $item->{package_item}->{mime}, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }
    } $current->c;
  });
} n => 3, name => 'no mime info but ext 1';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      $key => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/dataset/$key" => {
        text => qq{abc},
      },
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [
            {id => "r1", url => "https://hoge/$key/r1",
             name => "hoge.XLSX"},
          ],
        }},
      },
      "https://hoge/$key/r1" => {
        text => "a", mime => "application/octet-stream",
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
      { # r1
        my $item = $r->{jsonl}->[3];
        is $item->{package_item}->{mime}, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }
    } $current->c;
  });
} n => 3, name => 'no mime info but ext 2';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      $key => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/dataset/$key" => {
        text => qq{abc},
      },
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [
            {id => "r1", url => "https://hoge/$key/r1",
             name => "hoge.json"},
          ],
        }},
      },
      "https://hoge/$key/r1" => {
        text => "a", mime => "application/octet-stream",
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
      { # r1
        my $item = $r->{jsonl}->[3];
        is $item->{package_item}->{mime}, 'application/json';
      }
    } $current->c;
  });
} n => 3, name => 'no mime info but ext 3';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      $key => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/dataset/$key" => {
        text => qq{abc},
      },
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [
            {id => "r1", url => "https://hoge/$key/r1"},
          ],
        }},
      },
      "https://hoge/$key/r1" => {
        text => "a", mime => "application/x-zip-compressed",
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
      { # r1
        my $item = $r->{jsonl}->[3];
        is $item->{package_item}->{mime}, 'application/zip';
      }
    } $current->c;
  });
} n => 3, name => 'normalization, zip';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      $key => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
      },
    },
    {
      "https://hoge/dataset/$key" => {
        text => qq{abc},
      },
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [
            {id => "r1", url => "https://hoge/$key/r1"},
          ],
        }},
      },
      "https://hoge/$key/r1" => {
        text => "a", mime => "TEXT/csv;Charset=utF-8",
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
      { # r1
        my $item = $r->{jsonl}->[3];
        is $item->{package_item}->{mime}, 'text/csv; charset=utf-8';
      }
    } $current->c;
  });
} n => 3, name => 'normalization, case and charset';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
