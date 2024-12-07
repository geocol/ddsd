use strict;
use warnings;
use Path::Tiny;
BEGIN { $ENV{TEST_MAX_CONCUR} = 1 }
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare ({
    hoge => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
  }, {
    $current->legal_url_prefix . 'packref.json' => {
      json => {
        type => 'packref',
        source => {
          type => 'files',
          files => {
            'file:r:websites.json' => {
              url => "https://hoge/websites.json",
            },
            'file:r:info.json' => {
              url => "info.json",
            },
            'file:r:ckan.json' => {
              url => "ckan.json",
            },
          },
        },
      },
    },
    "https://hoge/websites.json" => {
      json => [{
        url_prefix => "https://hoge/$key/",
        source => {type => 'packref', url => "https://hoge/$key/license.json"},
        legal_key => "$key-license",
      }],
    },
    "https://hoge/$key/license.json" => {
      json => {
        type => 'packref',
        source => {type => 'files'},
      },
    },
    "https://hoge/$key/api/action/package_show?id=" . $key => {
      json => {success => \1, result => {
      }},
      etag => '"abc"',
    },
  })->then (sub {
    $current->set_o (time1 => time);
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    $current->set_o (time1_2 => time);
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         
         is 0+keys %{$json->{items}}, 1;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         ok $json->{items}->{$file_key}->{files}->{log};

         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp} > $current->o ('time1');
           ok $v->{timestamp} < $current->o ('time1_2');
           is $v->{legal_key}, "$key-license";
           $current->set_o (log1 => $v);
         }
       }},
    ]);
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'same response';
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         
         is 0+keys %{$json->{items}}, 1;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         ok $json->{items}->{$file_key}->{files}->{log};

         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 2;
         {
           my $v = json_bytes2perl $lines->[0];
           is $v->{timestamp}, $current->o ('log1')->{timestamp};
           is $v->{legal_key}, "$key-license";
         }
         {
           my $v = json_bytes2perl $lines->[1];
           ok $v->{timestamp} > $current->o ('time1');
           ok $v->{timestamp} < $current->o ('time1_2');
           is $v->{legal_key}, "$key-license";
           $current->set_o (log2 => $v);
         }
       }},
    ]);
  })->then (sub {
    return $current->prepare (undef, {
      "https://hoge/$key/api/action/package_show?id=" . $key => {
        status => 304,
        if_etag => '"abc"',
      },
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 304;
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 3;
         {
           my $v = json_bytes2perl $lines->[0];
           is $v->{timestamp}, $current->o ('log1')->{timestamp};
           is $v->{legal_key}, "$key-license";
           is $v->{legal_source_key}, undef;
           is $v->{legal_source_url}, undef;
         }
         {
           my $v = json_bytes2perl $lines->[1];
           is $v->{timestamp}, $current->o ('log2')->{timestamp};
           is $v->{legal_key}, "$key-license";
           is $v->{legal_source_key}, undef;
           is $v->{legal_source_url}, undef;
         }
         {
           my $v = json_bytes2perl $lines->[2];
           is $v->{timestamp}, $current->o ('log2')->{timestamp};
           is $v->{legal_key}, "$key-license";
           is $v->{legal_source_key}, undef;
           is $v->{legal_source_url}, undef;
         }
       }},
      {path => $current->repo_path ('packref', $current->legal_url_prefix.'packref.json') . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{$current->legal_url_prefix . "packref.json"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, undef;
         }
       }},
      {path => $current->repo_path ('packref', "https://hoge/$key/license.json") . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{"https://hoge/$key/license.json"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, undef;
           is $v->{legal_source_key}, undef;
           is $v->{legal_source_url}, undef;
         }
       }},
    ]);
  });
} n => 41, name => 'legal';


Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare ({
    hoge => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
  }, {
    $current->legal_url_prefix . 'packref.json' => {
      json => {
        type => 'packref',
        source => {
          type => 'files',
          files => {
            'file:r:websites.json' => {
              url => "https://hoge/websites.json",
            },
            'file:r:info.json' => {
              url => "info.json",
            },
            'file:r:ckan.json' => {
              url => "ckan.json",
            },
          },
        },
      },
    },
    "https://hoge/websites.json" => {
      json => [{
        url_prefix => "https://hoge/$key/",
        source => {type => 'packref', url => "https://hoge/$key/license.json"},
        legal_key => "$key-license",
      }],
    },
    "https://hoge/$key/license.json" => {
      json => {
        type => 'packref',
        source => {type => 'files'},
      },
    },
    "https://hoge/$key/api/action/package_show?id=" . $key => {
      text => q{ {"success": true, "result": {}} },
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare (undef, {
      "https://hoge/$key/api/action/package_show?id=" . $key => {
        json => {success => \1, result => {
          2 => 1,
        }},
      },
    });
  })->then (sub {
    return $current->run ('pull', additional => ['--now' => time+200*24*24]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'changed';
    return $current->prepare (undef, {
      "https://hoge/$key/api/action/package_show?id=" . $key => {
        text => q{ {"success": true, "result": {}} },
      },
    });
  })->then (sub {
    return $current->run ('pull', additional => ['--now' => time+400*24*24]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'reverted';
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 2;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, "$key-license";
           $current->set_o (v1 => $v);
         }
         {
           my $v = json_bytes2perl $lines->[1];
           ok $v->{timestamp} > $current->o ('v1')->{timestamp};
           is $v->{legal_key}, "$key-license";
         }
       }},
      {path => "local/data/hoge/package/package.ckan.json",
       text => q{ {"success": true, "result": {}} }},
    ]);
  });
} n => 10, name => 'reverted';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare ({
    hoge => {
      type => 'ckan', url => "https://hoge/$key/dataset/$key",
      files => {
        "meta:ckan.json" => {
          sha256 => 'd5850b8046f03d3ede10a30f1c9bff25fd12ad0f303ba6dcbf21b0b1534db0e4',
        },
      },
    },
  }, {
    $current->legal_url_prefix . 'packref.json' => {
      json => {
        type => 'packref',
        source => {
          type => 'files',
          files => {
            'file:r:websites.json' => {
              url => "https://hoge/websites.json",
            },
            'file:r:info.json' => {
              url => "info.json",
            },
            'file:r:ckan.json' => {
              url => "ckan.json",
            },
          },
        },
      },
    },
    "https://hoge/websites.json" => {
      json => [{
        url_prefix => "https://hoge/$key/",
        source => {type => 'packref', url => "https://hoge/$key/license.json"},
        legal_key => "$key-license",
      }],
    },
    "https://hoge/$key/license.json" => {
      json => {
        type => 'packref',
        source => {type => 'files'},
      },
    },
    "https://hoge/$key/api/action/package_show?id=" . $key => {
      text => q{ {"success": true, "result": {}} },
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    $current->set_o (time2 => time);
    return $current->prepare (undef, {
      "https://hoge/$key/api/action/package_show?id=" . $key => {
        text => q{ {"success": true, "result": {}, "2": true} },
      },
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c, name => 'remote changed but not affected';
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp} < $current->o ('time2');
           is $v->{legal_key}, "$key-license";
           $current->set_o (v1 => $v);
         }
       }},
      {path => "local/data/hoge/package/package.ckan.json",
       text => q{ {"success": true, "result": {}} }},
    ]);
  });
} n => 7, name => 'pull not affected by sha256, package';

Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare ({
    hoge => {
      type => 'ckan', url => "https://hoge/$key/dataset/$key",
      files => {
        "file:index:0" => {
          sha256 => "b5d4045c3f466fa91fe2cc6abe79232a1a57cdf104f7a26e716e0a1e2789df78",
        },
      },
    },
  }, {
    $current->legal_url_prefix . 'packref.json' => {
      json => {
        type => 'packref',
        source => {
          type => 'files',
          files => {
            'file:r:websites.json' => {
              url => "https://hoge/websites.json",
            },
            'file:r:info.json' => {
              url => "info.json",
            },
            'file:r:ckan.json' => {
              url => "ckan.json",
            },
          },
        },
      },
    },
    "https://hoge/websites.json" => {
      json => [{
        url_prefix => "https://hoge/$key/",
        source => {type => 'packref', url => "https://hoge/$key/license.json"},
        legal_key => "$key-license",
      }],
    },
    "https://hoge/$key/license.json" => {
      json => {
        type => 'packref',
        source => {type => 'files'},
      },
    },
    "https://hoge/$key/api/action/package_show?id=" . $key => {
      text => qq{ {"success": true, "result": {
        "resources": [{"url": "https://hoge/$key/abc"}]
      }} },
    },
    "https://hoge/$key/abc" => {text => "ABC"},
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare (undef, {
      "https://hoge/$key/abc" => {text => "ABC2"},
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'remote changed but not affected';
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 2;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, "$key-license";
         }
         {
           my $v = json_bytes2perl $lines->[1];
           ok $v->{timestamp};
           is $v->{legal_key}, "$key-license";
         }
       }},
      {path => "local/data/hoge/files/abc", text => "ABC"},
    ]);
  });
} n => 9, name => 'pull not affected by sha256, file';

