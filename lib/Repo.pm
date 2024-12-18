package Repo;
use strict;
use warnings;
use Promise;
use Promised::Flow;
use Promised::File;
use Time::HiRes qw(time);
use Digest::SHA qw(sha256_hex);
use Web::Encoding;
use Web::DateTime;
use Web::URL;
use JSON::PS;

use Zipper;
use Fetcher;
use RepoIndexFile;

sub set ($) { $_[0]->{set} // die }
sub type ($) { die }

sub _set_key ($$) {
  my ($self, $u) = @_;
  my @v = ($self->type);
  if ($u =~ m{^[a-z0-9]+://([0-9A-Za-z%][0-9A-Za-z.%-]*)/}) {
    my $authority = $1;
    $authority =~ tr/A-Z%/a-z_/;
    $authority = substr $authority, 0, 31;
    push @v, $authority;
  }
  push @v, sha256_hex encode_web_utf8 $u;
  $self->{key} = \@v;
} # _set_key

sub storage ($) {
  my $self = $_[0];
  return $self->{storage} //= $self->set->storage->child (@{$self->{key}});
} # storage

sub read_index ($) {
  return RepoIndexFile->open_by_repo ($_[0], allow_missing => 1);
} # read_index

sub lock_index ($) {
  return RepoIndexFile->open_by_repo ($_[0], allow_missing => 1, lock => 1);
} # lock_index

sub __find_mirror ($$) {
  my ($self, $def) = @_;
  my $logger = $self->set->app->logger;
  
  my $hash = $self->_get_source_snapshot_hash ($def);
  return undef unless defined $hash;

  my $type = $def->{type};
  return undef unless defined $type and $type =~ /\A[0-9a-z]+\z/;
  
  my $url = defined $def->{url} ? Web::URL->parse_string ($def->{url}) : undef;
  return undef unless defined $url and $url->is_http_s;

  my $host = $url->host->to_ascii;
  return undef unless $host =~ /\A[0-9a-z][0-9a-z.-]+\z/;

  $logger->message ({
    type => 'find mirrorzip',
    key => $host,
    value => $hash,
    url => $def->{url},
  });

  my $name = 'hash-' . $type . '-' . $host . '.jsonl';
  my $path = $self->set->app->ddsd_data_area->storage->{path}->child
      ('mirrors/files', $name);
  my $file = Promised::File->new_from_path ($path);
  return $file->read_byte_string->then (sub { # XXX JSONL
    my $lines = [split /\x0A/, $_[0]];
    for (@$lines) {
      my $json = json_bytes2perl $_;
      if (defined $json and ref $json eq 'ARRAY' and $json->[0] eq $hash) {
        my $murl = Web::URL->parse_string ($json->[1] // '');
        if (defined $murl and $murl->scheme eq 'https') {
          return [$murl, $json->[2] // ''];
        }
      }
    }
    return undef;
  }, sub {
    return undef;
  });
} # __find_mirror

sub _find_mirror ($$$) {
  my ($self, $key, $def) = @_;
  my $logger = $self->set->app->logger;
  return Promise->resolve->then (sub {
    die "|storage| is used" if defined $self->{storage};
    die "Duplicate invocation" if defined $self->{mirror_url};
    return undef if $def->{no_mirror};
    return $self->__find_mirror ($def);
  })->then (sub {
    my ($mirror_url, $mirror_sha256) = @{$_[0] // []};
    if (defined $mirror_url) {
      $self->{mirror_url} = $mirror_url;
      $self->{mirror_sha256} = $mirror_sha256;
      my $host = $mirror_url->host->to_ascii;
      $host =~ s/%/_/g;
      $host = substr $host, 0, 31;
      unshift @{$self->{key}}, 'mirrorzip', $host,
          sha256_hex encode_web_utf8 $mirror_url->stringify;
      $logger->message ({
        type => 'mirrorzip selected',
        key => $key,
        url => $mirror_url->stringify,
      });
    } else {
      $logger->message ({
        type => 'mirror not selected',
        key => $key,
      });
    }

    require PackageStateListFile;
    return PackageStateListFile->open_by_app ($self->set->app, allow_missing => 1, lock => 1)->then (sub {
      my $states = $_[0];
      my $ss = $states->get ($key);
      return $logger->throw ({
        type => 'broken file', format => 'ddsd package state list',
        path => $states->path->absolute,
        key => 'mirror_url',
      }) if
          (defined $ss->{$def->{type}} and not ref $ss->{$def->{type}} eq 'HASH') or
          (defined $ss->{$def->{type}}->{$def->{url}} and not ref $ss->{$def->{type}}->{$def->{url}} eq 'HASH');
      $ss->{$def->{type}}->{$def->{url}}->{mirror_url} = $self->{mirror_url}; # or undef
      $ss->{$def->{type}}->{$def->{url}}->{mirror_sha256} = $self->{mirror_sha256}; # or undef
      $states->touch;
      return $states->save;
    }) if defined $def->{url};
  });
} # _find_mirror

sub _use_mirror ($$$) {
  my ($self, $key, $def) = @_;
  require PackageStateListFile;
  return PackageStateListFile->open_by_app ($self->set->app, allow_missing => 1)->then (sub {
    die "|storage| is used" if defined $self->{storage};
    die "Duplicate invocation" if defined $self->{mirror_url};
    my $states = $_[0];
    my $ss = $states->get ($key);
    my $logger = $self->set->app->logger;
    if (defined $def->{url} and
        defined $ss->{$def->{type}} and ref $ss->{$def->{type}} eq 'HASH' and
        defined $ss->{$def->{type}}->{$def->{url}} and ref $ss->{$def->{type}}->{$def->{url}} eq 'HASH' and
        defined $ss->{$def->{type}}->{$def->{url}}->{mirror_url}) {
      my $mirror_url = Web::URL->parse_string
          ($ss->{$def->{type}}->{$def->{url}}->{mirror_url});
      return $logger->throw ({
        type => 'bad URL',
        key => 'mirror_url',
        value => $ss->{$def->{type}}->{$def->{url}}->{mirror_url},
      }) if not defined $mirror_url or not $mirror_url->is_http_s;
      $self->{mirror_url} = $mirror_url->stringify;
      $self->{mirror_sha256} = $ss->{$def->{type}}->{$def->{url}}->{mirror_sha256} // '';
      my $host = $mirror_url->host->to_ascii;
      $host =~ s/%/_/g;
      $host = substr $host, 0, 31;
      unshift @{$self->{key}}, 'mirrorzip', $host,
          sha256_hex encode_web_utf8 $mirror_url->stringify;
      $logger->message ({
        type => 'mirrorzip selected using states',
        url => $mirror_url->stringify,
      });
    } else {
      $logger->info ({
        type => 'mirror not selected using states',
      });
    }
  });
} # _use_mirror

sub _check_legal ($);
sub _check_legal ($) {
  return 0 unless defined $_[0] and ref $_[0] eq 'HASH';
  return 0 unless defined $_[0]->{type};
  if (defined $_[0]->{conditional}) {
    return 0 if not ref $_[0]->{conditional} eq 'ARRAY';
    for (@{$_[0]->{conditional}}) {
      return 0 unless _check_legal ($_);
    }
  }
  if (defined $_[0]->{alt}) {
    return 0 if not ref $_[0]->{alt} eq 'ARRAY';
    for (@{$_[0]->{alt}}) {
      return 0 unless _check_legal ($_);
    }
  }
  if (defined $_[0]->{notice}) {
    return 0 if not ref $_[0]->{notice} eq 'HASH';
    for (qw(title holder template template_not_modified)) {
      if (defined $_[0]->{notice}->{$_}) {
        return 0 if not ref $_[0]->{notice}->{$_} eq 'HASH';
        return 0 if not defined $_[0]->{notice}->{$_}->{value};
      }
    }
  }
  return 1;
} # _check_legal

sub validate_legal ($) {
  my $legal = $_[0];
  return 0 unless defined $legal and ref $legal eq 'HASH';

  return 0 unless defined $legal->{legal} and ref $legal->{legal} eq 'ARRAY';

  for (@{$legal->{legal}}) {
    return 0 unless _check_legal ($_);
  }
  
  return 1;
} # validate_legal

sub _fetch_file_from_mirrorzip ($$$%) {
  my ($self, $url, $file_def, %args) = @_;
  ## Assert: defined $self->{mirror_url}
  my $logger = $args{logger} // $self->set->app->logger;
  my $zip_path;
  my $zip_index;
  return $self->read_index->then (sub {
    my $in = $_[0];
    $zip_path = $in->path->parent->child ($in->index->{zip_file_name})
        if defined $in->index->{zip_file_name};
    $zip_index = $in->index->{zip_index};
    return [$in->get_item ($url->stringify, file_def => $file_def)];
  })->then (sub {
    my ($item_key, $item) = @{$_[0]};
    return {
      not_modified => 1, url => $url,
      insecure => (defined $item->{rev} ? $item->{rev}->{insecure} : undef),
      key => $item_key,
    } if defined $item;

    return Promise->resolve->then (sub {
      return if defined $zip_path;
      return Fetcher->fetch (
        $self->set->app, $self->{mirror_url},
        mime => $args{mime},
        cacert => $args{cacert},
        insecure => $args{insecure},
        sha256 => 1,
        file_def => {sha256 => $self->{mirror_sha256} // ''},
        logger => $logger,
      )->then (sub {
        my $r = $_[0];
        if ($r->{sha256_mismatch}) {
          return $logger->throw ({
            type => 'failed to fetch mirrorzip, sha256 mismatch',
            url => $self->{mirror_url}->stringify,
            expected_value => $self->{mirror_sha256},
            value => $r->{sha256},
          });
        } elsif ($r->{error} or $r->{not_modified}) {
          return $logger->throw ({
            type => 'failed to fetch mirrorzip',
            url => $self->{mirror_url}->stringify,
          });
        }

        return $self->lock_index->then (sub {
          my $ix = $_[0];
          $ix->ensure_type ('mirrorzip:'.$self->type);
          return $ix->put_response (
            $r,
            type => 'mirrorzip',
          )->then (sub {
            my $ret = $_[0];
            $r->{key} = $ret->{key};
            if ($ret->{not_modified} or
                $ret->{sha256_mismatch} or
                $ret->{incomplete}) {
              return $logger->throw ({
                type => 'failed to fetch mirrorzip',
                url => $self->{mirror_url}->stringify,
              });
            }

            $ix->touch;
            $ix->index->{zip_file_name} = $ret->{data_path}->relative
                ($self->storage->{path});
            $zip_path = $ret->{data_path};
          })->then (sub { $ix->save });
        })->then (sub {
          return Zipper->read_json ($self->set->app, $zip_path, 'index.json')->then (sub {
            my $json = $_[0];
            unless (defined $json and ref $json eq 'HASH') {
              return $logger->throw ({
                type => 'broken file, top', format => 'mirrorzip index.json',
                path => $zip_path->absolute,
              });
            }
            unless (defined $json->{items} and
                    ref $json->{items} eq 'HASH' and
                    not grep {
                      not (
                        defined $_ and ref $_ eq 'HASH' and
                        defined $_->{rev} and ref $_->{rev} eq 'HASH' and
                        defined $_->{files} and ref $_->{files} eq 'HASH'
                      );
                    } values %{$json->{items}}) {
              return $logger->throw ({
                type => 'broken file, items', format => 'mirrorzip index.json',
                path => $zip_path->absolute,
              });
            }
            unless (validate_legal $json->{legal}) {
              return $logger->throw ({
                type => 'broken file, legal', format => 'mirrorzip index.json',
                path => $zip_path->absolute,
                key => 'legal',
              });
            }

            return $self->lock_index->then (sub {
              my $ix = $_[0];
              $zip_index = $ix->index->{zip_index} = $json;
              $ix->touch;
              return $ix->save;
            });
          }, sub {
            my $e = $_[0];
            return $logger->throw ({
              type => 'mirrorzip file error',
              key => 'index.json',
              value => $e,
              path => $zip_path->absolute,
            });
          });
        });
      }); # fetch zip
    })->then (sub {
      my $item;
      my $u = $url->stringify;
      for my $it (values %{$zip_index->{items}}) {
        if (defined $it and
            ref $it eq 'HASH' and
            defined $it->{files} and ref $it->{files} eq 'HASH' and
            defined $it->{rev} and
            ref $it->{rev} eq 'HASH' and
            (
              not defined $file_def->{sha256} or
              (defined $it->{rev}->{sha256} and
               $file_def->{sha256} eq $it->{rev}->{sha256})
            ) and
            defined $it->{rev}->{url} and
            defined $it->{rev}->{original_url} and
            $it->{rev}->{original_url} eq $u) {
          my $temp_path = $self->set->app->temp_storage->{path};
          my $files = {};
          return Promise->resolve->then (sub {
            return promised_for {
              my $key = shift;
              my $dest_path = $temp_path->child (rand);
              return Zipper->extract
                  ($self->set->app, $zip_path, $it->{files}->{$key}, $dest_path)->then (sub {
                $files->{$key} = $_[0];
                $files->{$key}->{path} = $dest_path;
              });
            } [keys %{$it->{files}}];
          })->then (sub {
            return $self->lock_index->then (sub {
              my $ix = $_[0];
              my $error_location = {path => $zip_path->absolute, url => $u};
              return Promise->resolve->then (sub {
                return $ix->put_from_mirrorzip (
                  $files,
                  $it->{rev},
                  #XXX insecure => not signed,
                  error_location => $error_location,
                );
              })->then (sub { $ix->save });
            });
          });
        }
      } # $it

      $logger->message ({
        type => 'specified file not in mirrorzip',
        path => $zip_path->absolute,
        url => $u,
        value => $file_def->{sha256},
      });
      return {error => 1};
    });
  });
} # _fetch_file_from_mirrorzip

sub _fetch_file ($$$%) {
  my ($self, $url, $file_def, %args) = @_;
  return $self->_fetch_file_from_mirrorzip ($url, $file_def, %args)
      if defined $self->{mirror_url};
  my $logger = $args{logger} // $self->set->app->logger;
  return Promise->resolve->then (sub {
    return [undef, $args{item_key}, undef]
        if ($args{index_seen}) and
            not $args{skip_if_new} and not $args{skip_if_found};
    
    return $self->read_index->then (sub {
      my $in = $_[0];
      return [$in, $in->get_item ($url->stringify, file_def => $file_def)];
    });
  })->then (sub {
    my ($in, $item_key, $item) = @{$_[0]};
    if (defined $item and
        ($args{skip_if_found} or
         $self->{fetched}->{$url->stringify_without_fragment})) {
      return [{
        not_modified => 1, url => $url,
        insecure => (defined $item->{rev} ? $item->{rev}->{insecure} : undef),
        key => $item_key,
      }, $item, $item_key];
    }
    if ($args{skip_if_new} and defined $item and
        defined $item->{files}->{log}) {
      #die if $in is not defined
      return $in->get_timestamp_of ($item->{files}->{log})->then (sub {
        my $time = $_[0];
        if ($self->set->app->is_new ($time)) {
          $logger->info ({
            type => 'file is new enough',
            key => $item->{files}->{log},
            value => $time,
          });
          my $r = {
            not_modified => 1, is_new => $time, url => $url,
            insecure => (defined $item->{rev} ? $item->{rev}->{insecure} : undef),
            key => $item_key,
          };
          if ($args{check_is_new_insecure}) {
            my $legal = [];
            return Promised::File->new_from_path ($self->storage->{path}->child ($item->{files}->{log}))->read_byte_string->then (sub {
              # XXX jsonl parsing
              for (split /\x0A/, $_[0]) {
                my $j = json_bytes2perl $_;
                if ($j->{has_insecure}) {
                  $r->{is_new_insecure} = 1;
                }
                if ($j->{broken}) {
                  $r->{is_new_broken} = 1;
                }
              }
              return [$r, $item, $item_key];
            });
          } else {
            return [$r, $item, $item_key];
          }
        }
        return [undef, $item, $item_key];
      });
    }
    return [undef, $item, $item_key];
  })->then (sub {
    my ($r, $item, $item_key) = @{$_[0]};
    return $r if defined $r;

    return Fetcher->fetch (
      $self->set->app, $url,
      sha256 => 1,
      mime => $args{mime},
      force_fetch => $args{force_fetch},
      cacert => $args{cacert},
      insecure => $args{insecure},
      no_redirect => $args{no_redirect},
      sniffing => $args{sniffing},
      rev => $args{rev} || $item->{rev}, # or undef
      file_def => $file_def,
      logger => $logger,
    )->then (sub {
      my $r = $_[0];
      if ($r->{error}) {
        # no $r->{key}
        return $r;
      } elsif ($r->{not_modified}) {
        $r->{key} = $item_key;
        if (defined $args{fetch_log} and $r->{304}) {
          $args{fetch_log}->{_} = 304;
          return $self->lock_index->then (sub {
            my $ix = $_[0];
            return $ix->put_fetch_log_by_item_key (
              $item_key,
              fetch_log => $args{fetch_log},
            )->then (sub { $ix->save })->then (sub {
              return $r;
            });
          });
        } else {
          return $r;
        }
      } else {
        return $self->lock_index->then (sub {
          my $ix = $_[0];
          $ix->ensure_type ($self->type) if $args{set_repo_type};
          return $ix->put_response (
            $r,
            type => $args{dest_type},
            fetch_log => $args{fetch_log},
            logger => $logger,
          )->then (sub {
            my $ret = $_[0];
            $r->{key} = $ret->{key};
            if ($ret->{not_modified}) {
              $r->{not_modified} = 1;
            } elsif ($ret->{incomplete}) {
              # XXX retry?
              $logger->message ({
                type => 'response is incomplete',
                url => $r->{url}->stringify,
              });
              $r->{error} = 1;
            } elsif ($r->{sha256_mismatch}) { # not $ret
              $logger->message ({
                type => 'sha256 different from expected',
                url => $r->{url}->stringify,
                value => $r->{sha256},
              });
              $r->{error} = 1;
            }
          })->then (sub { $ix->save });
        })->then (sub {
          $self->{fetched}->{$url->stringify_without_fragment} = 1;
          return $r;
        });
      }
    });
  });
} # _fetch_file

sub _fetch_legal ($$;%) {
  my ($self, $url, %args) = @_;
  my $u = $url->stringify;

  return $self->set->app->get_legal_json ('websites.json')->then (sub {
    my $list = $_[0] // [];
    return undef unless ref $list eq 'ARRAY';

    my $selected;
    for my $item (@$list) {
      next unless defined $item and ref $item eq 'HASH';

      if ($args{is_terms_url}) {
        next unless defined $item->{terms_url};
        if ($item->{terms_url} eq $u) {
          $selected = $item;
          last;
        }
      } else {
        next unless defined $item->{url_prefix};
        if ($u =~ m{^\Q$item->{url_prefix}\E}) {
          $selected = $item;
          last;
        }
      }
    } # item
    return undef unless defined $selected;
    
    my $logger = $args{logger} // $self->set->app->logger;
    $logger->info ({
      type => 'fetch site legal package',
      key => $u,
    });

    my $def = $selected->{source};
    my $repo = $self->set->app->repo_set->get_repo_by_source
        ($def, error_location => {});

    my $has_error = 0;
    # no mirror
    return $repo->fetch (
      cacert => $args{cacert},
      insecure => $args{insecure} || $def->{insecure},
      file_defs => $def->{files},
      has_error => sub { $has_error = 1 },
      skip_other_files => $def->{skip_other_files},
      is_special_repo => 1,
      data_area_key => undef,
      logger => $logger,
    )->then (sub {
      my $ret = $_[0];

      my $v = {timestamp => $ret->{timestamp} // time};
      $v->{insecure} = 1 if $ret->{insecure};
      if ($has_error) {
        $v->{legal_key} = '-ddsd-unknown';
        $logger->info ({
          type => 'site legal package is broken',
          key => $u,
          value => $selected,
        });
        $args{has_error}->();
      } else {
        $v->{legal_key} = $selected->{legal_key};
      }

      $logger->info ({
        type => 'site legal key determined',
        key => $u,
        value => $v->{legal_key},
      });

      return $v;
    })->finally (sub {
      return $repo->close;
    });
  })->then (sub {
    my $v = $_[0];
    return $v if defined $v or not $args{is_terms_url};

    $v = {legal_key => '-ddsd-unknown', timestamp => time};
    return $v;
  });
} # _fetch_legal

sub _fetch_post_legal ($%) {
  my ($self, %args) = @_;
  my $file_defs = {
    package => {},
    'file:index.html' => {}, # CKANSiteRepo
    'file:about.html' => {}, # CKANSiteRepo
    'meta:ckan.json' => {}, # CKANRepo
    'meta:index.html' => {}, # CKANRepo
    'meta:activity.html' => {}, # CKANRepo
    'meta:packref.json' => {}, # PackRefRepo
  };
  my $terms_url;
  my $logger = $args{logger} // $self->set->app->logger;
  return $self->get_item_list (
    file_defs => $file_defs,
    has_error => $args{has_error},
    skip_other_files => 1,
    requires_legal => 1,
    data_area_key => undef,
  )->then (sub {
    my $all_files = shift;

    my $terms_source_key;
    for my $file (@$all_files) {
      if ($file_defs->{$file->{key}} and
          defined $file->{parsed}->{site_terms_url}) {
        $terms_url = $file->{parsed}->{site_terms_url};
        $terms_source_key = $file->{key};
        last;
      }
    }
    return if not defined $terms_url;
    $logger->info ({
      type => 'terms url detected',
      value => $terms_url,
    });

    return $self->_fetch_legal (
      $terms_url,
      is_terms_url => 1,
      cacert => $args{cacert}, insecure => $args{insecure},
      has_error => $args{has_error},
      logger => $logger,
    )->then (sub {
      my $x = $_[0];

      $x->{_} = 'legal';
      $x->{legal_source_key} = $terms_source_key;
      $x->{legal_source_url} = $terms_url->stringify;
      if (defined $args{packref_url}) {
        $x->{legal_packref_url} = $args{packref_url}->stringify;
      }
      return $self->lock_index->then (sub {
        my $ix = $_[0];
        return $ix->put_fetch_log_by_item_key (
          $args{dest_item_key},
          fetch_log => $x,
        )->then (sub { $ix->save });
      });
    });
  })->then (sub {
    return if defined $terms_url;

    my $source = $args{fallback_source};
    return unless defined $source;
    my $repo = $self->set->get_repo_by_source
        ($source, error_location => {});
    return unless defined $repo;

    # no mirror
    return $repo->fetch (
      %args,
      file_defs => $source->{files},
      insecure => $source->{insecure},
      skip_other_files => 1,
      is_special_repo => 1,
      has_error => sub { },
      data_area_key => undef,
      fallback_source => undef,
      logger => $logger,
    )->then (sub {
      return $repo->get_item_list (
        file_defs => $source->{files},
        has_error => $args{has_error},
        skip_other_files => 1,
        requires_legal => 1,
        data_area_key => undef,
      );
    })->then (sub {
      my $all_files = shift;

      my $terms_source_key;
      for my $file (@$all_files) {
        if ($file_defs->{$file->{key}} and
            defined $file->{parsed}->{site_terms_url}) {
          $terms_url = $file->{parsed}->{site_terms_url};
          $terms_source_key = $file->{key};
          last;
        }
      }
      return if not defined $terms_url;
      $logger->info ({
        type => 'terms url detected',
        value => $terms_url,
      });

      return $self->_fetch_legal (
        $terms_url,
        is_terms_url => 1,
        cacert => $args{cacert}, insecure => $args{insecure},
        has_error => $args{has_error},
        logger => $logger,
      )->then (sub {
        my $x = $_[0];

        $x->{_} = 'legal';
        $x->{legal_source_key} = $terms_source_key;
        $x->{legal_source_url} = $terms_url->stringify;
        if (defined $args{packref_url}) {
          $x->{legal_packref_url} = $args{packref_url}->stringify;
        }
        return $self->lock_index->then (sub {
          my $ix = $_[0];
          return $ix->put_fetch_log_by_item_key (
            $args{dest_item_key},
            fetch_log => $x,
          )->then (sub { $ix->save });
        });
      });
    })->finally (sub {
      return $repo->close;
    });
  })->then (sub {
    return if defined $terms_url;
    return unless defined $args{site_legal_key_url};

    return $self->_fetch_legal (
      $args{site_legal_key_url},
      cacert => $args{cacert}, insecure => $args{insecure},
      has_error => $args{has_error},
      logger => $logger,
    )->then (sub {
      my $x = $_[0];
      return unless defined $x;
      return $self->lock_index->then (sub {
        my $ix = $_[0];
        return $ix->put_fetch_log_by_item_key (
          $args{dest_item_key},
          fetch_log => $x,
        )->then (sub { $ix->save });
      });
    });
  });
} # _fetch_post_legal

sub _set_snapshot_hash ($$;%) {
  my ($self, $files, %args) = @_;
  ## Assert: $files->[0]->{type} eq 'package'

  my @item;
  for my $file (grep { 
    defined $_->{rev} and defined $_->{rev}->{sha256} and {
      file => 1, meta => 1, part => 1,
    }->{$_->{type}};
  } @$files) {
    next if $file->{key} eq 'meta:activity.html';
    push @item, [$file->{key}, $file->{rev}->{sha256}];
  }

  $files->[0]->{package_item}->{snapshot_hash} 
      = $self->_get_snapshot_hash_of (\@item);
} # _set_snapshot_hash

sub _get_snapshot_hash_of ($$) {
  return sha256_hex encode_web_utf8 join "\x0A", map { "$_->[0]\t$_->[1]" } sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } @{$_[1]};
} # _get_snapshot_hash_of

sub _get_source_snapshot_hash ($$) {
  my ($self, $source) = @_;
  return undef unless defined $source and ref $source eq 'HASH';
  return undef unless $source->{skip_other_files};
  return undef unless defined $source->{files} and
      ref $source->{files} eq 'HASH';

  my @item;
  for my $file_key (keys %{$source->{files}}) {
    next if $file_key eq 'meta:activity.html';
    my $sha = $source->{files}->{$file_key}->{sha256};
    return undef if not defined $sha;
    push @item, [$file_key, $sha];
  }

  return $self->_get_snapshot_hash_of (\@item);
} # _get_source_snapshot_hash

sub _sniff_terms_url_in_html ($$$) {
  # bytes
  my $base_url = $_[2];

  ## <https://city.himeji.gkan.jp/gkan/dataset/jinkouidou>
  ## <https://data.gsj.jp/gkan/dataset/>
  ## <https://odcs.bodik.jp/[0-9]+/tos/>
  ## <https://portal-data.city.kanazawa.ishikawa.jp/>
  ## <https://ckan.pref.akita.lg.jp/dataset/050008_sicyouson_009>
  ## <https://catalog.opendata.pref.kanagawa.jp/dataset>
  if ($_[1] =~ m{<a href="([^"]+)"[^<>]*>(?:オープンデータ利用規約|データ利用規約|利用規約|サイトについて（利用規約）)</a>}) {
    my $url = Web::URL->parse_string ($1, $base_url);
    return $url if defined $url and $url->is_http_s;
  }

  ## <https://opendata.city.sagamihara.kanagawa.jp/>
  if ($_[1] =~ m{<a href="([^"]+)"[^<>]*>[^<>&]*オープンデータ 利用規約</a>}) {
    my $url = Web::URL->parse_string ($1, $base_url);
    return $url if defined $url and $url->is_http_s;
  }

  ## <https://data.city.ikoma.lg.jp/>
  if ($_[1] =~ m{<a href="(/policy)">ご利用について</a>}) {
    my $url = Web::URL->parse_string ($1, $base_url);
    return $url if defined $url and $url->is_http_s;
  }
  
  return undef;
} # _sniff_terms_url_in_html

sub _parse_log_legal ($$$) {
  my $dest = $_[2];
  my $prev_legal_key;
  my $prev_time;
  my $ll = {};
  for (split /\x0A/, $_[1]) {
    my $line = json_bytes2perl $_;
    if (defined $line->{legal_key}) {
                if (defined $prev_legal_key and
                    $prev_legal_key eq $line->{legal_key}) {
                  my $delta = abs ($line->{timestamp} - $prev_time);
                  if ($delta < 1) {
                    #
                  } else {
                    $prev_time = $line->{timestamp};
                    $ll->{$prev_legal_key}->{timestamps}->{$prev_time} = 1;
                  }
                } else {
                  $prev_legal_key = $line->{legal_key};
                  $prev_time = $line->{timestamp};
                  $ll->{$prev_legal_key}->{timestamps}->{$prev_time} = 1;
                }
      if (defined $line->{legal_source_url}) {
        $ll->{$prev_legal_key}->{source_url}->{$line->{legal_source_url}} = 1;
      }
      if (defined $line->{legal_packref_url}) {
        $ll->{$prev_legal_key}->{packref_url}->{$line->{legal_packref_url}} = 1;
      }
      if ($line->{insecure}) {
        $ll->{$prev_legal_key}->{has_insecure} = 1;
      } else {
        $ll->{$prev_legal_key}->{has_non_insecure} = 1;
      }
    }
  }
  for my $legal_key (sort { $a cmp $b } keys %$ll) {
    my $x = {
      type => 'site_terms',
      key => $legal_key,
      source_type => 'site_legal',
      timestamps => [sort { $a <=> $b } keys %{$ll->{$legal_key}->{timestamps}}],
    };
    my $urls = $ll->{$legal_key}->{source_url} || {};
    if (keys %$urls) {
      $x->{source_url} = [sort { $a cmp $b } keys %$urls]->[0];
      $x->{source_type} = 'site';
    }
    if (keys %{$ll->{$legal_key}->{packref_url} || {}}) {
      $x->{source_type} = 'packref';
    }
    $x->{insecure} = 1 unless $ll->{$legal_key}->{has_non_insecure};
    push @{$dest}, $x;
  } # $legal_key
} # _parse_log_legal

sub get_legal ($;%) {
  my ($repo, %args) = @_;
  my $logger = $repo->set->app->logger;
  my $json = {};

  if (defined $repo->{mirror_url}) {
    return $repo->read_index->then (sub {
      my $in = $_[0];
      my $zip_index = $in->index->{zip_index};
      unless (defined $zip_index and ref $zip_index eq 'HASH' and
              validate_legal $zip_index->{legal}) {
        return $logger->throw ({
          type => 'broken file, legal', format => 'mirrorzip index.json',
          path => $in->path->absolute,
          key => 'legal',
        });
      }
      return $zip_index->{legal};
    });
  }
  
  return Promise->all ([
    $repo->get_item_list (
      #file_defs => $def->{files},
      with_source_meta => 1,
      with_props => 1,
      has_error => sub { },
      data_area_key => $args{data_area_key},
    ),
    $repo->set->app->get_legal_json ('info.json'),
  ])->then (sub {
    my ($items, $info) = @{$_[0]};
    return $logger->throw ({
      type => 'broken file', format => 'legal json',
      key => 'info.json',
    }) unless defined $info and ref $info eq 'HASH';

    my $ckan = {};
    my $pi = {};
    my $ckan_insecure = 0;
      if (@$items >= 1 and $items->[0]->{type} eq 'package') {
        $pi = $items->[0]->{package_item};
        $json->{legal} = $items->[0]->{package_item}->{legal};
        my $has_known_terms;
        for (@{$json->{legal}}) {
          if ($_->{type} eq 'site_terms') {
            if ($_->{key} eq '-ddsd-unknown') {
              #
            } else {
              $has_known_terms = 1;
              last;
            }
          }
        }
        $json->{legal} = [grep {
          if ($has_known_terms and
              $_->{type} eq 'site_terms' and $_->{key} eq '-ddsd-unknown') {
            0;
          } else {
            1;
          }
        } @{$json->{legal}}];
    }
    if (@$items >= 2 and $items->[1]->{key} eq 'meta:ckan.json') {
      $ckan = $items->[1]->{ckan_package} || {};
      $ckan_insecure = 1 if defined $items->[1]->{rev} and
                            $items->[1]->{rev}->{insecure};
    }
    $pi->{lang} //= '';
    $pi->{dir} //= 'ltr';
    $pi->{writing_mode} //= 'horizontal-tb';

    $json->{legal} //= [];
    push @{$json->{legal}}, {type => 'license', key => '-ddsd-unknown',
                             source_type => 'sniffer'}
        unless @{$json->{legal}};

      my $expand; $expand = sub {
        my ($l, $plang, $pnotice, $sub_def) = @_;
        my $in = $info->{$l->{key}};
        if (defined $l->{is_free} and $l->{is_free} eq 'non-free') {
          #
        } elsif (defined $in and ref $in eq 'HASH') {
          $l->{is_free} = $in->{is_free} // 'unknown';
        } else {
          $in = {};
          $l->{is_free} = 'unknown';
        }
          for my $key (qw(lang dir writing_mode desc_url full_url label)) {
            $l->{$key} = $in->{$key} if defined $in->{$key};
          }
          $l->{lang} //= $plang->{lang};
          $l->{dir} //= $plang->{dir};
          $l->{writing_mode} //= $plang->{writing_mode};
          my $inn = {};
          if (defined $in->{notice} and ref $in->{notice} eq 'HASH') {
            $inn = $in->{notice};
          }
        # XXX packref meta
          for my $key (qw(holder template template_not_modified)) {
            $l->{notice}->{$key} = {
              lang => $l->{lang},
              dir => $l->{dir},
              writing_mode => $l->{writing_mode},
              value => $inn->{$key},
            } if defined $inn->{$key};
          }
          my $subn = {};
          if (defined $sub_def->{notice} and
              ref $sub_def->{notice} eq 'HASH') {
            $subn = $sub_def->{notice};
          }
          for my $key (qw(holder template template_not_modified)) {
            $l->{notice}->{$key} = {
              lang => $l->{lang},
              dir => $l->{dir},
              writing_mode => $l->{writing_mode},
              value => $subn->{$key},
            } if defined $subn->{$key};
          }

          if (($inn->{need_holder} or $subn->{need_holder}) and
              not defined $l->{notice}->{holder}) {
            if (defined $pnotice->{holder}) {
              $l->{notice}->{holder} = $pnotice->{holder};
            } elsif (defined $ckan->{author} and length $ckan->{author}) {
              $l->{notice}->{holder} = {
                lang => $pi->{lang},
                dir => $pi->{dir},
                writing_mode => $pi->{writing_mode},
                value => $ckan->{author},
              };
              if (defined $ckan->{organization} and
                  ref $ckan->{organization} eq 'HASH' and
                  defined $ckan->{organization}->{title} and
                  length $ckan->{organization}->{title} and
                  not {
                    '--' => 1,
                  }->{$ckan->{organization}->{title}} and
                  not $l->{notice}->{holder}->{value} =~ m{\Q$ckan->{organization}->{title}\E}) {
                $l->{notice}->{holder}->{value} .= sprintf ' (%s)',
                    $ckan->{organization}->{title};
              }
              $l->{insecure} = 1 if $ckan_insecure;
            } elsif (defined $ckan->{organization} and
                     ref $ckan->{organization} eq 'HASH' and
                     defined $ckan->{organization}->{title} and
                     length $ckan->{organization}->{title} and
                     not {
                       '--' => 1,
                     }->{$ckan->{organization}->{title}}) {
              $l->{notice}->{holder} = {
                lang => $pi->{lang},
                dir => $pi->{dir},
                writing_mode => $pi->{writing_mode},
                value => $ckan->{organization}->{title},
              };
              $l->{insecure} = 1 if $ckan_insecure;
            }
          }

        if ($inn->{need_title} or $subn->{need_title} or
            $inn->{need_url} or $subn->{need_url}) {
            if (defined $pi->{title} and length $pi->{title}) {
              $l->{notice}->{title} = {
                lang => $pi->{lang},
                dir => $pi->{dir},
                writing_mode => $pi->{writing_mode},
                value => $pi->{title},
              };
              $l->{insecure} = 1 if $ckan_insecure;
            }
          }

          if ($inn->{need_url} or $subn->{need_url}) {
            if (defined $repo->{url}) {
              $l->{notice}->{url} = $repo->{url}->stringify;
            }
          }

          if ($inn->{need_modified_flag} or $subn->{need_modified_flag}) {
            $l->{notice}->{need_modified_flag} = \1;
          }
          if ($inn->{need_modified_by} or $subn->{need_modified_by}) {
            $l->{notice}->{need_modified_by} = \1;
          }

        if (defined $in->{conditional} and ref $in->{conditional} eq 'ARRAY') {
          for my $in_def (@{$in->{conditional}}) {
            my $l_def = {};
            push @{$l->{conditional} ||= []}, $l_def;
            for my $k (qw(type key)) {
              $l_def->{$k} = $in_def->{$k} if defined $in_def->{$k};
            }
            $expand->($l_def, $l, $l->{notice} // {}, $in_def);
          }
        } # conditional
        if (defined $in->{alt} and ref $in->{alt} eq 'ARRAY') {
          for my $in_def (@{$in->{alt}}) {
            my $l_def = {};
            push @{$l->{alt} ||= []}, $l_def;
            for my $k (qw(type key)) {
              $l_def->{$k} = $in_def->{$k} if defined $in_def->{$k};
            }
            $expand->($l_def, $l, $l->{notice} // {}, $in_def);
          }
        } # alt
      }; # $expand

      for my $l (@{$json->{legal}}) {
        $expand->($l, $pi, {}, {});
      }

      for my $l (@{$json->{legal}}) {
        if ($l->{insecure}) {
          $json->{insecure} = 1;
          last;
        }
      }
      if ($json->{insecure}) {
        push @{$json->{legal}}, {type => 'disclaimer', key => '-ddsd-insecure',
                                 source_type => 'sniffer'};
        $expand->($json->{legal}->[-1], $pi, {}, {});
      }
      push @{$json->{legal}}, {type => 'disclaimer', key => '-ddsd-disclaimer',
                               source_type => 'sniffer'};
      $expand->($json->{legal}->[-1], $pi, {}, {});

      my $has_free;
      my $free_explicit = {};
      my $sometimes_explicit = {};
      L: for my $l (@{$json->{legal}}) {
        my $is = $l->{is_free} // 'unknown';
        if ($is eq 'neutral') {
          #
        } elsif ($is eq 'free') {
          $has_free = 1;
          if ($l->{type} eq 'license' and
              defined $l->{source_type} and $l->{source_type} eq 'package') {
            $free_explicit->{$l->{key}} = 1;
            my $list = ($info->{$l->{key}} || {})->{possible};
            if (defined $list and ref $list eq 'ARRAY') {
              $free_explicit->{$_} = 1 for @$list;
            }
          }
        } else {
          my $free_if_explicit;
          for my $sl (@{$l->{alt} or []}) {
            my $sis = $sl->{is_free} // 'unknown';
            if ($sl->{type} eq 'license') {
              if ($sis eq 'free') {
                $has_free = 1;
                next L;
              } elsif ($sis eq 'sometimes') {
                $is = 'sometimes';
              }
              $free_if_explicit = 0;
            } elsif ($sl->{type} eq 'fallback_license') {
              if ($sis eq 'free') {
                if ($free_explicit->{$sl->{key}}) {
                  $has_free = 1;
                  next L;
                } else {
                  $free_if_explicit //= 1;
                }
              } elsif ($sis eq 'sometimes') {
                if ($sometimes_explicit->{$sl->{key}}) {
                  $is = 'sometimes';
                }
                $free_if_explicit = 0;
              } else {
                $free_if_explicit = 0;
              }
            } else {
              $free_if_explicit = 0;
            }
          } # alt
          if ($free_if_explicit and
              defined $l->{source_type} and $l->{source_type} eq 'packref') {
            $has_free = 1;
            next L;
          }

          my $has_cond_free = 0;
          my $has_cond_sometimes = 0;
          my $has_cond_non_free = 0;
          for my $sl (@{$l->{conditional} or []}) {
            my $sis = $sl->{is_free} // 'unknown';
            for my $ssl (@{$sl->{alt} or []}) {
              my $ssis = $ssl->{is_free} // 'unknown';
              if ($ssl->{type} eq 'license') {
                if ($ssis eq 'free') {
                  $sis = 'free';
                  last;
                } elsif ($ssis eq 'sometimes') {
                  $sis = 'sometimes';
                }
              } elsif ($ssl->{type} eq 'fallback_license') {
                if ($ssis eq 'free') {
                  $sis = 'sometimes';
                } elsif ($ssis eq 'sometimes') {
                  $sis = 'sometimes';
                }
              }
            } # alt
            
            if ($sl->{type} eq 'license') {
              if ($sis eq 'free') {
                $has_cond_free++;
              } elsif ($sis eq 'sometimes') {
                $has_cond_sometimes++;
              } else {
                $has_cond_non_free++;
              }
            } elsif ($sl->{type} eq 'fallback_license') {
              if ($sis eq 'free') {
                $has_cond_sometimes++;
              } elsif ($sis eq 'sometimes') {
                $has_cond_sometimes++;
              } else {
                $has_cond_non_free++;
              }
            }
          } # conditional
          if ($has_cond_non_free) {
            #
          } elsif ($has_cond_sometimes) {
            $is = 'sometimes';
          } elsif ($has_cond_free) {
            $has_free = 1;
            next L;
          }

          if ($is eq 'sometimes') {
            if ($l->{type} eq 'site_terms' and keys %$free_explicit) {
              next L;
            }
            
            $json->{is_free} //= 'sometimes';
            if ($l->{type} eq 'license' and
                defined $l->{source_type} and $l->{source_type} eq 'package') {
              $sometimes_explicit->{$l->{key}} = 1;
              my $list = ($info->{$l->{key}} || {})->{possible};
              if (defined $list and ref $list eq 'ARRAY') {
                $sometimes_explicit->{$l->{key}} = 1 for @$list;
              }
            }
          } elsif ($is eq 'non-free') {
            $json->{is_free} = 'non-free';
            last;
          } else { # unknown
            $json->{is_free} = 'unknown';
          }
        } # L
      }
      $json->{is_free} //= $has_free ? 'free' : 'unknown';
      
      undef $expand;

    return $json;
  });
} # get_legal

sub format_legal ($$$;%) {
  my ($self, $outer, $json, %args) = @_;
  
  my $cleanup = sub { };
  unless ($args{json}) {
    my $f; $f = sub {
      my $l = $_[0];
      my @m;

      push @m, sprintf "* %s\x0A",
          {
            license => 'License',
            db_license => 'License (database)',
            site_terms => 'Terms (Web site)',
            disclaimer => 'Disclaimer',
            fallback_license => 'Fallback license',
          }->{$l->{type}} // $l->{type}; # XXX locale
      if (delete $l->{insecure}) {
        push @m, "[Based on data trasferred over insecure transport]\x0A"; # XXX locale
      }

      if ($l->{type} eq 'fallback_license') {
        push @m, "This license is only applicable when no conflicting license is specified.\x0A"; # XXX locale
      }
      
      my $alts = delete $l->{alt};
      my $conds = delete $l->{conditional};
      
      if (defined $l->{source_type} and $l->{source_type} eq 'package' and
          defined $l->{source_url}) {
        # XXX locale
        push @m, sprintf "From package <%s>:\x0A",
            $l->{source_url};
        delete $l->{source_type};
        delete $l->{source_url};
      } elsif (defined $l->{source_type} and
               ($l->{source_type} eq 'site_legal' or
                $l->{source_type} eq 'site' or
                $l->{source_type} eq 'packref')) {
        # XXX locale
        my $m = sprintf "From Web site's terms, confirmed at:\x0A\x0A";
        if (defined $l->{source_url}) {
          $m = sprintf "From Web site's terms <%s>, confirmed at:\x0A\x0A",
              $l->{source_url};
        }
        if (defined $l->{timestamps} and ref $l->{timestamps} eq 'ARRAY') {
          for (@{$l->{timestamps}}) {
            my $dt = Web::DateTime->new_from_unix_time ($_);
            $m .= sprintf "  - %s\x0A", $dt->to_global_date_and_time_string; # XXX locale
          }
        }
        push @m, $m;
        delete $l->{source_type};
        delete $l->{source_url};
        delete $l->{timestamps};
      }

      {
        my $m = '';
        if (defined $l->{label}) {
          $m .= $l->{label} . "\x0A";
          delete $l->{label};
          delete $l->{key};
        }
        if (defined $l->{full_url}) {
          $m .= sprintf "<%s>\x0A", $l->{full_url};
          delete $l->{full_url};
          delete $l->{desc_url};
          delete $l->{key};
        } elsif (defined $l->{desc_url}) {
          $m .= sprintf "<%s>\x0A", $l->{desc_url};
          delete $l->{desc_url};
          delete $l->{key};
        }
        push @m, $m if length $m;
      }
      
      if (defined $l->{notice}->{template}) {
        my $t = $l->{notice}->{template}->{value};
        $t =~ s{\{([a-z]+)\}}{
          if ($1 eq 'holder') {
            $l->{notice}->{holder}->{value} // "{$1}";
          } elsif ($1 eq 'title') {
            $l->{notice}->{title}->{value} // "{$1}";
          } elsif ($1 eq 'url') {
            $l->{notice}->{url} // "{$1}";
          } else {
            "{$1}";
          }
        }ge;
        push @m, $t . "\x0A";
      } else {
        if (defined $l->{notice}->{title} and
            defined $l->{notice}->{holder} and
            defined $l->{notice}->{url}) {
          push @m, sprintf "%s, %s\x0A<%s>\x0A",
              $l->{notice}->{title}->{value},
              $l->{notice}->{holder}->{value},
              $l->{notice}->{url};
          delete $l->{notice}->{title};
          delete $l->{notice}->{holder};
          delete $l->{notice}->{url};
        } elsif (defined $l->{notice}->{holder}) {
          push @m, sprintf "Right holder: %s\x0A", # XXX locale
              $l->{notice}->{holder}->{value};
          delete $l->{notice}->{holder};
        }
        
        if (delete $l->{notice}->{need_modified_flag}) {
          push @m, "This is a modified copy.\x0A"; # XXX locale
        }
        
        delete $l->{type};
        delete $l->{lang};
        delete $l->{dir};
        delete $l->{writing_mode};
        delete $l->{is_free};
        delete $l->{notice} unless keys %{$l->{notice} or {}};
        push @m, (perl2json_chars_for_record $l) . "\x0A" if keys %$l;
      }

      if (@{$conds or []}) {
        # XXX locale
        push @m, "One of these licenses are applied conditionally (see the full text for the conditions):\x0A";
      }
      for (@{$conds or []}) {
        my $n = $f->($_);
        $n =~ s/\x0A/\x0A  /g;
        $n =~ s/\x0A  \z/\x0A/;
        push @m, sprintf "%s:\n\n  %s",
            "Option",
            $n;
      }

      for (@{$alts or []}) {
        my $n = $f->($_);
        $n =~ s/\x0A/\x0A  /g;
        $n =~ s/\x0A  \z/\x0A/;
        push @m, sprintf "%s:\n\n  %s",
            "Option",
            $n;
      }
      
      return join "\x0A", @m, '';
    }; # $f
    $outer->formatter (sub {
      my $item = $_[0];
      my $m = '';
      for (@{$item->{legal}}) {
        $m .= $f->($_);
      }
      return $m;
    });
    $cleanup = sub { undef $f };
  } # not json

  $outer->item ($json);

  unless ($args{json}) {
    # XXX locale
    $outer->formatted (sprintf "\x0A\x0A* %s\x0A\x0A%s\x0A", "Summary (informative)", {
      free => 'This is a free software.',
      sometimes => 'This might or might not be a free software.',
      'non-free' => 'This is NOT a free software.',
      unknown => 'Not sure whether this is a free software or not.',
    }->{$json->{is_free}} // $json->{is_free});
  }

  return $cleanup;
} # format_legal

my $MIMENormalize = {
  'application/json; charset=utf-8' => 'application/json',
  'application/x-zip-compressed' => 'application/zip',
  'binary/octet-stream' => 'application/octet-stream',
  'text/turtle; charset=utf-8' => 'text/turtle; charset=UTF-8',
};

sub _set_item_file_info ($$$$$%) {
  my ($self, $url, $fdef, $in, $file, %args) = @_;

  my $item;
  if (defined $url) {
    my $item_key;
    ($item_key, $item) = $in->get_item
        ($url->stringify, file_def => $fdef);
    if (defined $item) {
      $file->{rev} = $item->{rev};
      $file->{item_key} = $item_key if $args{with_item_key};
      
      if ($args{with_path}) {
        my $storage_path = $self->storage->{path};
        $file->{path} = $storage_path->child ($item->{files}->{data})
            if defined $item->{files}->{data};
        $file->{meta_path} = $storage_path->child ($item->{files}->{meta})
            if defined $item->{files}->{meta};
        $file->{log_path} = $storage_path->child ($item->{files}->{log})
            if defined $item->{files}->{log};
      }
    }
  } # $url

  my $pi = $file->{package_item} = {};
  if ($file->{type} eq 'file' or $file->{type} eq 'meta' or
      $file->{type} eq 'part') {
    $pi->{mime} = $args{default_mime} // 'application/octet-stream';
    $pi->{mime} = $file->{rev}->{http_content_type}
        if defined $file->{rev} and defined $file->{rev}->{http_content_type};
    my $m = $pi->{mime};
    $pi->{mime} =~ s{\A([^;]+);\s*[Cc][Hh][Aa][Rr][Ss][Ee][Tt]=[Uu][Tt][Ff]-8\z}{$1; charset=utf-8};
    $pi->{mime} =~ s{^([^;\s]+)}{lc $1}e;
    $pi->{mime} = $MIMENormalize->{$pi->{mime}} // $pi->{mime};
    delete $pi->{mime} unless length $pi->{mime};
  }
        if ($args{with_props}) {
        {
          if (defined $file->{rev} and
              defined $file->{rev}->{http_last_modified}) {
            $pi->{file_time} = $file->{rev}->{http_last_modified};
          }
          if (defined $file->{rev}) {
            $pi->{file_time} = $file->{rev}->{http_date} // $file->{rev}->{timestamp};
          }
        }
          $pi->{title} = '';
        } # with_props

  if (defined $fdef and defined $fdef->{name}) {
    $file->{file}->{directory} = 'files';
    $file->{file}->{name} = $fdef->{name};
  } else {
    if (defined $args{default_file_name}) {
      $file->{file}->{directory} = $args{default_directory_name} // 'files';
      $file->{file}->{name} = $args{default_file_name};
    }
  }

  return $item; # or undef
} # _set_item_file_info

sub _expand_dataset ($$$$$$%) {
  my ($self, $file, $fdefs, $in => $pack_file, $files, $logger, %args) = @_;

  if ($file->{set_type} eq 'sparql') {
              for my $h ('0'..'9', 'a'..'f') {
                my $f = {key => "part:sparql[$file->{key}]:$h",
                         type => 'part',
                         package_item => {
                           title => '', mime => 'text/turtle',
                         },
                         source => {mime => 'turtle'}};
                if (defined $file->{source}->{url}) {
                  $f->{source}->{url} = $file->{source}->{url};
                  $f->{source}->{url} .= $f->{source}->{url} =~ /\?/ ? '&' : '?';
                  $f->{source}->{url} .= 'query=SELECT%20%2A%20WHERE%20%7B%20%20%3Fs%20%3Fp%20%3Fo%20.%20%20FILTER%20(STRSTARTS(SUBSTR(MD5(STR(%3Fs)),%201,%202),%20%22'.$h.'%22))%20%7D';
                }
                $self->_set_item_file_info
                    (Web::URL->parse_string ($f->{source}->{url} // ''), $fdefs->{$f->{key}}, $in, $f, %args);
                
                my $fd = $fdefs->{$f->{key}};
                if (defined $fd and defined $fd->{name}) {
                  $f->{file}->{directory} = 'files';
                  $f->{file}->{name} = $fd->{name};
                } else {
                  $f->{file}->{directory_file_key} = $file->{key};
                  $f->{file}->{name} = "part-$h.ttl";
                }

                if (defined $f->{package_item}->{file_time}) {
                  $pack_file->{package_item}->{file_time} //= $f->{package_item}->{file_time};
                  $pack_file->{package_item}->{file_time} = $f->{package_item}->{file_time}
                      if $pack_file->{package_item}->{file_time} < $f->{package_item}->{file_time};
                }

                push @$files, $f;
    }

    $file->{source}->{base_url} = delete $file->{source}->{url};
    $file->{set_expanded} = \1;
  } elsif ($file->{set_type} eq 'fiware-ngsi') {
    if ($args{report_unexpandable_set_type}) {
      $logger->message ({
        type => 'dataset not supported',
        value => $file->{set_type},
        error_location => $args{error_location},
      });
      $args{has_error}->();
    }
  } else { # set_type
    if ($args{report_unknown_set_type}) {
      $logger->message ({
        type => 'unknown set_type',
        value => $file->{set_type},
        error_location => $args{error_location},
      });
      $args{has_error}->();
    }
  }
} # _expand_dataset

sub close ($) {
  my $self = $_[0];
  delete $self->{set};
} # close

sub DESTROY ($) {
  local $@;
  eval { die };
  warn "$$: Reference to @{[ref $_[0]]} ($_[0]->{id}) is not discarded before global destruction"
      if $@ =~ /during global destruction/;
} # DESTROY

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
