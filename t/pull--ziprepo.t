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
        type => 'zip',
        file_url => "https://hoge/$key.zip",
        source => {
          type => 'single',
          url => "https://hoge/$key.zip",
        },
      },
    },
    {
      "https://hoge/$key.zip" => {zip => {
        "abc.txt" => {text => "abc", timestamp => 1766890774},
        "xyz.txt" => {text => "xyz"},
      }},
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
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{"file:xyz.txt"};
         {
           my $file = $json->{items}->{"file:abc.txt"};
           is $file->{type}, 'file';
           is $file->{files}->{data}, "files/abc.txt";
           is $file->{rev}->{original_url}, undef;
           is $file->{rev}->{url}, undef;
           is $file->{rev}->{path}, "abc.txt";
           is $file->{rev}->{raw_path}, "abc.txt";
           is $file->{rev}->{path_encoding}, "ibm437";
           is $file->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
           is $file->{rev}->{timestamp}, 1766890774;
           ok ! $file->{rev}->{insecure};
         }
       }},
      {path => "local/data/$key/files/abc.txt", text => "abc",
       XXXtimestamp => 1766890774},
    ]);
  })->then (sub {
    return $current->run ('pull', additional => []);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'second pull';
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{"file:xyz.txt"};
         {
           my $file = $json->{items}->{"file:abc.txt"};
           is $file->{type}, 'file';
           is $file->{files}->{data}, "files/abc.txt";
           is $file->{rev}->{original_url}, undef;
           is $file->{rev}->{url}, undef;
           is $file->{rev}->{path}, "abc.txt";
           is $file->{rev}->{raw_path}, "abc.txt";
           is $file->{rev}->{path_encoding}, "ibm437";
           is $file->{rev}->{sha256}, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
           is $file->{rev}->{timestamp}, 1766890774;
           ok ! $file->{rev}->{insecure};
         }
       }},
      {path => "local/data/$key/files/abc.txt", text => "abc",
       XXXtimestamp => 1766890774},
      {path => $current->repo_path ('single', "https://hoge/$key.zip")->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'single';
         ok my $key = $json->{urls}->{"https://hoge/$key.zip"};
         {
           my $item = $json->{items}->{$key};
           is $item->{type}, 'file';
           ok $item->{files}->{data};
           ok $item->{files}->{extracted};

           my $dir_path = $path->parent->child ($item->{files}->{extracted});
           my $json_path = $dir_path->child ('index.json');
           my $json = json_bytes2perl $json_path->slurp;
           is $json->{type}, 'archive';
           is $json->{paths}->{"abc.txt"}, "file:abc.txt";
           is $json->{raw_paths}->{"abc.txt"}, "file:abc.txt";
           {
             my $item = $json->{items}->{"file:abc.txt"};
             is $item->{type}, 'file';
             ok $item->{files}->{data};
             is $item->{rev}->{url}, undef;
             is $item->{rev}->{original_url}, undef;
             is $item->{rev}->{path}, "abc.txt";
             is $item->{rev}->{raw_path}, "abc.txt";
             is $item->{rev}->{length}, 3;
             is $item->{rev}->{timestamp}, 1766890774;
             is $item->{rev}->{sha256}, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

             my $file_path = $dir_path->child ($item->{files}->{data});
             is $file_path->slurp, "abc";
             is $file_path->stat->mode & 0777, 0444;
           }
         }
       }},
    ]);
  });
} n => 53, name => 'pull';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'zip',
        file_url => "https://hoge/$key.zip",
        source => {
          type => 'single',
          url => "https://hoge/$key.zip",
        },
        files => {"file:xyz.txt" => {skip => 1}},
      },
    },
    {
      "https://hoge/$key.zip" => {zip => {
        "abc.txt" => {text => "abc", timestamp => 1766890774},
        "xyz.txt" => {text => "xyz"},
      }},
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
         ok $json->{items}->{"file:abc.txt"};
       }},
      {path => "local/data/$key/files/abc.txt", text => "abc"},
      {path => $current->repo_path ('single', "https://hoge/$key.zip")->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'single';
         ok my $key = $json->{urls}->{"https://hoge/$key.zip"};
         {
           my $item = $json->{items}->{$key};
           is $item->{type}, 'file';
           ok $item->{files}->{data};
           ok $item->{files}->{extracted};

           my $dir_path = $path->parent->child ($item->{files}->{extracted});
           my $json_path = $dir_path->child ('index.json');
           my $json = json_bytes2perl $json_path->slurp;
           is $json->{type}, 'archive';
           is $json->{paths}->{"abc.txt"}, "file:abc.txt";
           is $json->{paths}->{"xyz.txt"}, undef;
           ok $json->{items}->{"file:abc.txt"};
           is $json->{items}->{"file:xyz.txt"}, undef;
         }
       }},
    ]);
  });
} n => 17, name => 'skip';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'zip',
        file_url => "https://hoge/$key.zip",
        source => {
          type => 'single',
          url => "https://hoge/$key.zip",
        },
        files => {"package" => {skip => 1}},
      },
    },
    {
      "https://hoge/$key.zip" => {zip => {
        "abc.txt" => {text => "abc", timestamp => 1766890774},
        "xyz.txt" => {text => "xyz"},
      }},
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
         is 0+keys %{$json->{items}}, 2;
       }},
      {path => "local/data/$key/files/abc.txt", text => "abc"},
      {path => "local/data/$key/files/xyz.txt", text => "xyz"},
      {path => $current->repo_path ('single', "https://hoge/$key.zip")->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'single';
         ok my $key = $json->{urls}->{"https://hoge/$key.zip"};
         {
           my $item = $json->{items}->{$key};
           is $item->{type}, 'file';
           ok $item->{files}->{data};
           ok $item->{files}->{extracted};

           my $dir_path = $path->parent->child ($item->{files}->{extracted});
           my $json_path = $dir_path->child ('index.json');
           my $json = json_bytes2perl $json_path->slurp;
           is $json->{type}, 'archive';
           ok $json->{items}->{"file:abc.txt"};
           ok $json->{items}->{"file:xyz.txt"};
         }
       }},
    ]);
  });
} n => 15, name => 'package skipped (no effect)';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'zip',
        file_url => "https://hoge/$key.zip",
        source => {
          type => 'single',
          url => "https://hoge/$key.zip",
        },
        files => {"package" => {skip => 1}},
      },
    },
    {
      "https://hoge/$key.zip" => {text => "a"},
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
      {path => $current->repo_path ('single', "https://hoge/$key.zip")->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'single';
         ok my $key = $json->{urls}->{"https://hoge/$key.zip"};
         {
           my $item = $json->{items}->{$key};
           is $item->{type}, 'file';
           ok $item->{files}->{data};
           ok $item->{files}->{extracted};

           my $dir_path = $path->parent->child ($item->{files}->{extracted});
           my $json_path = $dir_path->child ('index.json');
           my $json = json_bytes2perl $json_path->slurp;
           is $json->{type}, 'archive';
           is 0+keys %{$json->{items}}, 0;
         }
       }},
    ]);
  });
} n => 12, name => 'broken file';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'zip',
        file_url => "https://hoge/$key.zip",
        source => {
          type => 'single',
          url => "https://hoge/$key.zip",
        },
      },
    },
    {
      "https://hoge/$key.zip" => {zip => {
        "abc.txt" => {text => "abc", timestamp => 1766890774},
        "xyz.txt" => {text => "abc", timestamp => 1766890774},
      }},
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
        "https://hoge/$key.zip" => {zip => {
          "abc.txt" => {text => "xyz", timestamp => 1766890770},
        }},
      },
    );
  })->then (sub {
    return $current->run ('pull', additional => []);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'second pull';
    return $current->check_files ([
      {path => "local/data/$key/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
         {
           my $file = $json->{items}->{"file:abc.txt"};
           is $file->{type}, 'file';
           is $file->{files}->{data}, "files/abc.txt";
           is $file->{rev}->{original_url}, undef;
           is $file->{rev}->{url}, undef;
           is $file->{rev}->{path}, "abc.txt";
           is $file->{rev}->{raw_path}, "abc.txt";
           is $file->{rev}->{path_encoding}, 'ibm437';
           is $file->{rev}->{sha256}, "3608bca1e44ea6c4d268eb6db02260269892c0b42b86bbf1e77a6fa16c3c9282";
           is $file->{rev}->{timestamp}, 1766890770;
           ok ! $file->{rev}->{insecure};
         }
       }},
      {path => "local/data/$key/files/abc.txt", text => "xyz",
       XXXtimestamp => 1766890770},
      {path => "local/data/$key/files/xyz.txt", is_none => 1},
    ]);
  });
} n => 17, name => 'pull, file changed';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'zip',
        file_url => "https://hoge/$key/hoge.zip",
        source => {
          type => 'single',
          url => "https://hoge/$key/hoge.zip",
        },
        files => {
          "file:abc.txt" => {
            sha256 => "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
          },
        },
      },
    },
    {
      "https://hoge/$key/hoge.zip" => {zip => {
        "abc.txt" => {text => "abc"},
      }},
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
        "https://hoge/$key/hoge.zip" => {zip => {
          "abc.txt" => {text => "xyz"},
        }},
      },
    );
  })->then (sub {
    return $current->run ('pull', additional => []);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/$key/files/abc.txt", is_none => 1},
    ]);
  });
} n => 5, name => 'sha256 limited';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'zip',
        file_url => "https://hoge/$key/hoge.zip",
        source => {
          type => 'single',
          url => "https://hoge/$key/hoge.zip",
        },
      },
    },
    {
      "https://hoge/$key/hoge.zip" => {zip => {
        "abc.txt" => {text => "abc"},
      }},
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
        "https://hoge/$key/hoge.zip" => {zip => {
          "abc.txt" => {text => "xyz"},
        }},
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
      {path => "local/data/$key/files/abc.txt", text => "xyz"},
    ]);
  });
} n => 6, name => 'single > zip';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'zip',
        file_url => "https://hoge/$key/hoge.zip",
        source => {
          type => 'ckan',
          url => "https://hoge/dataset/$key",
        },
      },
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [
            {id => 'hoge', url => "https://hoge/$key/hoge.zip"},
            {id => 'foo', url => "https://hoge/$key/foo.txt"},
          ],
        }},
      },
      "https://hoge/$key/hoge.zip" => {zip => {
        "abc.txt" => {text => "abc"},
      }},
      "https://hoge/$key/foo.txt" => {text => "a"},
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
        "https://hoge/$key/hoge.zip" => {zip => {
          "abc.txt" => {text => "xyz"},
        }},
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
      {path => "local/data/$key/files/abc.txt", text => "xyz"},
      {path => $current->repo_path ('ckan', "https://hoge/dataset/$key")->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         ok $json->{urls}->{"https://hoge/$key/hoge.zip"};
         ok not $json->{urls}->{"https://hoge/$key/foo.txt"};
       }},
    ]);
  });
} n => 8, name => 'ckan > zip';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      "p1" => {
        type => 'zip',
        file_url => "https://hoge/$key/hoge.zip",
        source => {
          type => 'ckan',
          url => "https://hoge/dataset/$key",
        },
      },
      "p2" => {
        type => 'zip',
        file_url => "https://hoge/$key/fuga.zip",
        source => {
          type => 'ckan',
          url => "https://hoge/dataset/$key",
        },
      },
      "p3" => {
        type => 'zip',
        file_url => "https://hoge/$key/hoge.zip",
        source => {
          type => 'ckan',
          url => "https://hoge/dataset/$key",
        },
      },
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [
            {id => 'hoge', url => "https://hoge/$key/hoge.zip"},
            {id => 'fuga', url => "https://hoge/$key/fuga.zip"},
          ],
        }},
      },
      "https://hoge/$key/hoge.zip" => {zip => {
        "abc.txt" => {text => "abc"},
      }},
      "https://hoge/$key/fuga.zip" => {zip => {
        "xyz.txt" => {text => "xyz"},
      }},
    },
  )->then (sub {
    return $current->run ('pull', additional => []);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/p1/files/abc.txt", text => "abc"},
      {path => "local/data/p2/files/xyz.txt", text => "xyz"},
      {path => "local/data/p3/files/abc.txt", text => "abc"},
    ]);
  });
} n => 5, name => 'ckan > zip files';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      $key => {
        type => 'zip',
        file_path => "fuga.zip",
        source => {
          type => 'zip',
          file_url => "https://hoge/$key/hoge.zip",
          source => {
            type => 'ckan',
            url => "https://hoge/dataset/$key",
          },
        },
      },
    },
    {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {success => \1, result => {
          resources => [
            {id => 'hoge', url => "https://hoge/$key/hoge.zip"},
          ],
        }},
      },
      "https://hoge/$key/hoge.zip" => {zip => {
        "fuga.zip" => {zip => {
          "abc.txt" => {text => "abc"},
        }},
      }},
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
  });
} n => 3, name => 'ckan > zip > zip';

Run;

=head1 LICENSE

Copyright 2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
