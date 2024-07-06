package Tests::Current;
use strict;
use warnings;
use Path::Tiny;
use File::Temp;
use JSON::PS;
use Promise;
use Promised::Flow;
use Promised::Command;
use Promised::File;
use Digest::SHA qw(sha256_hex);
use Web::Encoding;
use Web::URL;
use Web::Transport::BasicClient;
use Web::Transport::ENVProxyManager;
use Test::X1;
use Test::More;

sub new ($$$$) {
  my ($class, $c, $root_path, $opts) = @_;
  my $self = bless {c => $c, %$opts}, $class;

  $self->{ddsd_path} = $root_path->child ('ddsd')->absolute;
  $self->{perl_path} = $root_path->child ('perl')->absolute;
  $self->{zipper_path} = $root_path->child ('bin/zipper.pl')->absolute;
  
  $self->{_temp} = File::Temp->newdir (CLEANUP => ! $ENV{TEST_NO_CLEANUP});
  $self->{temp_path} = path ($self->{_temp}->dirname)->absolute;
  $self->{show_log} //= $ENV{TEST_DEBUG};
  
  return $self;
} # new

sub c ($) { $_[0]->{c} }
sub app_path ($) { $_[0]->{temp_path}->child ($_[1]) }

sub repo_path ($$$) {
  my ($self, $type, $key) = @_;
  my $host;
  $host = lc $1 if $key =~ m{^https?://([0-9A-Za-z_.%-]+)/};
  die $key unless defined $host;
  $host =~ s/%/_/g;
  my $hash = sha256_hex encode_web_utf8 $key;
  return path ('local/ddsd/repo/'.$type.'/' . $host . '/' . $hash);
} # repo_path

sub legal_url_prefix ($) { q<https://raw.githubusercontent.com/geocol/ddsd-data/master/legal/> }
sub mirrors_url_prefix ($) { q<https://raw.githubusercontent.com/geocol/ddsd-data/master/mirrors/> }

sub xs_client ($) {
  my $self = $_[0];
  return $self->{xs_client} //= Web::Transport::BasicClient->new_from_url
      (Web::URL->parse_string ("http://xs.server.test"), {
        proxy_manager => Web::Transport::ENVProxyManager->new_from_envs ($self->{client_envs}),
      });
} # xs_client

sub run ($$;%) {
  my ($self, $subcommand, %args) = @_;
  my $log_path = $self->{temp_path}->child (rand);
  my $cmd = Promised::Command->new ([
    $self->{ddsd_path},
    (defined $subcommand ? $subcommand : ()),
    ($args{insecure} ? '--insecure' : ()),
    ((not defined $args{cacert} or $args{cacert}) ? '--cacert=' . $self->{ca_cert_path}->absolute : ()),
    ($args{logs} ? ('--log-file', $log_path) : $self->{show_log} ? ('--log-file', '/dev/stderr') : ()),
    @{$args{additional} or []},
  ]);
  $cmd->wd ($self->app_path ($args{app} || 0));
  my $stdout;
  if ($args{lines} or $args{jsonl} or $args{stdout} or $args{json}) {
    $cmd->stdout (\$stdout);
  }
  my $stderr;
  if ($args{stderr}) {
    $cmd->stderr (\$stderr);
  }
  for my $key (keys %{$self->{client_envs}}) {
    $cmd->envs->{$key} = $self->{client_envs}->{$key};
  }
  return $cmd->run->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    my $r = {
      exit_code => $result->exit_code,
    };
    if ($args{lines} or $args{jsonl}) {
      $r->{lines} = [split /\x0A/, $stdout];
      if ($args{jsonl}) {
        $r->{jsonl} = [map { json_bytes2perl $_ } grep { length } @{$r->{lines}}];
      }
    } elsif ($args{json}) {
      $r->{json} = json_bytes2perl $stdout;
    }
    if ($args{stdout}) {
      if ($args{stdout} eq 'text') {
        $r->{stdout} = decode_web_utf8 $stdout;
      } else {
        $r->{stdout} = $stdout;
      }
    }
    if ($args{stderr}) {
      $r->{stderr} = $stderr;
    }
    if ($args{logs}) {
      return Promised::File->new_from_path ($log_path)->read_byte_string->then (sub {
        $r->{logs} = [map { json_bytes2perl $_ } split /\x0A/, $_[0]];
        print STDERR $_[0] if $self->{show_log};
        return $r;
      });
    } else {
      return $r;
    }
  });
} # run

sub o ($$) { $_[0]->{o}->{$_[1]} }
sub set_o ($$$) { $_[0]->{o}->{$_[1]} = $_[2] }

sub prepare ($$$;%) {
  my ($self, $packages, $remote, %args) = @_;
  my $client = $self->xs_client;

  unless ($self->{prepared}) {
    $remote->{$self->legal_url_prefix . 'packref.json'} //= {
      json => {type => 'packref', source => {type => 'files', files => {
        'file:r:ckan.json' => {url => 'ckan.json'},
        'file:r:websites.json' => {url => 'websites.json'},
        'file:r:info.json' => {url => 'info.json'},
      }}},
    };
    $remote->{$self->legal_url_prefix . 'ckan.json'} //= {
      json => [],
    };
    $remote->{$self->legal_url_prefix . 'websites.json'} //= {
      json => [],
    };
    $remote->{$self->legal_url_prefix . 'info.json'} //= {
      json => {},
    };
    $remote->{$self->mirrors_url_prefix . 'packref.json'} //= {
      json => {type => 'packref', source => {type => 'files', files => {
        map { 
          (
            "file:r:ckan-$_.hoge" => {url => $self->mirrors_url_prefix."hash-ckan-$_.hoge.jsonl"},
            "file:r:ckansite-$_.hoge" => {url => $self->mirrors_url_prefix."hash-ckansite-$_.hoge.jsonl"},
            "file:r:packref-$_.hoge" => {url => $self->mirrors_url_prefix."hash-packref-$_.hoge.jsonl"},
          );
        } 1..9,
      }}},
    };
    for (1..9) {
      $remote->{$self->mirrors_url_prefix."hash-ckan-$_.hoge.jsonl"} //= {text => ''};
      $remote->{$self->mirrors_url_prefix."hash-ckansite-$_.hoge.jsonl"} //= {text => ''};
      $remote->{$self->mirrors_url_prefix."hash-packref-$_.hoge.jsonl"} //= {text => ''};
    }
  }
  $self->{prepared} = 1;

  return Promise->resolve->then (sub {
    if (not defined $packages and not $args{null}) {
      my $path = $self->app_path ($args{app} || 0);
      my $file = Promised::File->new_from_path ($path);
      return $file->mkpath;
    } else {
      my $path = $self->app_path ($args{app} || 0)->child ('config/ddsd/packages.json');
      my $file = Promised::File->new_from_path ($path);
      return $file->write_byte_string (perl2json_bytes $packages);
    }
  })->then (sub {
    return $client->request (
      method => 'PUT',
      path => [],
      body => (perl2json_bytes $remote),
    )->then (sub {
      my $res = $_[0];
      die $res unless $res->status == 200;
    });
  })->then (sub {
    return promised_for {
      my $name = shift;
      my $path = $self->app_path ($args{app} || 0)->child ($name);
      my $file = Promised::File->new_from_path ($path);
      my $def = $args{files}->{$name};
      return Promise->resolve->then (sub {
        if (defined $def->{text}) {
          return $file->write_byte_string (encode_web_utf8 $def->{text});
        } elsif (defined $def->{bytes}) {
          return $file->write_byte_string ($def->{bytes});
        } else {
          die "Bad file definition for |$name|";
        }
      })->then (sub {
        return unless defined $def->{code};
        return $def->{code}->($path);
      });
    } [keys %{$args{files} || {}}];
  })->then (sub {
    return unless defined $args{post};
    return $args{post}->($self->app_path ($args{app} || 0));
  });
} # prepare

