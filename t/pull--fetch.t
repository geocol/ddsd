use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

for my $pi (
  {
    type => 'ckan',
    url => 'hoge/fuga', # not absolute URL
  },
  {
    type => 'ckan',
    url => 'http://hoge:fuga',
  },
  {
    type => 'ckan',
    url => 'https://hoge:fuga',
  },
  {
    type => 'ckan',
    url => 'file://foo/bar/', # bad URL scheme
  },
  {
    type => 'ckan',
    url => 'ftp://foo/bar/', # bad URL scheme
  },
  {
    type => 'ckan',
    url => 'javascript://foo/bar/', # bad URL scheme
  },
) {
  Test {
    my $current = shift;
    my $key = rand;
    return $current->prepare (
      {
        foo => $pi,
      },
      {},
    )->then (sub {
      return $current->run ('pull', insecure => 0);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'local/data/foo/index.json', is_none => 1},
      ]);
    });
  } n => 3, name => ['bad package location 1', %$pi];
  
  Test {
    my $current = shift;
    my $key = rand;
    return $current->prepare (
      {
        foo => $pi,
      },
      {},
    )->then (sub {
      return $current->run ('pull', insecure => 1);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'local/data/foo/index.json', is_none => 1},
      ]);
    });
  } n => 3, name => ['bad package location 2', %$pi];
} # $pi

for my $pi (
  {
    type => 'ckan',
    url => 'https://noserver.test/dataset/package-name', # server error
  },
) {
  Test {
    my $current = shift;
    my $key = rand;
    return $current->prepare (
      {
        foo => $pi,
      },
      {},
    )->then (sub {
      return $current->run ('pull', insecure => 0);
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'local/data/foo/index.json', is_none => 1},
      ]);
    });
  } n => 2, name => ['bad package location 3', %$pi];
  
  Test {
    my $current = shift;
    my $key = rand;
    return $current->prepare (
      {
        foo => $pi,
      },
      {},
    )->then (sub {
      return $current->run ('pull', insecure => 1);
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'local/data/foo/index.json', json => sub {
           my $json = $_[0];
           is 0+keys %{$json->{items}}, 0;
         }},
      ]);
    });
  } n => 3, name => ['bad package location 4', %$pi];
} # $pi

for my $pack (
  {
    type => 'ckan',
    url => 'https://raw.githubusercontent.com/wakaba/nemui/hoge/dataset/abc', # 404
  },
#  {
#    type => 'ckan',
#    url => 'http://raw.githubusercontent.com/wakaba/nemui/8874b5575dc71394665cbf1867d6221ce52b5e98/api/action/package_show?id=abc', # insecure error
#    insecure => 0,
#  },
) {
  Test {
    my $current = shift;
    my $key = rand;
    return $current->prepare (
      {
        foo => $pack,
      },
      {
      },
    )->then (sub {
      return $current->run ('pull', insecure => 0);
    })->then (sub {
      my $r = $_[0];
      test {
        is $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'local/data/foo/index.json', json => sub {
           my $json = $_[0];
           is 0+keys %{$json->{items}}, 0;
         }},
      ]);
    });
  } n => 3, name => 'broken packages 1';

  Test {
    my $current = shift;
    my $key = rand;
    return $current->prepare (
      {
        foo => $pack,
      },
      {
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
           my $json = $_[0];
           is 0+keys %{$json->{items}}, 0;
         }},
      ]);
    });
  } n => 3, name => 'broken packages 2';
} # $pack

