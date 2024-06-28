use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

for my $in (
  {json => {
    success => \1,
    result => [],
  }},
  {json => {
    success => \0,
    result => {},
  }},
  {json => {
    result => {},
  }},
  {json => {
    success => \1,
    result => "abc",
  }},
  {json => {
    success => \1,
  }},
  {json => {}},
  {json => []},
  {json => "abc"},
  {json => 12.3},
  {json => \1},
  {json => undef},
  {text => "abc"},
  {text => "{"},
  {text => ""},
) {
  Test {
    my $current = shift;
    my $key = rand;
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://hoge/dataset/package-name-' . $key,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => $in,
      },
    )->then (sub {
      return $current->run ('pull', insecure => 1);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
      } $current->c;
      return $current->check_files ([
        {path => 'local/data/foo/index.json', json => sub {
           my $json = shift;
           is 0+keys %{$json->{items}}, 1;
         }},
      ]);
    });
  } n => 3, name => 'broken packages';
} # $in

for my $in (
  {
    json => {success => \1, result => {}},
  },
  {
    json => {success => \1, result => {
      resources => [],
    }},
  },
  {
    json => {success => \1, result => {
      resources => "abc",
    }},
  },
  {
    json => {success => \1, result => {
      resources => undef,
    }},
  },
  {
    json => {success => \1, result => {
      resources => "",
    }},
  },
  {
    json => {success => \1, result => {
      resources => [
        [],
      ],
    }},
  },
  {
    json => {success => \1, result => {
      resources => [
        "",
      ],
    }},
  },
  {
    json => {success => \1, result => {
      resources => [
        124,
      ],
    }},
  },
) {
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://hoge/dataset/package-name-' . $key,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => $in,
      },
    )->then (sub {
      return $current->run ('pull', insecure => 1);
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 0;
      } $current->c;
      return $current->check_files ([
        {path => 'local/data/foo/index.json', json => sub {
           my $json = shift;
           is $json->{type}, 'datasnapshot';
           is ref $json->{items}, 'HASH';
           is 0+keys %{$json->{items}}, 1;
         }},
      ]);
    });
  } n => 5, name => 'empty packages';
} # $in