sub get_access_count ($$) {
  my ($self, $u) = @_;
  my $client = $self->xs_client;
  return $client->request (
    method => 'GET',
    path => ['COUNT'],
    params => {
      'url' => Web::URL->parse_string ($u)->stringify,
    },
  )->then (sub {
    my $res = $_[0];
    die $res unless $res->status == 200;
    return 0+$res->body_bytes;
  });
} # get_access_count

sub check_files ($$;%) {
  my ($self, $tests, %args) = @_;
  my $has_error = 0;
  return Promise->resolve->then (sub {
    return promised_for {
      my $test = shift;

      my $specified_path = ref $test->{path} eq 'ARRAY' ? $test->{path} : [$test->{path}];
      die "Bad |path|" unless @$specified_path;

      my $path0 = $self->app_path ($args{app} || 0)->child (shift @$specified_path);
      my $current_path = $path0;
      if (@$specified_path == 0 and $test->{is_none}) {
        return Promised::File->new_from_path ($current_path)->lstat->then (sub {
          test {
            ok 0, "@$specified_path is not found";
          } $self->c;
        }, sub {
          #
        });
      }

      return Promise->resolve->then (sub {
        return unless @$specified_path;
        return promised_until {
          my $next_path = shift @$specified_path;
          die "Bad path" unless defined $next_path;
          my $in_path = $self->app_path ($args{app} || 0)->child (rand);
          my $x_path = $self->app_path ($args{app} || 0)->child (rand);
          return Promised::File->new_from_path ($in_path)->write_byte_string (perl2json_bytes {
            command => 'extract',
            input_file_name => $current_path,
            file_name => $next_path,
            output_file_name => $x_path,
          })->then (sub {
            my $cmd = Promised::Command->new ([
              $self->{perl_path},
              $self->{zipper_path},
              $in_path,
            ]);
            if (@$specified_path == 0 and $test->{is_none}) {
              return $cmd->run->then (sub {
                return $cmd->wait;
              })->then (sub {
                my $result = $_[0];
                die $result unless $result->exit_code == 0;
                $current_path = $x_path;
                test {
                  ok 0, join " ", @{$test->{path}};
                } $self->c;
              }, sub {
                my $e = $_[0];
                test {
                  ok 1, $e;
                } $self->c;
              });
            } else {
              return $cmd->run->then (sub {
                return $cmd->wait;
              })->then (sub {
                my $result = $_[0];
                die $result unless $result->exit_code == 0;
                $current_path = $x_path;
                return @$specified_path ? not 'done' : 'done';
              });
            }
          });
        };
      })->then (sub {
        if ($test->{is_none}) {
          return;
        } elsif ($test->{readonly}) {
          return Promised::File->new_from_path ($current_path)->stat->then (sub {
            my $mode = $_[0]->[2] & 0777;
            test {
              is $mode, 0444, 'mode readonly';
            } $self->c, name => $specified_path;
          });
        }
      })->then (sub {
        if ($test->{is_none}) {
          return;
        } elsif (defined $test->{check}) {
          return test {
            return $test->{check}->($current_path);
          } $self->c, name => $specified_path;
        } elsif (defined $test->{text}) {
          return Promised::File->new_from_path ($current_path)->read_byte_string->then (sub {
            my $text = decode_web_utf8 $_[0];
            if (ref $test->{text}) {
              return test {
                return $test->{text}->($text, $current_path);
              } $self->c, name => $specified_path;
            } else {
              return test {
                is $text, $test->{text}, 'file content text matched';
              } $self->c, name => $specified_path;
            }
          }, sub {
            my $e = $_[0];
            test {
              is $e, undef, "@$specified_path ($current_path) found";
            } $self->c;
          });
        } elsif ($test->{json}) {
          return Promised::File->new_from_path ($current_path)->read_byte_string->then (sub {
            my $json = json_bytes2perl $_[0];
            return test {
              return $test->{json}->($json, $current_path);
            } $self->c, name => $specified_path;
          }, sub {
            my $e = $_[0];
            test {
              is $e, undef, "@$specified_path found";
            } $self->c;
          });
        } elsif ($test->{jsonl}) {
          return Promised::File->new_from_path ($current_path)->read_byte_string->then (sub {
            my $json = [map { json_bytes2perl $_ } split /\x0A/, $_[0]];
            return test {
              return $test->{jsonl}->($json, $current_path);
            } $self->c, name => $specified_path;
          }, sub {
            my $e = $_[0];
            test {
              is $e, undef, "@$specified_path found";
            } $self->c;
          });
        } elsif ($test->{zip}) {
          my $in_path = $self->app_path ($args{app} || 0)->child (rand);
          return Promised::File->new_from_path ($in_path)->write_byte_string (perl2json_bytes {
            command => 'list',
            input_file_name => $current_path,
          })->then (sub {
            my $cmd = Promised::Command->new ([
              $self->{perl_path},
              $self->{zipper_path},
              $in_path,
            ]);
            $cmd->stdout (\my $stdout);
            return $cmd->run->then (sub {
              return $cmd->wait;
            })->then (sub {
              my $result = $_[0];
              die $result unless $result->exit_code == 0;
              my $out = json_bytes2perl [grep { length } split /\n/, $stdout]->[-1];
              return test {
                my $files = {};
                for (@{$out->{files}}) {
                  $files->{$_->{name}} = $_;
                }
                return $test->{zip}->($files, $current_path);
              } $self->c, name => $specified_path;
            }, sub {
              my $e = $_[0];
              test {
                is $e, undef, "@$current_path found";
              } $self->c;
            });
          });
        } else {
          die "Broken test: " . perl2json_bytes $test;
        }
      });
    } $tests;
  })->then (sub {
    unless ($has_error) {
      test {
        ok 1;
      } $self->c;
    }
  });
} # check_files

sub close ($) {
  my $self = $_[0];
  return Promise->all ([
    (defined $self->{xs_client} ? $self->{xs_client}->close : undef),
  ]);
} # close

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
