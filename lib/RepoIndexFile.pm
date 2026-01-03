package RepoIndexFile;
use strict;
use warnings;
use Carp;
use Time::HiRes qw(time);
use JSON::PS;
use Promised::File;

use JSONFile;
push our @ISA, qw(JSONFile);

sub open_by_app_and_storage ($$$;%) {
  my ($class, $app, $storage, %cargs) = @_;

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
    $self->{upstream_index} = $cargs{upstream_index}; # or undef
    $self->{upstream_item} = $cargs{upstream_item}; # or undef
  }; # $init
  
  my $init_empty = sub {
    my ($self, %args) = @_;
    $self->{json} = {type => 'empty', items => {}};
    $self->{storage} = $storage;
    $self->{upstream_index} = $cargs{upstream_index}; # or undef
    $self->{upstream_item} = $cargs{upstream_item}; # or undef
  }; # $init_empty

  my $path = $storage->child_path ('index.json');
  return $class->_open_by_app_and_path
      ($app, $path,
       allow_missing => $cargs{allow_missing}, lock => $cargs{lock},
       format => 'ddsd repo index',
       init => $init, init_empty => $init_empty);
} # open_by_app_and_storage

sub index ($) { $_[0]->{json} }
sub items ($) { $_[0]->{json}->{items} }
sub upstream_index ($) { $_[0]->{upstream_index} }
sub upstream_item ($) { $_[0]->{upstream_item} }