for my $pack (
  {
    type => 'ckan',
    url => 'https://raw.githubusercontent.com/wakaba/nemui/f4413b7ec21c4dc6f513b77da35ee668031df72e/api/action/package_show?id=abc', # broken response
  },
  {
    type => 'ckan',
    url => 'https://raw.githubusercontent.com/wakaba/nemui/8874b5575dc71394665cbf1867d6221ce52b5e98/api/action/package_show?id=abc',
  },
  {
    type => 'ckan',
    url => 'https://raw.githubusercontent.com/wakaba/nemui/8874b5575dc71394665cbf1867d6221ce52b5e98/api/action/package_show?id=abc',
    insecure => 1,
  },
  {
    type => 'ckan', url => 'https://raw.githubusercontent.com/wakaba/nemui/8874b5575dc71394665cbf1867d6221ce52b5e98/api/action/package_show?id=abc',
    insecure => 0,
  },
) {
  last;
  
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (
      {
        foo => $pack,
      },
      {
      },
    )->then (sub {
      return $current->run ('pull', insecure => 0, cacert => 0);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'local/data/foo', is_none => 1},
      ]);
    });
  } n => 5, name => 'empty packages 1';

  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (
      {
        foo => $pack,
      },
      {
      },
    )->then (sub {
      return $current->run ('pull', insecure => 1, cacert => 0);
    })->then (sub {
      my $r = $_[0];
      test {
        isnt $r->{exit_code}, 0;
        isnt $r->{exit_code}, 12;
      } $current->c;
      return $current->check_files ([
        {path => 'local/data/foo', is_none => 1},
      ]);
    });
  } n => 5, name => 'empty packages 2';
} # $pack

for my $in (
  {
    insecure => 1,
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
          files => {'meta:ckan.json' => {skip => 1}},
          %$in,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {
            success => \1,
            result => {},
          },
        },
      },
    )->then (sub {
      return $current->run ('pull', insecure => 0);
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
           is 0+keys %{$json->{items}}, 0;
         }},
      ]);
    });
  } n => 5, name => 'empty packages, secure only';
  
  Test {
    my $current = shift;
    my $key = '' . rand;
    return $current->prepare (
      {
        foo => {
          type => 'ckan',
          url => 'http://hoge/dataset/package-name-' . $key,
          files => {'meta:ckan.json' => {skip => 1}},
          %$in,
        },
      },
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          json => {
            success => \1,
            result => {},
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
           is 0+keys %{$json->{items}}, 0;
         }},
      ]);
    });
  } n => 5, name => 'empty packages --insecure';
} # $in

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-name-' . $key,
      },
      foo2 => {
        type => 'ckan',
        url => 'http://hoge/dataset/package-2-' . $key,
      },
    },
    {
      "http://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {},
          foo1 => 1,
        },
      },
      "http://hoge/api/action/package_show?id=package-2-" . $key => {
        json => {
          success => \1,
          result => {},
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
    return $current->prepare (
      undef,
      {
        "http://hoge/api/action/package_show?id=package-name-" . $key => {
          status => 404,
          json => {
            success => \1,
            result => {},
          },
        },
        "http://hoge/api/action/package_show?id=package-2-" . $key => {
          json => {
            success => \1,
            result => {},
            hoge => 1,
          },
        },
      },
    );
  })->then (sub {
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
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => 'local/data/foo/package/package.ckan.json', json => sub {
         my $json = shift;
         ok $json->{foo1};
       }},
      {path => 'local/data/foo2/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => 'local/data/foo2/package/package.ckan.json', json => sub {
         my $json = shift;
         ok $json->{hoge};
       }},
    ]);
  });
} n => 11, name => '404 package';

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
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1"},
              {id => "r2", url => "http://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1" => {text => "r1"},
      "http://hoge/" . $key . "/r2" => {text => "r2", status => 404},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
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
         is 0+keys %{$json->{items}}, 3;
       }},
      {path => 'local/data/foo/files/r1', text => "r1"},
      {path => 'local/data/foo/files/r2', is_none => 1},
      {path => 'local/data/foo/files/r3', text => "r3"},
    ]);
  });
} n => 7, name => '404 resource 1';

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
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1"},
              {id => "r2", url => "http://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1" => {text => "r1"},
      "http://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare (
      undef,
      {
        "http://hoge/" . $key . "/r1" => {text => "R1"},
        "http://hoge/" . $key . "/r2" => {text => "R2", status => 404},
        "http://hoge/" . $key . "/r3" => {text => "R3"},
      },
    );
  })->then (sub {
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
         is 0+keys %{$json->{items}}, 4;
       }},
      {path => 'local/data/foo/files/r1', text => "R1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', text => "R3"},
    ]);
  });
} n => 9, name => '404 resource 2';

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
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1"},
              {id => "r2", url => "http://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1" => {text => "r1", etag => '"r1"'},
      "http://hoge/" . $key . "/r2" => {text => "r2", etag => '"r2"'},
      "http://hoge/" . $key . "/r3" => {text => "r3", etag => '"r3"'},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare (
      undef,
      {
        "http://hoge/" . $key . "/r1" => {text => "R1", etag => '"R1"'},
        "http://hoge/" . $key . "/r2" => {if_etag => '"r2"', status => 304},
        "http://hoge/" . $key . "/r3" => {text => "R3", etag => '"R3"'},
      },
    );
  })->then (sub {
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
       }},
      {path => $current->repo_path ('ckan', 'http://hoge/dataset/package-name-' . $key)->child ('index.json'), json => sub {
         my $json = shift;
         is $json->{items}->{$json->{urls}->{"http://hoge/$key/r1"}}->{rev}->{http_etag}, '"R1"';
         is $json->{items}->{$json->{urls}->{"http://hoge/$key/r2"}}->{rev}->{http_etag}, '"r2"';
         is $json->{items}->{$json->{urls}->{"http://hoge/$key/r3"}}->{rev}->{http_etag}, '"R3"';
       }},
      {path => 'local/data/foo/files/r1', text => "R1"},
      {path => 'local/data/foo/files/r2', text => "r2"},
      {path => 'local/data/foo/files/r3', text => "R3"},
    ]);
  });
} n => 12, name => '304';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-' . $key,
        files => {'meta:ckan.json' => {skip => 1}},
      },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {},
        },
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 1, cacert => 0);
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
         is 0+keys %{$json->{items}}, 0;
       }},
      ]);
  });
} n => 5, name => 'HTTPS, no root CA cert, --insecure';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('pull');
  })->then (sub {
    return $current->prepare ({
      foo => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-' . $key,
        files => {'meta:ckan.json' => {skip => 1}},
      },
    }, {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {},
        },
      },
    });
  })->then (sub {
    return $current->run ('pull', insecure => 0, cacert => 0);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = $_[0];
         is 0+keys %{$json->{items}}, 0;
       }},
    ]);
  });
} n => 3, name => 'HTTPS, no root CA cert, not --insecure';