Test {
  my $current = shift;
  my $key = "0.794847608133317";
  return $current->prepare ({
    hoge => {
      type => 'ckan', url => "https://hoge/$key/dataset/$key",
      files => {
        "package" => {
          sha256 => "d1ce79aa2690d62508d19db0025dd544b9febc0f1080170a50cd92a95ec5d049",
        },
        "file:index:0" => {
        },
      },
    },
  }, {
    $current->legal_url_prefix . 'packref.json' => {
      json => {
        type => 'packref',
        source => {
          type => 'files',
          files => {
            'file:r:websites.json' => {
              url => "https://hoge/websites.json",
            },
            'file:r:info.json' => {
              url => "info.json",
            },
            'file:r:ckan.json' => {
              url => "ckan.json",
            },
          },
        },
      },
    },
    "https://hoge/websites.json" => {
      json => [{
        url_prefix => "https://hoge/$key/",
        source => {type => 'packref', url => "https://hoge/$key/license.json"},
        legal_key => "$key-license",
      }],
    },
    "https://hoge/$key/license.json" => {
      json => {
        type => 'packref',
        source => {type => 'files'},
      },
    },
    "https://hoge/$key/api/action/package_show?id=" . $key => {
      text => qq{ {"success": true, "result": {
        "resources": [{"url": "https://hoge/$key/abc"}]
      }} },
    },
    "https://hoge/$key/abc" => {text => "ABC"},
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->prepare (undef, {
      "https://hoge/$key/abc" => {text => "ABC2"},
    });
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'remote changed but not affected';
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 2;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, "$key-license";
         }
         {
           my $v = json_bytes2perl $lines->[1];
           ok $v->{timestamp};
           is $v->{legal_key}, "$key-license";
         }
       }},
      {path => "local/data/hoge/files/abc", text => "ABC2"},
    ]);
  });
} n => 9, name => 'pull package freezed but file changed';


Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare ({
    hoge => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
  }, {
    $current->legal_url_prefix . 'packref.json' => {
      json => {
        type => 'packref',
        source => {
          type => 'files',
          files => {
            'file:r:websites.json' => {
              url => "https://hoge/websites.json",
            },
            'file:r:info.json' => {
              url => "info.json",
            },
            'file:r:ckan.json' => {
              url => "ckan.json",
            },
          },
        },
      },
    },
    "https://hoge/websites.json" => {
      json => [{
        url_prefix => "https://hoge/$key/",
        source => {type => 'packref', url => "https://hoge/$key/license.json"},
        legal_key => "$key-license",
      }],
    },
    "https://hoge/$key/license.json" => {
      json => {
        type => 'packref',
        source => {type => 'files', files => {"file:r:404" => {url => 404}}},
      },
    },
    "https://hoge/$key/api/action/package_show?id=" . $key => {
      text => q{ {"success": true, "result": {}} },
    },
  })->then (sub {
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 12;
    } $current->c;
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, "-ddsd-unknown";
         }
       }},
      {path => "local/data/hoge/package/package.ckan.json",
       text => q{ {"success": true, "result": {}} }},
    ]);
  });
} n => 6, name => 'legal broken';


