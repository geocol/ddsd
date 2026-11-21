package DcatusRepo;
use strict;
use warnings;
use Time::HiRes qw(time);
use JSON::PS;
use Promise;
use Promised::Flow;
use Web::URL;
use Web::URL::Encoding;
use Web::DateTime::Parser;
use Web::Encoding;
use Digest::SHA qw(sha256_hex);
use Promised::File;
use Path::Tiny;

use Repo;
push our @ISA, qw(Repo);

use RepoIndexFile;
use FileTypes;

sub new_from_upstream ($$$;%) {
  my ($class, $upstream_repo, $upstream_args, %args) = @_;

  my $self = bless {
    set => $upstream_repo->set,
    upstream_repo => $upstream_repo,
    upstream_args => $upstream_args,
    id => $args{id},
  }, $class;
  $self->_set_key ($self->{id});

  return $self;
} # new_from_upstream

sub type () { "dcatus" }

sub _upstream_mirror_def ($) {
  my $self = $_[0];
  return {
    type => $self->{upstream_repo}->type,
    url => $self->{upstream_args}->{url}->stringify,
  };
} # _upstream_mirror_def

sub _find_mirror ($$$) {
  my ($self, $key, $def) = @_;
  my $updef = $self->_upstream_mirror_def;
  return $self->{upstream_repo}->_find_mirror ($key, $updef)->then (sub {
    return $self->SUPER::_find_mirror ($key, $def);
  });
} # _find_mirror

sub _use_mirror ($$$) {
  my ($self, $key, $def) = @_;
  my $updef = $self->_upstream_mirror_def;
  return $self->{upstream_repo}->_use_mirror ($key, $updef)->then (sub {
    return $self->SUPER::_use_mirror ($key, $def);
  });
} # _use_mirror
sub is_nested ($) { 1 }

sub feed_url ($) {
  my $self = $_[0];
  return $self->{upstream_args}->{url}; # or undef
}

sub read_index ($) {
  my $self = $_[0];
  unless (defined $self->{upstream_repo}) {
    return $self->SUPER::read_index;
  }
  return $self->{upstream_repo}->read_index->then (sub {
    my $upix = $_[0];
    my $upitem = $self->{upstream_repo}->_get_item
        ($upix, $self->{upstream_args});
    if (not defined $upitem) {
      my $logger = $self->set->app->logger;
      $logger->message ({
        type => 'no local copy available',
        (defined $self->{upstream_args}->{url} ? (url => $self->{upstream_args}->{url}->stringify) : ()),
      });
      return $self->SUPER::read_index (
        upstream_index => $upix,
        upstream_item => $upitem,
      );
    }

    my $storage = $upix->get_storage_of
        ($upitem, "dcatus-" . sha256_hex (encode_web_utf8 $self->{id}),
         allow_missing => 1,
         nested => $self->{upstream_repo}->is_nested);
    unless (defined $storage) {
      return $self->SUPER::read_index (
        upstream_index => $upix,
        upstream_item => $upitem,
      );
    }
    return RepoIndexFile->open_by_app_and_storage (
      $self->set->app, $storage, allow_missing => 1,
      upstream_index => $upix,
      upstream_item => $upitem,
      path_index_key => (join "-", @{$self->{key}}),
    );
  });
} # read_index

sub lock_index ($) {
  my $self = $_[0];
  unless (defined $self->{upstream_repo}) {
    return $self->set->app->logger->throw ({
      type => 'no local copy available',
      (defined $self->{upstream_args}->{url} ? (url => $self->{upstream_args}->{url}->stringify) : ()),
    });
  }
  return $self->{upstream_repo}->lock_index->then (sub {
    my $upix = $_[0];
    my $upitem = $self->{upstream_repo}->_get_item
        ($upix, $self->{upstream_args});
    if (not defined $upitem) {
      return $self->set->app->logger->throw ({
        type => 'no local copy available',
        (defined $self->{upstream_args}->{url} ? (url => $self->{upstream_args}->{url}->stringify) : ()),
      });
    }

    my $storage = $upix->get_storage_of
        ($upitem, "dcatus-" . sha256_hex (encode_web_utf8 $self->{id}),
         prefix => 'dcatus-',
         create_if_missing => 1,
         nested => $self->{upstream_repo}->is_nested);
    return $storage->mkpath->then (sub { $upix->save })->finally (sub { $upix->close })->then (sub {
      return RepoIndexFile->open_by_app_and_storage (
        $self->set->app, $storage, allow_missing => 1, lock => 1,
        upstream_index => $upix,
        upstream_item => $upitem,
        path_index_key => (join "-", @{$self->{key}}),
      );
    });
  });
} # lock_index