for my $in (
  {json => {
    success => \1,
    result => {},
  }, status => 404},
  {text => "", status => 304},
  {json => {
    success => \1,
    result => {},
  }, status => 500},
  {json => {
    success => \1,
    result => {},
  }, status => 201},
  {json => {
    success => \1,
    result => {},
  }, status => 206},
  {json => {
    success => \1,
    result => {},
  }, mime => 'application/jsonnot', y => 1},
  {json => {
    success => \1,
    result => {},
  }, mime => 'text/json', y => 1},
  {json => {
    success => \1,
    result => {},
  }, mime => '', x => 1},
  {json => {
    success => \1,
    result => {},
  }, mime => ' ', x => 1},
) {
  Test {
    my $current = shift;
    my $key = rand;
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://hoge/dataset/package-name-' . $key,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => $in,
      },
    )->then (sub {
      return $current->run ('pull', insecure => 1);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, $in->{x} ? 2 : 0;
      } $current->c;
      return $current->check_files ([
        {path => 'local/data/foo/package-ckan.json', json => sub { },
         is_none => $in->{status} || $in->{y}},
        {path => 'local/data/foo/index.json', json => sub {
           my $json = shift;
           if ($in->{status} or $in->{y}) {
             is $json->{items}->{'package'}, undef;
           } else {
             ok $json->{items}->{package};
           }
         }},
      ]);
    });
  } n => 3, name => ['broken response', %$in];
} # $in

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://Hoge/dataset/package-name-' . $key,
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         ok $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key};
         $current->set_o (head1 => $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key});
         is 0+keys %{$json->{items}}, 1;
         my $item = $json->{items}->{$json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}};
         ok $item->{files}->{meta};
         ok $item->{files}->{data};
         is $item->{type}, 'package';
         my $meta_path = $path->parent->child ($item->{files}->{meta});
         my $meta = json_bytes2perl $meta_path->slurp;
         is $meta->{rev}->{url}, "http://hoge/api/action/package_show?id=package-name-" . $key;
         is $meta->{rev}->{original_url}, "http://hoge/api/action/package_show?id=package-name-" . $key;
         ok $meta->{rev}->{sha256};
         is $json->{url_sha256s}->{"http://hoge/api/action/package_show?id=package-name-" . $key, $meta->{rev}->{sha256}}, $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key};
         is $meta->{rev}->{length}, 39;
         ok $meta->{rev}->{http_date};
         is $meta->{rev}->{http_last_modified}, undef;
         is $meta->{rev}->{http_etag}, undef;
         ok $meta->{rev}->{timestamp};
         my $data_path = $path->parent->child ($item->{files}->{data});
         my $data = json_bytes2perl $data_path->slurp;
         ok $data->{success};
         is $json->{site}->{lang}, undef;
         is $json->{site}->{dir}, undef;
         is $json->{site}->{writing_mode}, undef;
       }},
    ]);
  })->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => "same response";
    return $current->check_files ([
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         is $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}, $current->o ('head1');
         is 0+keys %{$json->{items}}, 1;
       }},
    ]);
  })->then (sub {
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://Hoge/dataset/package-name-' . $key,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          status => 304,
          text => "abc",
        },
      },
    );
  })->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
    } $current->c, name => "bad 304 error";
    return $current->check_files ([
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         is $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}, $current->o ('head1');
         is 0+keys %{$json->{items}}, 1;
       }},
    ]);
  })->then (sub {
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://Hoge/dataset/package-name-' . $key,
          files => {package => {skip => 1}},
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {
            success => \1,
            result => {
              _ => 2,
              resources => [],
            },
          },
          etag => '"AbcEFEGeftr"',
        },
      },
    );
  })->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => "replace";
    return $current->check_files ([
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         isnt $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}, $current->o ('head1');
         ok $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key};
         $current->set_o (head2 => $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key});
         is 0+keys %{$json->{items}}, 2;
         my $item = $json->{items}->{$json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}};
         ok $item->{files}->{meta};
         ok $item->{files}->{data};
         is $item->{type}, 'package';
         my $meta_path = $path->parent->child ($item->{files}->{meta});
         my $meta = json_bytes2perl $meta_path->slurp;
         is $meta->{rev}->{url}, "http://hoge/api/action/package_show?id=package-name-" . $key;
         is $meta->{rev}->{original_url}, "http://hoge/api/action/package_show?id=package-name-" . $key;
         ok $meta->{rev}->{sha256};
         is $meta->{rev}->{length}, 45;
         ok $meta->{rev}->{http_date};
         is $meta->{rev}->{http_last_modified}, undef;
         is $meta->{rev}->{http_etag}, '"AbcEFEGeftr"';
         ok $meta->{rev}->{timestamp};
         my $data_path = $path->parent->child ($item->{files}->{data});
         my $data = json_bytes2perl $data_path->slurp;
         ok $data->{success};
       }},
    ]);
  })->then (sub {
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://Hoge/dataset/package-name-' . $key,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          status => 304,
          text => "abc",
          if_etag => '"AbcEFEGeftr"',
        },
      },
    );
  })->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => "good 304";
    return $current->check_files ([
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         is $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}, $current->o ('head2');
         is 0+keys %{$json->{items}}, 2;
       }},
    ]);
  });
} n => 57, name => 'empty package repo files';

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://Hoge/dataset/package-name-' . $key,
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
        },
        headers => {'last-modified' => '20 Apr 2023 23:23:22 GMT'},
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         ok $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key};
         $current->set_o (head1 => $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key});
         is 0+keys %{$json->{items}}, 1;
         my $item = $json->{items}->{$json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}};
         ok $item->{files}->{meta};
         ok $item->{files}->{data};
         is $item->{type}, 'meta';
         my $meta_path = $path->parent->child ($item->{files}->{meta});
         my $meta = json_bytes2perl $meta_path->slurp;
         is $meta->{rev}->{url}, "http://hoge/api/action/package_show?id=package-name-" . $key;
         is $meta->{rev}->{original_url}, "http://hoge/api/action/package_show?id=package-name-" . $key;
         ok $meta->{rev}->{sha256};
         is $meta->{rev}->{length}, 39;
         ok $meta->{rev}->{http_date};
         is $meta->{rev}->{http_last_modified}, 1682033002;
         is $meta->{rev}->{http_etag}, undef;
         ok $meta->{rev}->{timestamp};
         my $data_path = $path->parent->child ($item->{files}->{data});
         my $data = json_bytes2perl $data_path->slurp;
         ok $data->{success};
       }},
    ]);
  })->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => "same response";
    return $current->check_files ([
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         is $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}, $current->o ('head1');
         is 0+keys %{$json->{items}}, 1;
       }},
    ]);
  })->then (sub {
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://Hoge/dataset/package-name-' . $key,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {
            success => \1,
            result => {
              resources => [],
            },
            _ => 2,
          },
          headers => {'last-modified' => '20 Apr 2023 23:23:22 GMT'},
        },
      },
    );
  })->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => "replace (size changed)";
    return $current->check_files ([
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         isnt $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}, $current->o ('head1');
         ok $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key};
         $current->set_o (head2 => $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key});
         is 0+keys %{$json->{items}}, 2;
         my $item = $json->{items}->{$json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}};
         ok $item->{files}->{meta};
         ok $item->{files}->{data};
         is $item->{type}, 'meta';
         my $meta_path = $path->parent->child ($item->{files}->{meta});
         my $meta = json_bytes2perl $meta_path->slurp;
         is $meta->{rev}->{url}, "http://hoge/api/action/package_show?id=package-name-" . $key;
         is $meta->{rev}->{original_url}, "http://hoge/api/action/package_show?id=package-name-" . $key;
         ok $meta->{rev}->{sha256};
         is $meta->{rev}->{length}, 45;
         ok $meta->{rev}->{http_date};
         is $meta->{rev}->{http_last_modified}, 1682033002;
         is $meta->{rev}->{http_etag}, undef;
         ok $meta->{rev}->{timestamp};
         my $data_path = $path->parent->child ($item->{files}->{data});
         my $data = json_bytes2perl $data_path->slurp;
         ok $data->{success};
       }},
    ]);
  })->then (sub {
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://Hoge/dataset/package-name-' . $key,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {
            success => \1,
            result => {
              resources => [],
            },
            _ => 3,
          },
          headers => {'last-modified' => '20 Apr 2023 23:23:22 GMT'},
        },
      },
    );
  })->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => "no replace (size unchanged)";
    return $current->check_files ([
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         is $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}, $current->o ('head2');
         is 0+keys %{$json->{items}}, 2;
       }},
    ]);
  })->then (sub {
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://Hoge/dataset/package-name-' . $key,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {
            success => \1,
            result => {
              resources => [],
            },
            _ => 3,
          },
          headers => {'last-modified' => '20 Apr 2013 23:23:22 GMT'},
        },
      },
    );
  })->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => "replace (modified unchanged)";
    return $current->check_files ([
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         isnt $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}, $current->o ('head2');
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => "local/data/foo/index.json", text => sub { }, readonly => 1},
      {path => "local/data/foo/LICENSE", text => sub { }, readonly => 1},
      {path => "local/data/foo/package/package.ckan.json",
       text => sub { }, readonly => 1},
    ]);
  });
} n => 56, name => 'last-modified';

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://Hoge/dataset/package-name-' . $key,
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {
            resources => [],
          },
        },
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         ok $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key};
         $current->set_o (head1 => $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key});
         is 0+keys %{$json->{items}}, 1;
         my $item = $json->{items}->{$json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}};
         ok $item->{files}->{meta};
         ok $item->{files}->{data};
         is $item->{type}, 'package';
         my $meta_path = $path->parent->child ($item->{files}->{meta});
         my $meta = json_bytes2perl $meta_path->slurp;
         is $meta->{rev}->{url}, "http://hoge/api/action/package_show?id=package-name-" . $key;
         is $meta->{rev}->{original_url}, "http://hoge/api/action/package_show?id=package-name-" . $key;
         ok $meta->{rev}->{sha256};
         is $meta->{rev}->{length}, 39;
         my $data_path = $path->parent->child ($item->{files}->{data});
         my $data = json_bytes2perl $data_path->slurp;
         ok $data->{success};
       }},
    ]);
  })->then (sub {
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://Hoge/dataset/package-name-' . $key,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          text => "abc",
        },
      },
    );
  })->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c, name => "replaced by broken package";
    return $current->check_files ([
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         isnt $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}, $current->o ('head1');
         $current->set_o (head2 => $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key});
         is 0+keys %{$json->{items}}, 2;
       }},
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
    ]);
  })->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c, name => "still broken";
    return $current->check_files ([
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         is $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}, $current->o ('head2');
         is 0+keys %{$json->{items}}, 2;
       }},
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
    ]);
  })->then (sub {
    return $current->prepare (
      undef,
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {
            success => \1,
            result => {
              resources => [],
            },
            x => 2,
          },
        },
      },
    );
  })->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => "replaced by non-broken package";
    return $current->check_files ([
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{type}, 'ckan';
         isnt $json->{urls}->{"http://hoge/api/action/package_show?id=package-name-" . $key}, $current->o ('head2');
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
    ]);
  });
} n => 40, name => 'new broken package available';

