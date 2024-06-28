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
  } n => 3, name => 'bad package location';
  
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
  } n => 3, name => 'bad package location';
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
  } n => 2, name => 'bad package location';
  
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
        {path => 'local/data/foo/index.json', is_none => 1},
      ]);
    });
  } n => 2, name => 'bad package location';
} # $pi

for my $pack (
  {
    type => 'ckan',
    url => 'https://raw.githubusercontent.com/wakaba/nemui/hoge/api/action/package_show?id=abc', # 404
  },
  {
    type => 'ckan',
    url => 'http://raw.githubusercontent.com/wakaba/nemui/8874b5575dc71394665cbf1867d6221ce52b5e98/api/action/package_show?id=abc', # insecure error
    insecure => 0,
  },
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
        {path => 'local/data/foo/index.json', is_none => 1},
      ]);
    });
  } n => 2, name => 'broken packages 1';

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
        {path => 'local/data/foo/index.json', is_none => 1},
      ]);
    });
  } n => 2, name => 'broken packages 2';
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
      {path => 'local/data/foo/package-ckan.json', json => sub {
         my $json = shift;
         ok $json->{foo1};
       }},
      {path => 'local/data/foo2/index.json', json => sub {
         my $json = shift;
         is $json->{type}, 'datasnapshot';
         is ref $json->{items}, 'HASH';
         is 0+keys %{$json->{items}}, 1;
       }},
      {path => 'local/data/foo2/package-ckan.json', json => sub {
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
} n => 5, name => '404 resource 1';

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
} n => 6, name => '404 resource 2';

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
      {path => $current->repo_path ('ckan', 'http://hoge/api/action/package_show?id=package-name-' . $key)->child ('index.json'), json => sub {
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
} n => 9, name => '304';

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
    return $current->run ('pull', insecure => 0, cacert => 0);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => 'local/data/foo/index.json', is_none => 1},
    ]);
  });
} n => 2, name => 'HTTPS, no root CA cert, not --insecure';

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
      is 0+@{$r->{jsonl}}, 4;
      {
        my $file = $r->{jsonl}->[3];
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

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