Test {
  my $current = shift;
  my $key = '' . rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => 'https://hoge/dataset/package-name-' . $key,
        files => {'meta:ckan.json' => {skip => 1}},
      },
    },
    {
      "https://hoge/api/action/package_show?id=package-name-" . $key => {
        json => {
          success => \1,
          result => {},
        },
      },
    },
  )->then (sub {
    return $current->run ('pull', insecure => 0, cacert => 1);
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
         is 0+keys %{$json->{items}}, 0;
       }},
      ]);
  });
} n => 5, name => 'HTTPS, with root CA cert';

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
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "http://hoge/" . $key . "/r1"},
              {id => "r2", url => "http://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "http://hoge/" . $key . "/r1" => {text => "r1"},
      "http://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
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
         ok $json->{items}->{'meta:ckan.json'}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
    ]);
  });
} n => 9, name => 'insecure flag, plain HTTP';

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
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "https://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 0);
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
         ok ! $json->{items}->{'meta:ckan.json'}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
    ]);
  });
} n => 9, name => 'no insecure flag, HTTPS';

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
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "https://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {text => "r3"},
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
         ok ! $json->{items}->{'meta:ckan.json'}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
    ]);
  });
} n => 9, name => 'insecure flag, HTTPS with --insecure';

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
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
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
         ok ! $json->{items}->{'meta:ckan.json'}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
    ]);
  });
} n => 9, name => 'insecure flag, HTTP(S) with --insecure (1)';

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
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
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
         ok $json->{items}->{'meta:ckan.json'}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
    ]);
  });
} n => 9, name => 'insecure flag, HTTP(S) with --insecure 2';

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
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "http://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', insecure => 0);
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
         is 0+keys %{$json->{items}}, 3;
         ok ! $json->{items}->{'meta:ckan.json'}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
       }},
    ]);
  });
} n => 8, name => 'insecure flag, HTTP(S) with --insecure (3)';

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
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {text => "r3"},
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
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 4;
         ok ! $json->{items}->{'meta:ckan.json'}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok ! $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
    ]);
  })->then (sub {
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 6;
      {
        my $file = $r->{jsonl}->[5];
        ok ! $file->{rev}->{insecure};
        is $file->{rev}->{url}, "https://hoge/" . $key . "/r3";
        is $file->{rev}->{original_url}, "http://hoge/" . $key . "/r3";
      }
    } $current->c;
  });
} n => 14, name => 'resource URL auto-upgrade';

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
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "https://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', cacert => 0, insecure => 1);
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
         ok $json->{items}->{'meta:ckan.json'}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
    ]);
  })->then (sub {
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 6;
      {
        my $file = $r->{jsonl}->[1];
        ok $file->{rev}->{insecure};
        is $file->{rev}->{url}, "https://hoge/api/action/package_show?id=package-name-" . $key;
        is $file->{rev}->{original_url}, $file->{rev}->{url};
      }
      {
        my $file = $r->{jsonl}->[5];
        ok $file->{rev}->{insecure};
        is $file->{rev}->{url}, "https://hoge/" . $key . "/r3";
        is $file->{rev}->{original_url}, "https://hoge/" . $key . "/r3";
      }
    } $current->c;
  });
} n => 17, name => 'bad cert with --insecure';

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
        json => {
          success => \1,
          result => {
            resources => [
              {id => "r1", url => "https://hoge/" . $key . "/r1"},
              {id => "r2", url => "https://hoge/" . $key . "/r2"},
              {id => "r3", url => "http://hoge/" . $key . "/r3"},
            ],
          },
        },
      },
      "https://hoge/" . $key . "/r1" => {text => "r1"},
      "https://hoge/" . $key . "/r2" => {text => "r2"},
      "https://hoge/" . $key . "/r3" => {text => "r3"},
    },
  )->then (sub {
    return $current->run ('pull', cacert => 0, insecure => 1);
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
         ok $json->{items}->{'meta:ckan.json'}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r1"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r2"}->{rev}->{insecure};
         ok $json->{items}->{"file:id:r3"}->{rev}->{insecure};
       }},
    ]);
  })->then (sub {
    return $current->run ('ls', additional => ['foo', '--jsonl'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 6;
      {
        my $file = $r->{jsonl}->[5];
        ok $file->{rev}->{insecure};
        is $file->{rev}->{url}, "https://hoge/" . $key . "/r3";
        is $file->{rev}->{original_url}, "http://hoge/" . $key . "/r3";
      }
    } $current->c;
  });
} n => 14, name => 'resource URL auto-upgrade but bad cert';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
        files => {
          "file:id:bar" => {skip => 0},
        },
      },
    },
    {
      "https://hoge/dataset/$key" => {text => ""},
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
              {id => 'bar', url => "https://hoge/$key/bar"},
            ],
          },
        },
      },
      "https://hoge/$key/foo" => {text => "abc"},
      "https://hoge/$key/bar" => {text => "xyz"},
    },
  )->then (sub {
    return $current->run ('pull', logs => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;

      my $cc = [grep { $_->{counts} } @{$r->{logs}}]->[0]->{counts};
      ok $cc->{http_request};
      ok $cc->{http_request_completed};
      ok $cc->{fetch_failure};

      my $cmp = [grep { $_->{error}->{type} eq 'completed' } @{$r->{logs}}]->[0];
      is $cmp->{error}->{value}, 0;
    } $current->c;
  });
} n => 5, name => 'logs ok';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
        files => {
          "file:id:bar" => {skip => 0},
        },
      },
    },
    {
      "https://hoge/dataset/$key" => {text => ""},
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
              {id => 'bar', url => "https://hoge/$key/bar"},
            ],
          },
        },
      },
      "https://hoge/$key/foo" => {text => "abc"},
      "https://hoge/$key/bar" => {text => "xyz", status => 404},
    },
  )->then (sub {
    return $current->run ('pull', logs => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;

      my $cc = [grep { $_->{counts} } @{$r->{logs}}]->[0]->{counts};
      ok $cc->{http_request};
      ok $cc->{http_request_completed};
      ok $cc->{fetch_failure};

      my $cmp = [grep { $_->{error}->{type} eq 'completed' } @{$r->{logs}}]->[0];
      is $cmp->{error}->{value}, 12;
    } $current->c;
  });
} n => 5, name => 'logs error';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
        files => {},
      },
    },
    {
      "https://hoge/dataset/$key" => {text => ""},
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
            ],
          },
        },
      },
      "https://hoge/$key/foo" => {text => "abc"},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare (undef, {
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "http://hoge/$key/bar"},
            ],
          },
        },
      },
      "http://hoge/$key/bar" => {text => "abc"},
    });
  })->then (sub {
    return $current->run ('pull', additional => ['--insecure']);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         my $item = $json->{items}->{'file:id:foo'};
         ok $item->{rev}->{insecure};
       }},
      {path => 'local/data/foo/files/bar', text => "abc"},
      {path => $current->repo_path ('ckan', "https://hoge/dataset/$key")->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         isnt $json->{urls}->{"http://hoge/$key/bar"}, $json->{urls}->{"https://hoge/$key/foo"};
         ok ! $json->{items}->{$json->{urls}->{"https://hoge/$key/foo"}}->{rev}->{insecure};
         ok $json->{items}->{$json->{urls}->{"http://hoge/$key/bar"}}->{rev}->{insecure};
       }},
    ]);
  });
} n => 8, name => 'secure and insecure with same response, different path';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
        files => {},
      },
    },
    {
      "https://hoge/dataset/$key" => {text => ""},
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
            ],
          },
        },
      },
      "https://hoge/$key/foo" => {text => "abc"},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('pull', additional => ['--insecure'], cacert => 0);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         my $item = $json->{items}->{'file:id:foo'};
         ok $item->{rev}->{insecure};
       }},
      {path => 'local/data/foo/files/foo', text => "abc"},
      {path => $current->repo_path ('ckan', "https://hoge/dataset/$key")->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         ok $json->{items}->{$json->{urls}->{"https://hoge/$key/foo"}}->{rev}->{insecure};
         my $items = [grep { $json->{items}->{$_}->{rev}->{url} eq "https://hoge/$key/foo" and not $json->{items}->{$_}->{rev}->{insecure} } keys %{$json->{items}}];
         is 0+@$items, 1;
         isnt $items->[0], $json->{urls}->{"https://hoge/$key/foo"};
         is $json->{items}->{$items->[0]}->{files}->{data}, $json->{items}->{$json->{urls}->{"https://hoge/$key/foo"}}->{files}->{data};
       }},
    ]);
  });
} n => 9, name => 'secure and insecure with same response, different cert status, ok then ng';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
        files => {},
      },
    },
    {
      "https://hoge/dataset/$key" => {text => ""},
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
            ],
          },
        },
      },
      "https://hoge/$key/foo" => {text => "abc"},
    },
  )->then (sub {
    return $current->run ('pull', additional => ['--insecure'], cacert => 0);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         my $item = $json->{items}->{'file:id:foo'};
         ok ! $item->{rev}->{insecure};
       }},
      {path => 'local/data/foo/files/foo', text => "abc"},
      {path => $current->repo_path ('ckan', "https://hoge/dataset/$key")->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         ok ! $json->{items}->{$json->{urls}->{"https://hoge/$key/foo"}}->{rev}->{insecure};
         my $items = [grep { $json->{items}->{$_}->{rev}->{url} eq "https://hoge/$key/foo" and $json->{items}->{$_}->{rev}->{insecure} } keys %{$json->{items}}];
         is 0+@$items, 1;
         isnt $items->[0], $json->{urls}->{"https://hoge/$key/foo"};
         is $json->{items}->{$items->[0]}->{files}->{data}, $json->{items}->{$json->{urls}->{"https://hoge/$key/foo"}}->{files}->{data};
       }},
    ]);
  });
} n => 9, name => 'secure and insecure with same response, different cert status, ng then ok';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
        files => {},
      },
    },
    {
      "https://hoge/dataset/$key" => {text => ""},
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
            ],
          },
        },
      },
      "https://hoge/$key/foo" => {text => "abc"},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare (undef, {
      "https://hoge/$key/foo" => {text => "abc", mime => 'text/css'},
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         my $item = $json->{items}->{'file:id:foo'};
         is $item->{rev}->{http_content_type}, 'text/css';
       }},
      {path => 'local/data/foo/files/foo', text => "abc"},
      {path => $current->repo_path ('ckan', "https://hoge/dataset/$key")->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         is $json->{items}->{$json->{urls}->{"https://hoge/$key/foo"}}->{rev}->{http_content_type}, 'text/css';
         my $items = [grep { $json->{items}->{$_}->{rev}->{url} eq "https://hoge/$key/foo" and not defined $json->{items}->{$_}->{rev}->{http_content_type} } keys %{$json->{items}}];
         is 0+@$items, 1;
         isnt $items->[0], $json->{urls}->{"https://hoge/$key/foo"};
         is $json->{items}->{$items->[0]}->{files}->{data}, $json->{items}->{$json->{urls}->{"https://hoge/$key/foo"}}->{files}->{data};
       }},
    ]);
  });
} n => 9, name => 'mime type changed';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare (
    {
      foo => {
        type => 'ckan',
        url => "https://hoge/dataset/$key",
        files => {},
      },
    },
    {
      "https://hoge/dataset/$key" => {text => ""},
      "https://hoge/dataset/activity/$key" => {text => ""},
      "https://hoge/api/action/package_show?id=$key" => {
        json => {
          success => \1,
          result => {
            resources => [
              {id => 'foo', url => "https://hoge/$key/foo"},
            ],
          },
        },
      },
      "https://hoge/$key/foo" => {text => ""},
    },
  )->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare (undef, {
      "https://hoge/$key/foo" => {text => "", incomplete => 1},
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', json => sub {
         my $json = shift;
         my $item = $json->{items}->{'file:id:foo'};
         ok $item->{rev}->{http_incomplete};
       }},
      {path => 'local/data/foo/files/foo', text => ""},
      {path => $current->repo_path ('ckan', "https://hoge/dataset/$key")->child ('index.json'), json => sub {
         my ($json, $path) = @_;
         ok $json->{items}->{$json->{urls}->{"https://hoge/$key/foo"}}->{rev}->{http_incomplete};
         my $items = [grep { $json->{items}->{$_}->{rev}->{url} eq "https://hoge/$key/foo" and not $json->{items}->{$_}->{rev}->{http_incomplete} } keys %{$json->{items}}];
         is 0+@$items, 1;
         isnt $items->[0], $json->{urls}->{"https://hoge/$key/foo"};
         is $json->{items}->{$items->[0]}->{files}->{data}, $json->{items}->{$json->{urls}->{"https://hoge/$key/foo"}}->{files}->{data};
       }},
    ]);
  });
} n => 9, name => 'incomplete response';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