Test {
  my $current = shift;
  my $key = sprintf '%.10f', rand;
  return $current->prepare (
    {
      hoe => {
        type => 'ckan',
        url => "http://foo.test/abc/dataset/" . $key,
      },
    },
    {
      "http://foo.test/abc/api/action/package_show?id=" . $key => {
        json => {
          success => \1,
          result => {
            resources => [
              {"id" => "r1", "url" => "http://foo.test/" . $key . "/r1"},
              {"id" => "r2", "url" => "http://foo.test/" . $key . "/r2"},
              {"id" => "r3", "url" => "http://foo.test/" . $key . "/r3"},
              {"id" => "r4", "url" => "http://foo.test/" . $key . "/r4"},
              {"id" => "r5", "url" => "http://foo.test/" . $key . "/r5"},
              {"id" => "r6", "url" => "http://foo.test/" . $key . "/r6"},
              {"id" => "r7", "url" => "http://foo.test/" . $key . "/r7"},
              {"id" => "r8", "url" => "http://foo.test/" . $key . "/r8"},
              {"id" => "r9", "url" => "http://foo.test/" . $key . "/r9"},
              {"id" => "r10", "url" => "http://foo.test/" . $key . "/r10"},
              {"id" => "r11", "url" => "http://foo.test/" . $key . "/r11"},
            ],
          },
        },
      },
      "http://foo.test/" . $key . "/r1" => {text => "r1"},
      "http://foo.test/" . $key . "/r2" => {text => "r2"},
      "http://foo.test/" . $key . "/r3" => {text => "r3"},
      "http://foo.test/" . $key . "/r4" => {text => "r4"},
      "http://foo.test/" . $key . "/r5" => {text => "r5"},
      "http://foo.test/" . $key . "/r6" => {text => "r6"},
      "http://foo.test/" . $key . "/r7" => {text => "r7"},
      "http://foo.test/" . $key . "/r8" => {text => "r8"},
      "http://foo.test/" . $key . "/r9" => {text => "r9"},
      "http://foo.test/" . $key . "/r10" => {text => "r10"},
      "http://foo.test/" . $key . "/r11" => {text => "r11"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "local/data/hoe/index.json", json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is 0+keys %{$json->{items}}, 12;
       }},
      {path => "local/data/hoe/files/r1", text => "r1"},
      {path => "local/data/hoe/files/r2", text => "r2"},
      {path => "local/data/hoe/files/r3", text => "r3"},
      {path => "local/data/hoe/files/r4", text => "r4"},
      {path => "local/data/hoe/files/r5", text => "r5"},
      {path => "local/data/hoe/files/r6", text => "r6"},
      {path => "local/data/hoe/files/r7", text => "r7"},
      {path => "local/data/hoe/files/r8", text => "r8"},
      {path => "local/data/hoe/files/r9", text => "r9"},
      {path => "local/data/hoe/files/r10", text => "r10"},
      {path => "local/data/hoe/files/r11", text => "r11"},
      {path => 'config/ddsd/packages.json', json => sub {
         my $json = shift;
         my $def = $json->{hoe};
         is 0+keys %{$def}, 2;
       }},
    ]);
  });
} n => 16, name => ['many resources'];

