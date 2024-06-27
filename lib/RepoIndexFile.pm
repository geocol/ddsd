package RepoIndexFile;
use strict;
use warnings;
use Time::HiRes qw(time);
use JSON::PS;

use JSONFile;
push our @ISA, qw(JSONFile);

sub open_by_repo ($$;%) {
  my ($class, $repo, %args) = @_;
  my $storage = $repo->storage;

  my $init = sub {
    my ($self, $logger, $path, $index, %args) = @_;
    return $logger->throw ({
      type => 'broken file', format => $args{format},
      path => $path,
    }) unless defined $index and ref $index eq 'HASH';
    $index->{type} //= '';

    for my $key (qw(items url_sha256s urls)) {
      $index->{$key} //= {};
      if (not ref $index->{$key} eq 'HASH') {
        return $logger->throw ({
          type => 'broken file', format => $args{format},
          path => $path,
          value => $key,
        });
      }
      for my $v (values %{$index->{$key}}) {
        if (not defined $v and ref $v eq 'HASH') {
          return $logger->throw ({
            type => 'broken file', format => $args{format},
            path => $path,
            value => $key,
          });
        }

        if ($key eq 'items') {
          if (defined $v->{rev} and not ref $v->{rev} eq 'HASH') {
            return $logger->throw ({
              type => 'broken file', format => $args{format},
              path => $path,
              value => 'rev',
            });
          }
          if (defined $v->{files} and not ref $v->{files} eq 'HASH') {
            return $logger->throw ({
              type => 'broken file', format => $args{format},
              path => $path,
              value => 'files',
            });
          }
        }
      }
    } # $key

    $self->{json} = $index;
    $self->{storage} = $storage;
  };
  
  my $init_empty = sub {
    my ($self, %args) = @_;
    $self->{json} = {type => 'empty', items => {}};
    $self->{storage} = $storage;
  };

  my $path = $repo->storage->{path}->child ('index.json');
  return $class->_open_by_app_and_path
      ($repo->set->app, $path,
       allow_missing => $args{allow_missing}, lock => $args{lock},
       format => 'ddsd repo index',
       init => $init, init_empty => $init_empty);
} # open_by_repo

sub index ($) { $_[0]->{json} }
sub items ($) { $_[0]->{json}->{items} }

sub get_item ($$;%) {
  my ($self, $url_string, %args) = @_;
  my $index = $self->{json};

  my $ref;
  if (defined $args{file_def}->{sha256}) {
    $ref = $index->{url_sha256s}->{$url_string, $args{file_def}->{sha256}};
  } else {
    $ref = $index->{urls}->{$url_string};
  }
  return (undef, undef) unless defined $ref;
  
  my $item = $index->{items}->{$ref};
  return $self->app->logger->throw ({
    type => 'referenced item not found',
    ref => $ref,
    path => $self->path->absolute,
  }) if not defined $item;

  return ($ref, $item);
} # get_item

sub get_timestamp_of ($$) {
  my ($self, $path_string) = @_;
  my $path = $self->{path}->parent->child ($path_string);
  my $file = Promised::File->new_from_path ($path);
  return $file->stat->then (sub {
    my $stat = $_[0];
    return $stat->mtime;
  });
} # get_timestamp_of

sub ensure_type ($$) {
  my ($self, $type) = @_;
  die "Not locked" unless defined $self->{lock};
  
  if ($self->{json}->{type} eq 'empty') {
    $self->{json}->{type} = $type;
    $self->touch;
  } elsif ($self->{json}->{type} eq $type) {
    #
  } else {
    return $self->app->logger->throw ({
      type => 'broken file', format => $self->{format},
      key => 'type', value => $self->{json}->{type},
      path => $self->path->absolute,
    });
  }
} # ensure_type