Test {
  my $current = shift;
  my $key = rand;
  return $current->prepare ({
    hoge => {type => 'ckan', url => "https://hoge/$key/dataset/$key"},
  }, {
    $current->legal_url_prefix . 'packref.json' => {
      json => {
        type => 'packref',
        source => {
          type => 'files',
          files => {
            'file:r:websites.json' => {
              url => "https://hoge/websites.json",
            },
            'file:r:info.json' => {
              url => "info.json",
            },
            'file:r:ckan.json' => {
              url => "ckan.json",
            },
          },
        },
      },
    },
    "https://hoge/websites.json" => {
      json => [{
        url_prefix => "https://hoge/$key/",
        source => {type => 'packref', url => "https://hoge/$key/license.json"},
        legal_key => "$key-license",
      }],
    },
    "https://hoge/$key/license.json" => {
      json => {
        type => 'packref',
        source => {type => 'files'},
      },
    },
    "https://hoge/$key/api/action/package_show?id=" . $key => {
      json => {success => \1, result => {
      }},
      etag => '"abc"',
    },
  })->then (sub {
    $current->set_o (time1 => time);
    return $current->run ('pull');
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c;
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         
         is 0+keys %{$json->{items}}, 1;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         ok $json->{items}->{$file_key}->{files}->{log};

         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 1;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp} > $current->o ('time1');
           is $v->{legal_key}, "$key-license";
           $current->set_o (log1 => $v);
         }
       }},
    ]);
  })->then (sub {
    return $current->run ('pull', additional => ['--now' => time + 200*24*24]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 'same response';
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         
         is 0+keys %{$json->{items}}, 1;
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         ok $json->{items}->{$file_key}->{files}->{log};

         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 2;
         {
           my $v = json_bytes2perl $lines->[0];
           is $v->{timestamp}, $current->o ('log1')->{timestamp};
           is $v->{legal_key}, "$key-license";
         }
         {
           my $v = json_bytes2perl $lines->[1];
           ok $v->{timestamp} > $current->o ('log1')->{timestamp};
           is $v->{legal_key}, "$key-license";
           $current->set_o (log2 => $v);
         }
       }},
      {path => $current->repo_path ('packref', $current->legal_url_prefix.'packref.json') . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{$current->legal_url_prefix . "packref.json"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 2;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, undef;
         }
       }},
      {path => $current->repo_path ('packref', "https://hoge/$key/license.json") . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{"https://hoge/$key/license.json"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 2;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, undef;
         }
         {
           my $v = json_bytes2perl $lines->[1];
           ok $v->{timestamp};
           is $v->{legal_key}, undef;
         }
       }},
    ]);
  })->then (sub {
    return $current->prepare (undef, {
      "https://hoge/$key/api/action/package_show?id=" . $key => {
        status => 304,
        if_etag => '"abc"',
      },
    });
  })->then (sub {
    return $current->run ('pull', additional => ['--now' => time + 400*24*24]);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
    } $current->c, name => 304;
    return $current->check_files ([
      {path => $current->repo_path ('ckan', "https://hoge/$key/dataset/$key").'/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         
         my $file_key = $json->{urls}->{"https://hoge/$key/api/action/package_show?id=$key"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 3;
         {
           my $v = json_bytes2perl $lines->[0];
           is $v->{timestamp}, $current->o ('log1')->{timestamp};
           is $v->{legal_key}, "$key-license";
         }
         {
           my $v = json_bytes2perl $lines->[1];
           is $v->{timestamp}, $current->o ('log2')->{timestamp};
           is $v->{legal_key}, "$key-license";
         }
         {
           my $v = json_bytes2perl $lines->[2];
           ok $v->{timestamp} > $current->o ('log2')->{timestamp};
           is $v->{legal_key}, "$key-license";
         }
       }},
      {path => $current->repo_path ('packref', $current->legal_url_prefix.'packref.json') . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{$current->legal_url_prefix . "packref.json"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 3;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, undef;
         }
       }},
      {path => $current->repo_path ('packref', "https://hoge/$key/license.json") . '/index.json', json => sub {
         my $json = shift;
         my $path = shift;
         my $file_key = $json->{urls}->{"https://hoge/$key/license.json"};
         my $log_path = $path->parent->child
             ($json->{items}->{$file_key}->{files}->{log});
         my $lines = [split /\x0A/, $log_path->slurp];
         is 0+@$lines, 3;
         {
           my $v = json_bytes2perl $lines->[0];
           ok $v->{timestamp};
           is $v->{legal_key}, undef;
           $current->set_o (l1 => $v);
         }
         {
           my $v = json_bytes2perl $lines->[1];
           ok $v->{timestamp} > $current->o ('l1')->{timestamp};
           is $v->{legal_key}, undef;
           $current->set_o (l2 => $v);
         }
         {
           my $v = json_bytes2perl $lines->[2];
           ok $v->{timestamp} > $current->o ('l2')->{timestamp};
           is $v->{legal_key}, undef;
         }
       }},
    ]);
  });
} n => 43, name => 're-pulled';


Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