for my $in (
  {url => undef},
  {url => q<https://hoge.test/{foo}>},
  {url => q<hoge://>},
  {url => q<javascript:>},
  {url => q<foo bar>},
  {url => q<httPs://hoge:fuga>},
  {url => q<http://hoge/fuga/{key}/>},
  {url => q<http://hoge/fuga/{key}/.foo>},
  {url => q<http://hoge/fuga/{key}/-foo>},
  {url => q<http://hoge/fuga/{key}/foo.>},
  {url => q<http://hoge/fuga/{key}/%00>},
  {url => q<http://hoge/fuga/{key}/%85>},
  {url => q<http://hoge/fuga/{key}/b%2Fa>},
  {url => q<http://hoge/fuga/{key}/b%5Ca>},
  {url => q<http://hoge/fuga/{key}/b%7Fa>},
  {url => q<http://hoge/fuga/{key}/b%20a>},
) {
  Test {
    my $current = shift;
    my $key = '' . rand;
    $in->{url} =~ s{\{key\}}{$key};
    return $current->prepare (
      {
        $key => {
          type => "ckan",
          url => "http://foo.test/abc/dataset/" . $key,
        },
      },
      {
        "http://foo.test/abc/api/action/package_show?id=" . $key => {
          json => {
            success => \1,
            result => {
              resources => [
                {
                  "id" => "hoge123",
                  "url" => "http://foo.test/hoge123/" . $key,
                  %$in,
                },
              ],
            },
          },
        },
        "http://foo.test/hoge123/" . $key => {
          text => "abc def",
        },
        ($in->{url} =~ m{^https?://} ? ($in->{url} => {text => "xyz"}) : ()),
      },
    )->then (sub {
      return $current->run ('pull', insecure => 1);
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => "local/data/$key/index.json", json => sub {
           my $json = shift;
           is $json->{type}, 'datasnapshot';
           is 0+keys %{$json->{items}}, 1;
         }},
        {path => "local/data/$key/files/1", is_none => 1},
        {path => 'config/ddsd/packages.json', json => sub {
           my $json = shift;
           my $def = $json->{$key};
           is 0+keys %{$def}, 2;
           is $def->{type}, 'ckan';
           is $def->{url}, "http://foo.test/abc/dataset/".$key;
         }},
      ]);
    });
  } n => 7, name => ['disabled resource', %$in];
}

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {id => 'hoge', url => "http://hoge/$key/hoge"},
            {id => 'fuga', url => "http://hoge/$key/hoge"},
            {id => 'abc', url => "http://hoge/$key/abc"},
          ],
        }},
      },
      "http://hoge/$key/hoge" => {
        text => "ab",
      },
      "http://hoge/$key/abc" => {
        text => "abc",
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 2;
         ok $json->{items}->{"file:id:abc"};
       }},
      {path => 'local/data/foo/files/hoge', is_none => 1},
      {path => 'local/data/foo/files/fuga', is_none => 1},
      {path => 'local/data/foo/files/abc', text => "abc"},
    ]);
  });
} n => 7, name => ['dup file names'];

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {id => 'hoge', url => "http://hoge/$key/hoge"},
            {id => 'hoge', url => "http://hoge/$key/fuga"},
            {id => 'abc', url => "http://hoge/$key/abc"},
          ],
        }},
      },
      "http://hoge/$key/hoge" => {
        text => "ab",
      },
      "http://hoge/$key/fuga" => {
        text => "cd",
      },
      "http://hoge/$key/abc" => {
        text => "abc",
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
         ok $json->{items}->{"file:id:hoge"};
         ok $json->{items}->{"file:index:1"};
         ok $json->{items}->{"file:id:abc"};
       }},
      {path => 'local/data/foo/files/hoge', text => "ab"},
      {path => 'local/data/foo/files/fuga', text => "cd"},
      {path => 'local/data/foo/files/abc', text => "abc"},
    ]);
  });
} n => 11, name => ['dup IDs in ckan package'];

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
        files => {
          "file:id:hoge" => {name => "hoge0"},
          "file:index:1" => {name => "hoge1"},
        },
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          resources => [
            {id => 'hoge', url => "http://hoge/$key/hoge"},
            {id => 'hoge', url => "http://hoge/$key/fuga"},
            {id => 'abc', url => "http://hoge/$key/abc"},
          ],
        }},
      },
      "http://hoge/$key/hoge" => {
        text => "ab",
      },
      "http://hoge/$key/fuga" => {
        text => "cd",
      },
      "http://hoge/$key/abc" => {
        text => "abc",
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
         ok $json->{items}->{"file:id:hoge"};
         ok $json->{items}->{"file:index:1"};
         ok $json->{items}->{"file:id:abc"};
       }},
      {path => 'local/data/foo/files/hoge0', text => "ab"},
      {path => 'local/data/foo/files/hoge1', text => "cd"},
      {path => 'local/data/foo/files/hoge', is_none => 1},
      {path => 'local/data/foo/files/fuga', is_none => 1},
      {path => 'local/data/foo/files/abc', text => "abc"},
    ]);
  });
} n => 11, name => ['dup IDs in ckan package, renamed'];

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-' . $key,
      },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {success => \1, result => {
          title => "\x{4e00}",
          resources => [
            {id => 'hoge', url => "https://hoge/$key/hoge"},
          ],
        }},
      },
      "https://hoge/$key/hoge" => {
        text => "ab",
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
      {path => 'local/data/foo/files/hoge', text => "ab"},
    ]);
  });
} n => 3, name => 'name 1';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