sub put_response ($$$) {
  my ($self, $r, %args) = @_;

  my $return = {};
  
  my $meta = {};
  $meta->{rev}->{timestamp} = time;
  $meta->{rev}->{url} = $r->{url}->stringify;
  $meta->{rev}->{original_url} = $r->{original_url}->stringify;
  $meta->{rev}->{insecure} = 1 if $r->{insecure};

  my $dtp = Web::DateTime::Parser->new;
  $dtp->onerror (sub { });
  {
    my $dt = $dtp->parse_http_date_string ($r->{res}->header ('date') // '');
    $meta->{rev}->{http_date} = $dt->to_unix_number if defined $dt;
  }
  {
    my $dt = $dtp->parse_http_date_string ($r->{res}->header ('last-modified') // '');
    $meta->{rev}->{http_last_modified} = $dt->to_unix_number if defined $dt;
  }
  {
    $meta->{rev}->{http_etag} = $r->{res}->header ('etag') // '';
    delete $meta->{rev}->{http_etag}
        unless $meta->{rev}->{http_etag} =~ m{\A"[^"]+"\z};
  }
  $meta->{rev}->{http_content_type} = $r->{res}->header ('content-type');
  delete $meta->{rev}->{http_content_type}
      unless defined $meta->{rev}->{http_content_type};
  $meta->{rev}->{length} = $r->{length};
  $meta->{rev}->{sha256} = $r->{sha256} if defined $r->{sha256};

  $meta->{http_status} = $r->{res}->{status};
  $meta->{http_status_text} = $r->{res}->{status_text};
  # XXX
  for (@{$r->{res}->{headers}}) {
    push @{$meta->{http_headers} ||= []}, [$_->[0], $_->[1]];
  }
  $meta->{http_incomplete} = 1 if $r->{res}->incomplete;

  my $storage_path = $self->{storage}->{path};
  my $logger = $self->app->logger;

  my $index = $self->index;
  my $matched = undef;
  if (not $args{force}) {
    for my $na (keys %{$index->{items}}) {
      my $it = $index->{items}->{$na};
      if (defined $meta->{rev}->{sha256} and
          defined $it->{rev}->{sha256} and
          defined $meta->{rev}->{url} and
          defined $it->{rev}->{url} and
          $meta->{rev}->{sha256} eq $it->{rev}->{sha256} and
          $meta->{rev}->{url} eq $it->{rev}->{url}) {
        $matched = $na;
        $return->{item} = $it;
        $return->{key} = $na;
        $return->{data_path} = $storage_path->child ($it->{files}->{data});
        last;
      } elsif (defined $meta->{rev}->{http_etag} and
               defined $it->{rev}->{http_etag} and
               defined $meta->{rev}->{url} and
               defined $it->{rev}->{url} and
               $meta->{rev}->{http_etag} eq $it->{rev}->{http_etag} and
               $meta->{rev}->{http_url} eq $it->{rev}->{url}) {
        $matched = $na;
        $return->{item} = $it;
        $return->{key} = $na;
        $return->{data_path} = $storage_path->child ($it->{files}->{data});
        last;
      } elsif (defined $meta->{rev}->{http_last_modified} and
               defined $it->{rev}->{http_last_modified} and
               defined $meta->{rev}->{length} and
               defined $it->{rev}->{length} and
               defined $meta->{rev}->{url} and
               defined $it->{rev}->{url} and
               $meta->{rev}->{http_last_modified} == $it->{rev}->{http_last_modified} and
               $meta->{rev}->{length} == $it->{rev}->{length} and
               $meta->{rev}->{url} eq $it->{rev}->{url}) {
        $matched = $na;
        $return->{item} = $it;
        $return->{key} = $na;
        $return->{data_path} = $storage_path->child ($it->{files}->{data});
        last;
      }
    }
  }

  my $key = $matched;
  unless (defined $matched) {
    $key = '' . rand;
    $key = '' . rand while defined $index->{items}->{$key};
  }
  $self->touch;
  $index->{urls}->{$meta->{rev}->{url}} = $key;
  $index->{urls}->{$meta->{rev}->{original_url}} = $key;

  if (defined $matched) {
    $logger->info ({
      type => 'duplicate item found in repository',
      ref => $matched,
      path => $storage_path->absolute,
    });
    $return->{not_modified} = 1;
    $args{fetch_log}->{_} = 'dup' if defined $args{fetch_log};
    return $self->put_fetch_log_by_item_key ($matched, %args)->then (sub {
      return $return;
    });
  }

  my $meta_path = $storage_path->child ("objects/$key-meta.json");
  my $data_path = $storage_path->child ("objects/$key-data.dat");
  my $log_path = $storage_path->child ("objects/$key-log.jsonl");
  $meta->{files}->{meta} = "objects/$key-meta.json";
  $meta->{files}->{data} = "objects/$key-data.dat";

  my $fl = $args{fetch_log} || {};
  for my $key (@{[keys %$fl]}) {
    delete $fl->{$key} unless defined $fl->{$key};
  }
  if (1 < keys %$fl) { # timestamp
    $meta->{files}->{log} = "objects/$key-log.jsonl";
  } else {
    undef $fl;
  }

  $return->{item} = $index->{items}->{$key} = {
    type => $args{type} // 'file',
    rev => $meta->{rev},
    files => $meta->{files},
  };
  if (defined $meta->{rev}->{sha256}) {
    $index->{url_sha256s}->{$meta->{rev}->{url}, $meta->{rev}->{sha256}} = $key;
    $index->{url_sha256s}->{$meta->{rev}->{original_url}, $meta->{rev}->{sha256}} = $key;
  }

  $return->{data_path} = $data_path;
  $return->{key} = $key;
  $return->{new} = 1;

  $logger->info ({
    type => 'file created in repository',
    path => $meta_path->absolute,
  });
  $logger->info ({
    type => 'file created in repository',
    path => $data_path->absolute,
  });
  $logger->info ({
    type => 'file created in repository',
    path => $log_path->absolute,
  }) if defined $fl;
  return Promise->all ([
    $self->{storage}->write_json ("objects/$key-meta.json", $meta),
    $self->{storage}->hardlink_from ("objects/$key-data.dat", $r->{path}),
    (defined $fl ? $self->{storage}->write_jsonl ("objects/$key-log.jsonl", [$fl]) : undef),
  ])->then (sub {
    return $return;
  });
} # put_response

sub put_fetch_log_by_item_key ($$;%) {
  my ($self, $key, %args) = @_;

  my $fl = $args{fetch_log} || {};
  for my $key (@{[keys %$fl]}) {
    delete $fl->{$key} unless defined $fl->{$key};
  }
  if (1 < keys %$fl) { # timestamp
    #
  } else {
    return Promise->resolve;
  }

  my $logger = $self->app->logger;
  my $index = $self->index;
  my $item = $index->{items}->{$key} // die "Bad item key |$key|";
  my $storage_path = $self->{storage}->{path};
  if (not defined $item->{files}->{log}) {
    $item->{files}->{log} = "objects/$key-log.jsonl";
    $self->touch;
    $logger->info ({
      type => 'file created in repository',
      path => $storage_path->child ($item->{files}->{log})->absolute,
    });
  }
  my $log_path = $storage_path->child ($item->{files}->{log});

  my $log_file = $log_path->opena;
  print $log_file perl2json_bytes $fl;
  print $log_file "\x0A";
  
  return Promise->resolve;
} # put_fetch_log_by_item_key

sub put_from_mirrorzip ($$$;%) {
  my ($self, $files, $rev, %args) = @_;

  my $return = {};

  $rev = {%$rev};
  $rev->{insecure} = 1 if $args{insecure};
  $rev->{from_mirrorzip} = 1;

  my $logger = $self->app->logger;
  if (not defined $files->{data}) {
    return $logger->throw ({
      type => 'mirrorzip no data file',
      %{$args{error_location}},
    });
  }

  if (not defined $rev->{length} or
      not defined $rev->{sha256} or
      $files->{data}->{length} != $rev->{length} or
      $files->{data}->{sha256} ne $rev->{sha256}) {
    return $logger->throw ({
      type => 'mirrorzip broken data file',
      %{$args{error_location}},
    });
  }

  my $index = $self->index;
  my $key = '' . rand;
  $key = '' . rand while defined $index->{items}->{$key};

  $self->touch;
  $index->{urls}->{$rev->{url}} = $key;
  $index->{urls}->{$rev->{original_url}} = $key;
  $index->{url_sha256s}->{$rev->{url}, $rev->{sha256}} = $key;
  $index->{url_sha256s}->{$rev->{original_url}, $rev->{sha256}} = $key;
  
  $return->{item} = $index->{items}->{$key} = {
    type => $args{type} // 'file',
    rev => $rev,
    files => {},
  };

  my $storage_path = $self->{storage}->{path};
  my $p = Promise->resolve;
  for my $f (keys %$files) {
    return $logger->throw ({
      type => 'broken file', format => 'mirrorzip index.json',
      value => $f,
      %{$args{error_location}},
    }) unless $f =~ /\A[0-9a-z]+\z/;
    my $name = $return->{item}->{files}->{$f} = "objects/$key-$f." . ({
      meta => 'json',
      log => 'jsonl',
    }->{$key} // 'dat');
    $p = $p->then (sub {
      return $self->{storage}->hardlink_from ($name, $files->{$f}->{path});
    });
  }
  
  my $data_path = $storage_path->child ("objects/$key-data.dat");
  $return->{data_path} = $data_path;
  $return->{key} = $key;
  $return->{new} = 1;

  return $p->then (sub {
    return $return;
  });
} # put_from_mirrorzip

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