sub _parse_feed ($$) {
  my ($self, $bytes) = @_;
  my $json = json_bytes2perl $bytes;
  return undef unless defined $json and ref $json eq 'HASH';
  my $datasets = $json->{dataset};
  return undef unless defined $datasets and ref $datasets eq 'ARRAY';
  my $id = $self->{id};
  for my $ds (@$datasets) {
    next unless defined $ds and ref $ds eq 'HASH';
    my $ds_id = $ds->{identifier} // '';
    if ($ds_id eq $id) {
      return $ds;
    }
  }
  for my $ds (@$datasets) {
    next unless defined $ds and ref $ds eq 'HASH';
    my $lp = $ds->{landingPage} // '';
    if (length $lp and $lp eq $id) {
      return $ds;
    }
  }
  return undef;
} # _parse_feed

sub _dist_url ($$) {
  my ($self, $dist) = @_;
  return undef unless defined $dist and ref $dist eq 'HASH';
  for my $k (qw(downloadURL accessURL)) {
    my $u = $dist->{$k};
    next unless defined $u and length $u;
    my $url = Web::URL->parse_string ($u);
    next unless defined $url and $url->is_http_s;
    return $url;
  }
  return undef;
} # _dist_url

sub _dist_is_html_page ($$$) {
  my ($self, $dist, $ds) = @_;
  return 0 unless defined $dist and ref $dist eq 'HASH';
  my $format = ($dist->{format} // '');
  my $mt = ($dist->{mediaType} // '');
  my $title = ($dist->{title} // '');
  my $url = $dist->{downloadURL} // $dist->{accessURL} // '';
  my $url2 = $url;
  tr/A-Z/a-z/ for $format, $mt, $title, $url2;
  my $lp = $ds->{landingPage} // '';

  if ($mt eq 'text/html' and $format eq 'web page' and
      $title eq 'arcgis hub dataset') {
    return 1;
  }
  return 0;

  #if ($mt eq 'text/html' or $format eq 'web page' or $format eq 'html') {
  #  return 1;
  #}
  #if (length $lp and $url eq $lp) {
  #  return 1;
  #}
  #if ($title =~ /arcgis hub dataset/ or $title =~ /web page/) {
  #  if ($url2 =~ /\.(?:zip|csv|json|geojson|xlsx?|xml|rdf|ttl|pdf|shp|kml|kmz)(?:[?#].*)?$/) {
  #    return 0;
  #  }
  #  return 1 if $mt eq '' or $mt eq 'text/html';
  #}
  #return 0;
} # _dist_is_html_page

sub _dist_file_key ($$$) {
  my ($self, $dist, $i) = @_;
  my $url = $dist->{downloadURL} // $dist->{accessURL} // '';
  my $sha = substr sha256_hex (encode_web_utf8 $url), 0, 16;
  return "file:distribution-$sha";
} # _dist_file_key

{
  package DcatusRepo::_FakeRes;
  sub header { return undef }
  sub incomplete { return 0 }
}

sub fetch ($;%) {
  my ($self, %args) = @_;
  my $logger = $args{logger} // $self->set->app->logger;
  my $file_defs = $args{file_defs} || {};
  my $ret = {};
  my $as;

  # 1. Fetch upstream (feed)
  return $self->{upstream_repo}->fetch (
    %args,
    skip_other_files => 1,
    file_defs => { file => {} },
  )->then (sub {
    my $up = $_[0] // {};
    $ret->{insecure} = 1 if $up->{insecure};
    return $up;
  })->then (sub {
    my $up = shift;
    return $self->read_index->then (sub {
      my $ix = $_[0];
      my $upitem = $ix->upstream_item;
      unless (defined $upitem) {
        $args{has_error}->() if $args{has_error};
        $ret->{broken} = 1;
        return $ret;
      }
      my $path = $ix->upstream_index->get_path_of ($upitem, 'data');
      return Promised::File->new_from_path ($path)->read_byte_string->then (sub {
        my $ds = $self->_parse_feed ($_[0]);
        unless (defined $ds) {
          $logger->message ({
            type => 'dcatus dataset not found',
            (defined $self->feed_url ? (url => $self->feed_url->stringify) : ()),
            id => $self->{id},
          });
          $args{has_error}->() if $args{has_error};
          $ret->{broken} = 1;
          return $ret;
        }

        # 2. Store extracted dataset meta in our own nested index
        my $ds_bytes = perl2json_bytes_for_record $ds;
        return $self->lock_index->then (sub {
          my $own = $_[0];
          $own->ensure_type ($self->type);
          my $url = Web::URL->parse_string ($self->{id});
          my $tmp = Path::Tiny->tempfile;
          $tmp->spew_raw ($ds_bytes);
          return $own->put_response (
            {
              url => $url,
              original_url => $url,
              path => $tmp,
              length => length $ds_bytes,
              sha256 => Digest::SHA::sha256_hex ($ds_bytes),
              timestamp => time,
              fetch_time => time,
              res => bless {status => 200, status_text => 'OK', headers => []}, 'DcatusRepo::_FakeRes',
            },
            type => 'meta',
            logger => $logger,
          )->then (sub {
            $ret->{has_package} = 1;
          })->then (sub { $own->save })->finally (sub { $own->close; undef $tmp });
        })->then (sub { return $ds }, sub {
          my $e = shift;
          $logger->message ({ type => 'dcatus lock failed', error => ''.$e });
          $args{has_error}->() if $args{has_error};
          $ret->{broken} = 1;
          return $ret;
        });
      }, sub {
        my $e = shift;
        $logger->message ({
          type => 'file read failed',
          error => ''.$e,
          path => ''.$path,
        });
        $args{has_error}->() if $args{has_error};
        $ret->{broken} = 1;
        return $ret;
      });
    });
  })->then (sub {
    my $ds = shift;
    return $ret if $ret->{broken};
    return $ret unless defined $ds and ref $ds eq 'HASH';

    return $self->get_item_list (
      file_defs => $file_defs,
      has_error => $args{has_error},
      skip_other_files => $args{skip_other_files},
      min => $args{min},
      requires_legal => $args{requires_legal},
    )->then (sub {
      my $all_files = shift;
      my $files = [];
      for my $file (@$all_files) {
        next if $file->{type} eq 'meta' or $file->{type} eq 'package';
        next if $args{skip_other_files} and not defined $file_defs->{$file->{key}};
        next if defined $file_defs->{$file->{key}} and $file_defs->{$file->{key}}->{skip};
        if ($args{min}) {
          my $size = $file->{package_item}->{file_size};
          if (defined $size and $size > 100_000_000) {
            $logger->count (['add_skipped']);
            next;
          }
        }
        push @$files, $file;
      }

      $as = $logger->start (0+@$files, {
        type => 'pull package files',
        all_count => 0+@$all_files,
        selected_count => 0+@$files,
      });
      return promised_for {
        my $file = shift;
        $as->{next}->(undef, undef, {key => $file->{key}});
        my $u = $file->{source}->{url};
        unless (defined $u) { $args{has_error}->() if $args{has_error}; return; }
        my $url = Web::URL->parse_string ($u);
        if (not defined $url or not $url->is_http_s) {
          $args{has_error}->() if $args{has_error};
          $as->message ({ type => 'bad URL', value => $u, key => 'url', file => $file });
          return;
        }

        my $he = $args{has_error};
        return $self->_fetch_file (
          $url, $file_defs->{$file->{key}},
          %args,
          has_error => $he,
          index_seen => 1, rev => $file->{rev}, item_key => $file->{item_key},
          logger => $as,
        )->then (sub {
          my $r = $_[0];
          $ret->{insecure} = 1 if $r->{insecure};
          if ($r->{error}) {
            $he->() if $he;
            $as->count (['fetch_failure']);
          }
        });
      } $files;
    })->then ($as->{ok}, $as->{ng});
  })->then (sub {
    return $ret;
  });
} # fetch

sub get_item_list ($;%) {
  my ($self, %args) = @_;
  my $logger = $self->set->app->logger;
  my $file_defs = $args{file_defs} || {};
  my $files = [];
  my $in;
  my $ds;

  my $with_package = not $args{no_package};
  $with_package = 1 if $args{requires_package} or $args{with_snapshot_hash} or $args{requires_legal};

  return $self->read_index->then (sub {
    $in = $_[0];
    my $upitem = $in->upstream_item;

    if ($with_package) {
      my $file0 = {
        type => 'package',
        key => 'package',
        package_item => {
          title => '',
          lang => '',
          dir => 'auto',
          writing_mode => 'horizontal-tb',
          page_url => $self->{id},
        },
      };
      my $file = {
        type => 'meta',
        key => 'meta:dcat-us.json',
        package_item => {
          mime => 'application/json',
          title => '',
        },
        file => {
          directory => 'package',
          name => 'package.dcat-us.json',
        },
      };
      if (defined $file_defs->{'meta:dcat-us.json'} and
          defined $file_defs->{'meta:dcat-us.json'}->{name}) {
        $file->{file}->{directory} = 'files';
        $file->{file}->{name} = $file_defs->{'meta:dcat-us.json'}->{name};
      }
      push @$files, $file0, $file;
    }

    # Read extracted dataset from our own index
    my ($item_key, $item) = $in->get_item
        (url_string => $self->{id},
         file_def => $file_defs->{'meta:dcat-us.json'});

    my $ds_promise;
    if (defined $item and defined $item->{files}->{data}) {
      my $path = $in->{storage}->child_path ($item->{files}->{data});
      $ds_promise = Promised::File->new_from_path ($path)->read_byte_string->then (sub {
        my $json = json_bytes2perl $_[0];
        return (defined $json and ref $json eq 'HASH') ? $json : undef;
      }, sub { return undef });
      if ($with_package) {
        my $file = $files->[1];
        $file->{rev} = $item->{rev} if defined $item->{rev};
        $file->{item_key} = $item_key if $args{with_item_key};
        if ($args{with_path}) {
          my $storage = $in->{storage};
          $file->{path} = $storage->child_path ($item->{files}->{data})
              if defined $item->{files}->{data};
          $file->{meta_path} = $storage->child_path ($item->{files}->{meta})
              if defined $item->{files}->{meta};
          $file->{log_path} = $storage->child_path ($item->{files}->{log})
              if defined $item->{files}->{log};
        }
      }
    } else {
      # Fallback: read from upstream feed
      $ds_promise = Promise->resolve->then (sub {
        unless (defined $upitem) {
          $logger->message ({
            type => 'no local copy available',
            (defined $self->feed_url ? (url => $self->feed_url->stringify) : ()),
            key => 'meta:dcat-us.json',
          });
          $args{has_error}->() if $args{has_error};
          return undef;
        }
        my $path = $in->upstream_index->get_path_of ($upitem, 'data');
        return Promised::File->new_from_path ($path)->read_byte_string->then (sub {
          return $self->_parse_feed ($_[0]);
        }, sub {
          $args{has_error}->() if $args{has_error};
          return undef;
        });
      });
    }

    return $ds_promise->then (sub {
      $ds = shift;
      return [$ds, $item];
    });
  })->then (sub {
    my ($ds, $item) = @{$_[0]};
    my $with_package = @$files && $files->[0]->{type} eq 'package';

    if ($with_package) {
      my $file0 = $files->[0];
      my $meta_file = $files->[1];
      my $pi0 = $file0->{package_item};
      my $pi = $meta_file->{package_item};
      if (defined $ds) {
        $pi0->{title} = $ds->{title} // '';
        $pi->{title} = $pi0->{title};
        $pi0->{page_url} = $ds->{landingPage} // $self->{id};
        $pi0->{desc} = $ds->{description} if defined $ds->{description};
      } else {
        $pi0->{title} = $self->{id};
        $pi->{title} = $self->{id};
      }
      if ($args{with_props}) {
        $pi0->{legal} = [];
        my $set_legal = sub {
          if (defined $ds and defined $ds->{license} and length $ds->{license}) {
            my $matched;
            my $defs = $_[0];
            $defs = [] unless defined $defs and ref $defs eq 'ARRAY';
            for my $l (@$defs) {
              next unless defined $l and ref $l eq 'HASH';
              my $has_some = 0;
              if (not defined $l->{url} and not defined $ds->{license}) {
                #
              } elsif (defined $l->{url} and defined $ds->{license} and
                       $l->{url} eq $ds->{license}) {
                $has_some = 1;
              } else {
                next;
              }
              next unless $has_some;
              next if defined $l->{extracted_url};
              next if defined $l->{licenses};
              if (defined $l->{is}) {
                push @{$pi0->{legal}}, {
                  type => ($l->{db} ? 'db_license' : 'license'),
                  key => $l->{is},
                  source_type => 'package',
                  source_url => (defined $self->feed_url ? $self->feed_url->stringify : $self->{id}),
                  license_url => $ds->{license},
                };
                $matched = 1;
                last;
              }
            }
            unless ($matched) {
              push @{$pi0->{legal}}, {
                type => 'license',
                key => '-ddsd-dcatus-license',
                source_type => 'package',
                source_url => (defined $self->feed_url ? $self->feed_url->stringify : $self->{id}),
                license_url => $ds->{license},
              };
            }
          }
          if (defined $item and defined $item->{files}->{log}) {
            return Promised::File->new_from_path ($in->{storage}->child_path ($item->{files}->{log}))->read_byte_string->then (sub {
              $self->_parse_log_legal ($_[0] => $pi0->{legal});
              return $ds;
            }, sub { return $ds });
          }
          return $ds;
        };
        return $self->set->app->get_legal_json ('dcatus.json')->then ($set_legal, sub { $set_legal->([]) });
      }
    }
    return $ds;
  })->then (sub {
    my $ds = shift;
    return $files unless defined $ds;
    return $files if $args{skip_other_files} and not grep { $_ ne 'meta:dcat-us.json' and $_ ne 'package' } keys %$file_defs;

    my $dists = $ds->{distribution};
    $dists = [] unless defined $dists and ref $dists eq 'ARRAY';
    my $i = 0;
    for my $dist (@$dists) {
      $i++;
      next unless defined $dist and ref $dist eq 'HASH';
      next if $self->_dist_is_html_page ($dist, $ds);
      my $url = $self->_dist_url ($dist);
      next unless defined $url;
      next if $url->stringify =~ m<\{>;

      my $file_key = $self->_dist_file_key ($dist, $i);
      if ($args{skip_other_files} and not defined $file_defs->{$file_key}) { next; }
      my $skipped;
      if (defined $file_defs->{$file_key} and $file_defs->{$file_key}->{skip}) {
        $skipped = 1;
        next unless $args{with_skipped};
      }

      my $file = {
        type => 'file',
        key => $file_key,
        source => { url => $url->stringify },
      };
      $self->_set_item_file_info
          ([url_string => $url->stringify],
           $file_defs->{$file_key}, $in, $file, %args,
           skipped => $skipped, compute_mime => 1);

      if ($args{with_props}) {
        my $pi = $file->{package_item};
        $pi->{title} = $dist->{title} // '';
        if (not defined $pi->{file_time}) {
          for my $k (qw(modified issued)) {
            my $v = $ds->{$k} // $dist->{$k};
            next unless defined $v and length $v;
            my $dtp = Web::DateTime::Parser->new;
            $dtp->onerror (sub { });
            my $dt = $dtp->parse_iso8601_datetime ($v);
            $dt = $dtp->parse_global_date_and_time_string ($v) unless defined $dt;
            if (defined $dt) {
              $pi->{file_time} = $dt->to_unix_number;
              last;
            }
          }
        }
        my $dist_mt = $dist->{mediaType} // '';
        $dist_mt = FileTypes::normalize_mime_type_string $dist_mt;
        $dist_mt = FileTypes::remove_mime_type_parameters $dist_mt
            if defined $dist_mt;
        if (defined $dist_mt and length $dist_mt and
            ($pi->{mime} // 'application/octet-stream') eq 'application/octet-stream') {
          $pi->{mime} = $dist_mt;
        }
        if (not defined $pi->{file_name} or not length $pi->{file_name}) {
          my $u = $url->path;
          if (defined $u and $u =~ m{/([^/]+)$}) {
            my $n = percent_decode_c $1;
            $n =~ s/[?#].*$//s;
            $pi->{file_name} = $n if length $n;
          }
        }
      }

      push @$files, $file;
    }

    if ($args{with_props} or $args{with_snapshot_hash}) {
      if ($args{with_snapshot_hash}) {
        unshift @$files, { type => 'package', key => 'package', package_item => {} }
            unless @$files and $files->[0]->{type} eq 'package';
        $self->_set_snapshot_hash ($files);
      }
      $files->[0]->{package_item}->{file_time} //= time
          if @$files and $files->[0]->{type} eq 'package';
    }

    return $files;
  });
} # get_item_list

sub get_legal ($;%) {
  my ($self, %args) = @_;
  local $self->{_no_upstream_legal} = 1;
  return $self->SUPER::get_legal (%args);
} # get_legal

sub _get_item ($$$) {
  my ($self, $ix, $args) = @_;
  if (defined $args->{url}) {
    my (undef, $item) = $ix->get_item
        (url_string => $args->{url}->stringify, file_def => undef);
    return $item; # or undef
  }
  return undef;
} # _get_item

1;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