## Return item object for the specified condition.
##
## Exactly one of |url_string| (matches to |url_string| or
## |original_url_string| of items), |path_string|, or
## |raw_path_string| is required.
##
## If |sha256| is specified in |file_def|, the item object whose
## |sha256| is equal to the value, if any, is returned.
sub get_item ($%) {
  my ($self, %args) = @_;
  my $index = $self->{json};

  my $ref;
  if (defined $args{url_string}) {
    if (defined $args{file_def}->{sha256}) {
      $ref = $index->{url_sha256s}->{$args{url_string}, $args{file_def}->{sha256}};
    } else {
      $ref = $index->{urls}->{$args{url_string}};
    }
  } elsif (defined $args{original_url_string}) {
    if (defined $args{file_def}->{sha256}) {
      $ref = $index->{original_url_sha256s}->{$args{original_url_string}, $args{file_def}->{sha256}};
    } else {
      $ref = $index->{original_urls}->{$args{original_url_string}};
    }
  } elsif (defined $args{raw_path_string}) {
    if (defined $args{file_def}->{sha256}) {
      $ref = $index->{raw_path_sha256s}->{$args{raw_path_string}, $args{file_def}->{sha256}};
    } else {
      $ref = $index->{raw_paths}->{$args{raw_path_string}};
    }
  } elsif (defined $args{path_string}) {
    if (defined $args{file_def}->{sha256}) {
      $ref = $index->{path_sha256s}->{$args{path_string}, $args{file_def}->{sha256}};
    } else {
      $ref = $index->{paths}->{$args{path_string}};
    }
  } elsif ($args{allow_no_item}) {
    #
  } else {
    die "No item key", Carp::longmess;
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

## Return the path object for the file with the specified $key in the
## $item listed in the repository index.
sub get_path_of ($$$;%) {
  my ($self, $item, $key, %args) = @_;

  my $name = $item->{files}->{$key};
  if (not defined $name) {
    if ($args{create_if_missing}) {
      my $path = $self->{storage}->create_child_path (prefix => $args{prefix});
      $item->{files}->{$key} = $path->relative ($self->path);
      $self->touch;
      return $path;
    } elsif ($args{allow_missing}) {
      return undef;
    } else {
      return $self->app->logger->throw ({
        type => 'referenced file not found',
        item => $item,
        key => $key,
        path => $self->path->absolute,
      });
    }
  } # $name
  
  return $self->{storage}->child_path ($name);
} # get_path_of
#
sub get_storage_of ($$$;%) {
  my ($self, $item, $key, %args) = @_;

  my $name = $item->{files}->{$key};
  if (not defined $name) {
    if ($args{create_if_missing}) {
      my $storage = $self->{storage}->create_child_storage (prefix => $args{prefix});
      $item->{files}->{$key} = $storage->{path}->relative ($self->{storage}->{path});
      $self->touch;
      return $storage;
    } elsif ($args{allow_missing}) {
      return undef;
    } else {
      return $self->app->logger->throw ({
        type => 'referenced file not found',
        item => $item,
        key => $key,
        path => $self->path->absolute,
      });
    }
  } # $name
  
  return $self->{storage}->child_storage ($name);
} # get_storage_of

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
  {
    my $header = $r->{res}->header ('content-disposition') // '';
    # XXX parser
    if ($header =~ m{;\s*[Ff][Ii][Ll][Ee][Nn][Aa][Mm][Ee]=("[^"]+"|[^";\\]+)}) {
      my $name = $1;
      if ($name =~ s/^"//) {
        $name =~ s/"$//;
      } else {
        $name =~ s/\s+$//;
      }
      $meta->{rev}->{mime_filename} = $name if length $name;
    }
  }
  $meta->{rev}->{length} = $r->{length};
  $meta->{rev}->{sha256} = $r->{sha256} if defined $r->{sha256};
  if ($r->{res}->incomplete) {
    $meta->{rev}->{http_incomplete} = 1;
    $return->{incomplete} = 1;
  }

  $meta->{http_status} = $r->{res}->{status};
  $meta->{http_status_text} = $r->{res}->{status_text};
  # XXX
  for (@{$r->{res}->{headers}}) {
    push @{$meta->{http_headers} ||= []}, [$_->[0], $_->[1]];
  }

  my $storage_path = $self->{storage}->{path};
  my $logger = $self->app->logger;

  my $index = $self->index;
  my $matched = undef;
  my $old_data;
  {
    for my $na (keys %{$index->{items}}) {
      my $it = $index->{items}->{$na};
      if (defined $meta->{rev}->{sha256} and
          defined $it->{rev}->{sha256} and
          defined $meta->{rev}->{url} and
          defined $it->{rev}->{url} and
          $meta->{rev}->{sha256} eq $it->{rev}->{sha256} and
          $meta->{rev}->{url} eq $it->{rev}->{url}) {
        $return->{data_path} = $storage_path->child ($it->{files}->{data});
        if ((($meta->{rev}->{insecure} and $it->{rev}->{insecure}) or
            (not $meta->{rev}->{insecure} and not $it->{rev}->{insecure})) and
            (($meta->{rev}->{http_incomplete} and $it->{rev}->{http_incomplete}) or
            (not $meta->{rev}->{http_incomplete} and not $it->{rev}->{http_incomplete})) and
            (($meta->{rev}->{http_content_type} // '') eq ($it->{rev}->{http_content_type} // ''))) {
          $matched = $na;
          $return->{item} = $it;
          $return->{key} = $na;
        } else {
          $old_data = $it->{files}->{data};
        }
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
  } elsif (defined $old_data) {
    $logger->info ({
      type => 'duplicate data found in repository',
      ref => $key,
      path => $return->{data_path}->absolute,
    });
  }

  my $meta_path = $storage_path->child ("objects/$key-meta.json");
  my $log_path = $storage_path->child ("objects/$key-log.jsonl");
  $meta->{files}->{meta} = "objects/$key-meta.json";

  my $data_path = $storage_path->child ("objects/$key-data.dat");
  if (defined $old_data) {
    $meta->{files}->{data} = $old_data;
  } else {
    $meta->{files}->{data} = "objects/$key-data.dat";
    $return->{data_path} = $data_path;
  }

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

  $return->{key} = $key;
  $return->{new} = 1;

  $logger->info ({
    type => 'file created in repository',
    path => $meta_path->absolute,
  });
  $logger->info ({
    type => 'file created in repository',
    path => $data_path->absolute,
  }) unless defined $old_data;
  $logger->info ({
    type => 'file created in repository',
    path => $log_path->absolute,
  }) if defined $fl;
  return Promise->all ([
    $self->{storage}->write_json ("objects/$key-meta.json", $meta, readonly => 1),
    (defined $old_data ? undef : $self->{storage}->hardlink_from ("objects/$key-data.dat", $r->{path})->then (sub {
      return Promised::File->new_from_path ($r->{path})->chmod (04444);      
    })),
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

  ## Fetch logs.
  ##
  ## An |objects/{key}-log.jsonl| file is a JSON Lines of log JSON
  ## objects.
  ##
  ## A log JSON object is a fetch log JSON object.
  ##
  ## A fetch log JSON object has:
  ##
  ##   |legal_key| : Legal key     The detected legal.
  ##   |timestamp| : Timestamp     The time of the detection, i.e. the fetch.
  ##   |insecure| : Boolean        Whether the fetch is insecure.
  ##   |legal_source_key| : Item key?
  ##       If the legal is specified by a file as a legal URL or
  ##       detected by a sniffing of a file, the file's item key in
  ##       the package repository.
  ##   |legal_packref_url| : URL?
  ##       If the legal is specified by a packref as a legal URL, the
  ##       packref's URL.
  ##   |legal_source_url| : URL?
  ##       If the legal is specified by a file as a legal URL or
  ##       detected by a sniffing, the file's item key in the package
  ##       repository.
  ##   |additionals| : Array?
  ##       If the fetch log JSON object is the topmost log JSON object
  ##       and there are more legals detected, the detected legals as
  ##       fetch log JSON objects.
  ##   |_|                         Informative notes for debugging.
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
    }->{$f} // 'dat');
    $p = $p->then (sub {
      return $self->{storage}->hardlink_from ($name, $files->{$f}->{path});
    })->then (sub {
      return Promised::File->new_from_path ($files->{$f}->{path})->chmod (0444)
          unless $f eq 'log';
    });
  }
  return $logger->throw ({
    type => 'broken file', format => 'mirrorzip index.json',
    value => 'files.data',
    %{$args{error_location}},
  }) unless defined $return->{item}->{files}->{data};
  
  my $data_path = $storage_path->child ("objects/$key-data.dat");
  $return->{data_path} = $self->{storage}->child_path ($return->{item}->{files}->{data});
  $return->{key} = $key;
  $return->{new} = 1;

  return $p->then (sub {
    return $return;
  });
} # put_from_mirrorzip

sub put_zip_item ($$$$;%) {
  my ($self, $file, $zipped, $zip_temp_path, %args) = @_;

  my $return = {};
  
  my $rev = {
    raw_path => $file->{archive_item}->{central}->{raw_path},
    path => $file->{archive_item}->{path},
    timestamp => $file->{archive_item}->{mtime},
    sha256 => $zipped->{sha256},
    length => $zipped->{length},
  };
  $rev->{insecure} = 1 if $args{insecure};
  $rev->{path_encoding} = $file->{archive_item}->{path_encoding}
      if defined $file->{archive_item}->{path_encoding};

  my $logger = $self->app->logger;

  my $index = $self->index;
  $self->touch;
  my $item = $return->{item} = $index->{items}->{$file->{key}} = {
    type => $args{type} // 'file',
    rev => $rev,
    files => {},
  };

  my $data_path = $self->{storage}->create_child_path
      (dir_name => 'objects', ext => 'dat');
  $return->{data_path} = $data_path;
  my $name = $item->{files}->{data} = $data_path->relative ($self->{storage}->{path});
  my $p = $self->{storage}->hardlink_from ($name, $zip_temp_path)->then (sub {
    return Promised::File->new_from_path ($zip_temp_path)->chmod (0444);
  });
  
  $return->{key} = $file->{key};
  $return->{new} = 1;

  $index->{raw_paths}->{$file->{archive_item}->{central}->{raw_path}} = $file->{key};
  $index->{paths}->{$file->{archive_item}->{path}} = $file->{key};
  if (defined $rev->{sha256}) {
    $index->{raw_path_sha256s}->{$file->{archive_item}->{central}->{raw_path}, $rev->{sha256}} = $file->{key};
    $index->{path_sha256s}->{$file->{archive_item}->{path}, $rev->{sha256}} = $file->{key};
  }

  return $p->then (sub {
    return $return;
  });
} # put_zip_item

1;

=head1 LICENSE

Copyright 2024-2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
