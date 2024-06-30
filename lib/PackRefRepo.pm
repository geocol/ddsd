package PackRefRepo;
use strict;
use warnings;
use Time::HiRes qw(time);
use Web::URL;
use Promised::Flow;
use Promised::File;
use JSON::PS;

use Repo;
push our @ISA, qw(Repo);

use PackRef;

sub new_from_set_and_url ($$$) {
  my ($class, $set, $url) = @_;

  my $self = bless {
    set => $set,
    url => $url,
  }, $class;

  my $u = $url->stringify;
  $u =~ s{#.*}{}s; # XXX
  $self->_set_key ($u);

  return $self;
} # new_from_set_and_url

sub type () { "packref" }

sub fetch ($;%) {
  my ($self, %args) = @_;
  my $logger = $args{logger} // $self->set->app->logger;
  my $file_defs = $args{file_defs} || {};
  my $ret = {};
  my $has_source = 0;
  my $snapshot_hash_items = [];
  my $package_item_key;
  my $x;
  if ($args{is_special_repo}) {
    $x //= {};
    $x->{_} //= 1;
    $x->{timestamp} //= time;
    $ret->{timestamp} = $x->{timestamp};
  }
  my $r_item_key;
  return $self->_fetch_file (
    $self->{url}, undef,
    %args,
    mime => 'json',
    dest_type => 'package',
    set_repo_type => 1,
    skip_if_found => $args{no_update},
    skip_if_new => $args{is_special_repo},
    force_fetch => (defined $x),
    fetch_log => $x, # or undef
    check_is_new_insecure => $args{is_special_repo},
    logger => $logger,
  )->then (sub {
    my $r = $_[0];
    $package_item_key = $r->{key}; # or undef
    $ret->{insecure} = 1 if $r->{insecure};
    if ($r->{error}) {
      if ($args{requires_package}) {
        return $logger->throw ({
          type => 'no packref available',
          url => $r->{url}->stringify,
        });
      }
      $ret->{broken} = 1;
      $args{has_error}->();
      $logger->count (['fetch_failure']);
      return;
    } elsif ($r->{not_modified}) {
      if ($r->{is_new}) {
        $ret->{timestamp} = $r->{is_new};
        $ret->{insecure} = 1 if $r->{is_new_insecure};
        $ret->{not_modified} = 1;
        $ret->{_skip} = 1;
        if ($r->{is_new_broken}) {
          $args{has_error}->();
          $ret->{broken} = 1;
          $logger->message ({
            type => 'package is broken',
            url => $r->{url}->stringify,
          });
          return;
        }
        return;
      } else {
        #
      }
    } else {
      $ret->{has_modified} = 1;
    }
    $r_item_key = $r->{key};
    
    return $self->read_index->then (sub {
      my $in = $_[0];
      my (undef, $item) = $in->get_item
          ($self->{url}->stringify, file_def => undef);
      if (defined $item) {
        $ret->{has_package} = 1;
      } else {
        $args{has_error}->();
        $ret->{broken} = 1;
        return;
      }
      return PackRef->open_by_app_and_path (
        $self->set->app,
        $self->storage->{path}->child ($item->{files}->{data}),
      )->then (sub {
        my $pack = $_[0];
        unless (defined $pack) {
          $args{has_error}->();
          $ret->{broken} = 1;
          return;
        }

        my $fdefs = $pack->get_file_defs ($file_defs);
        my $insecure = $args{insecure};
        my $as;
        return Promise->resolve->then (sub {
          my $source = $pack->get_package->{source};
          unless (defined $source and ref $source eq 'HASH') {
            $logger->message ({
              type => 'broken file', format => 'packref',
              %{$pack->{error_location}},
            });
            $args{has_error}->();
            $ret->{broken} = 1;
            return;
          }

          $insecure = 1 if $source->{insecure};
          my $repo = $self->set->get_repo_by_source
              ($source, error_location => $pack->{error_location},
               allow_bad_repo_type => 1, allow_files => 1);
          unless (defined $repo) {
            $args{has_error}->();
            $ret->{broken} = 1;
            return;
          }
          return if $repo eq ''; # type=files

          $has_source = 1;
          $ret->{has_package} = 1;
          return $repo->_find_mirror ($args{data_area_key}, $source)->then (sub {
            return $repo->fetch (
              %args,
              has_error => sub {
                $args{has_error}->();
                $ret->{broken} = 1;
              },
              file_defs => $fdefs,
              insecure => $insecure,
              #XXX nest_level
            );
          })->then (sub {
            my $sret = $_[0];
            $ret->{insecure} = 1 if $sret->{insecure};
          })->finally (sub {
            return $repo->close;
          });
        })->then (sub {
          return $self->get_item_list (
            with_source_meta => 1, not_from_source => 1,
            file_defs => $fdefs, has_error => $args{has_error},
            with_item_key => 1,
            data_area_key => $args{data_area_key},
            report_unknown_set_type => 1,
          );
        })->then (sub {
          my $files = $_[0];

          $as = $logger->start (0+@$files, {
            type => 'pull package files',
            all_count => 0+@$files,
            selected_count => 0+@$files,
          });
          return promised_for {
            my $file = shift;
            $as->{next}->(undef, undef, {key => $file->{key}, url => $file->{source}->{url}});

            return if not defined $file->{source}->{url};
            my $url = Web::URL->parse_string
                ($file->{source}->{url}, $self->{url});
            if (not defined $url or not $url->is_http_s) {
              $args{has_error}->();
              $ret->{broken} = 1;
              $as->message ({
                type => 'bad URL',
                value => $file->{source}->{url},
                file => $file,
              });
              return;
            }

            my $fdef = $fdefs->{$file->{key}};
            return $self->_fetch_file (
              $url, $fdef,
              %args,
              has_error => sub {
                $args{has_error}->();
                $ret->{broken} = 1;
              },
              mime => $file->{source}->{mime},
              insecure => $insecure,
              index_seen => 1, rev => $file->{rev}, item_key => $file->{item_key},
              skip_if_found => $args{no_update},
              skip_if_new => $args{is_special_repo},
              logger => $as,
            )->then (sub {
              my $r = $_[0];
              $ret->{insecure} = 1 if $r->{insecure};
              if ($r->{error}) {
                $args{has_error}->();
                $ret->{broken} = 1;
                $as->count (['fetch_failure']);
              } elsif ($r->{not_modified}) {
                # XXX at risk
                if (defined $file->{rev} and defined $file->{rev}->{sha256}) {
                  push @$snapshot_hash_items,
                      [$file->{key}, $file->{rev}->{sha256}];
                }
              } else {
                $ret->{has_modified} = 1;
                #XXX at risk
                if (defined $r->{item} and defined $r->{item}->{rev} and
                    defined $r->{item}->{rev}->{sha256}) {
                  push @$snapshot_hash_items,
                      [$file->{key}, $r->{item}->{rev}->{sha256}];
                }
              }
            });
          } $files;
        })->then ($as->{ok}, $as->{ng})->then (sub {
          return unless $pack->{package}->{is_legal};
          return if $has_source;
          for my $fdef (values %$file_defs) {
            if (defined $fdef and ref $fdef eq 'HASH' and
                $fdef->{skip}) {
              return;
            }
          }
          
          my $hash = $self->_get_snapshot_hash_of ($snapshot_hash_items);
          my $path = $self->storage->{path}->child ('hash.jsonl');
          my $file = $path->opena;
          print $file perl2json_bytes [time, $hash, $snapshot_hash_items];
          print $file "\x0A";

          $logger->info ({
            type => 'snapshot hash appended',
            path => $path->absolute,
          });
        });
      });
    });
  })->then (sub {
    return if $ret->{_skip};
    return if not defined $package_item_key;
    #return if $has_legal;
    return $self->_fetch_post_legal (
      %args,
      has_error => sub {
        $args{has_error}->();
        $ret->{broken} = 1;
      },
      dest_item_key => $package_item_key,
      packref_url => $self->{url},
      logger => $logger,
    );
  })->then (sub {
    return unless $args{is_special_repo};

    my $x = {_ => 'hasinsecure'};
    if ($ret->{insecure} and $ret->{has_modified}) {
      $x->{has_insecure} = 1;
    }
    if ($ret->{broken} and $ret->{has_modified}) {
      $x->{broken} = 1;
    }
    return unless 1 < keys %$x;
    
    return $self->lock_index->then (sub {
      my $ix = $_[0];
      return $ix->put_fetch_log_by_item_key (
        $r_item_key,
        fetch_log => $x,
      )->then (sub { $ix->save });
    });
  })->then (sub {
    return $ret;
  });
} # fetch

sub get_item_list ($;%) {
  my ($self, %args) = @_;
  my $logger = $self->set->app->logger;
  my $file_defs = $args{file_defs} || {};
  my $files = [];

  my $pack_file = {
    type => 'package',
    key => 'package',
    package_item => {
      title => '', desc => '', author => '', org => '',
      lang => '',
      dir => 'auto',
      writing_mode => 'horizontal-tb',
    },
  };
  
  return $self->read_index->then (sub {
    my $in = $_[0];

    my $packref_fdef = $file_defs->{'meta:packref.json'};
    my (undef, $item) = $in->get_item
        ($self->{url}->stringify, file_def => $packref_fdef);
    if (not defined $item) {
      $logger->message ({
        type => 'no local copy available',
        url => $self->{url}->stringify,
      });
      $args{has_error}->();
      return $files;
    }

    return Promise->all ([
      PackRef->open_by_app_and_path (
        $self->set->app, $self->storage->{path}->child ($item->{files}->{data}),
      ),
      (($args{with_props} and defined $item->{files}->{log}) ? Promised::File->new_from_path ($self->storage->{path}->child ($item->{files}->{log}))->read_byte_string : undef),
    ])->then (sub {
      my ($pack, $log_bytes) = @{$_[0]};
      unless (defined $pack) {
        $args{has_error}->();
        return;
      }

      my $source = $pack->get_package->{source};
      unless (defined $source and ref $source eq 'HASH') {
        $logger->message ({
          type => 'broken file', format => 'packref',
          %{$pack->{error_location}},
        });
        $args{has_error}->();
        return;
      }

      my $fdefs = $pack->get_file_defs ($file_defs);
      my $repo = $self->set->get_repo_by_source
          ($source, error_location => $pack->{error_location},
           allow_bad_repo_type => 1, allow_files => 1);
      my $repo_is_files = (defined $repo and $repo eq ''); # type=files
      return Promise->resolve->then (sub {
        if ($repo_is_files) {
          unshift @$files, $pack_file;

          my $terms_u = $pack->get_package->{terms_url};
          if (defined $terms_u) {
            my $url = Web::URL->parse_string ($terms_u, $self->{url});
            unless (defined $url and $url->is_http_s) {
              $args{has_error}->();
              $logger->message ({
                type => 'bad URL',
                value => $terms_u,
                key => 'terms_url',
                %{$pack->{error_location}},
              });
              $fdefs = {};
              return;
            }
            $pack_file->{parsed}->{site_terms_url} = $url;
          }
          my $pack_legal = $pack->get_package->{packref_license};
          if (defined $pack_legal) {
            unless ($pack_legal eq 'CC0-1.0') {
              $args{has_error}->();
              $logger->message ({
                type => 'bad license',
                value => $pack_legal,
                key => 'packref_license',
                %{$pack->{error_location}},
              });
              $fdefs = {};
              return;
            }
          }
          
          if ($args{with_props}) {
            $pack_file->{package_item}->{legal} = [];
            if (defined $log_bytes) {
              $self->_parse_log_legal
                  ($log_bytes => $pack_file->{package_item}->{legal});
            } # $log_bytes
            
            my $meta = $pack->get_package->{meta};
            for my $key (qw(title desc author org lang dir writing_mode)) {
              $pack_file->{package_item}->{$key} = $meta->{$key} // $pack_file->{package_item}->{$key} // '';
            }
          } # props

          my $file = {key => 'meta:packref.json', type => 'meta'};
          if (defined $packref_fdef and $packref_fdef->{skip} and
              not $args{with_skipped}) {
            $logger->info ({
              type => 'item ignored by skip',
              value => $file->{key},
              path => $in->path->absolute,
            });
          } else {
            $file->{source}->{url} = $self->{url}->stringify
                if $args{with_source_meta};
            $self->_set_item_file_info
                ($self->{url}, $packref_fdef, $in, $file, %args,
                 default_mime => 'application/json',
                 default_directory_name => 'package',
                 default_file_name => 'packref.json');

            if (defined $file->{package_item}->{file_time}) {
              $pack_file->{package_item}->{file_time} //= $file->{package_item}->{file_time};
              $pack_file->{package_item}->{file_time} = $file->{package_item}->{file_time}
                  if $pack_file->{package_item}->{file_time} < $file->{package_item}->{file_time};
            }

            push @$files, $file;
          }
        } # $repo_is_files

        return if $args{not_from_source};

        return unless defined $repo;
        return if $repo_is_files;
        
        return $repo->_use_mirror ($args{data_area_key}, $source)->then (sub {
          return $repo->get_item_list (
            %args,
            file_defs => $fdefs,
            with_snapshot_hash => 0,
            # XXX nest level
          );
        })->then (sub {
          push @$files, @{$_[0]};
        });
      })->then (sub {
        return unless $repo_is_files;
        
        for my $file_key (keys %$fdefs) {
          next unless $file_key =~ /^file:r:/;
          my $fdef = $fdefs->{$file_key};

          my $file = {key => $file_key};

          if (defined $fdef->{set_type}) {
            $file->{type} = 'dataset';
            $file->{set_type} = $fdef->{set_type};
          } else {
            $file->{type} = 'file';
          }
          if (defined $fdef and $fdef->{skip}) {
            if ($args{with_skipped}) {
              #
            } else {
              $logger->info ({
                type => 'item ignored by skip',
                value => $file->{key},
                path => $in->path->absolute,
              });
              next;
            }
          } # skip

          my $url = Web::URL->parse_string ($fdef->{url}, $self->{url});
          $file->{source}->{url} = $url->stringify
              if ($args{with_source_meta} or
                  ($file->{type} eq 'dataset' and $file->{set_type} eq 'sparql')) and
                 defined $url;
          $self->_set_item_file_info ($url, $fdef, $in, $file, %args);

          if (defined $file->{package_item}->{file_time}) {
            $pack_file->{package_item}->{file_time} //= $file->{package_item}->{file_time};
            $pack_file->{package_item}->{file_time} = $file->{package_item}->{file_time}
                if $pack_file->{package_item}->{file_time} < $file->{package_item}->{file_time};
          }

          push @$files, $file;

          if ($file->{type} eq 'dataset') {
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
            } else { # set_type
              if ($args{report_unknown_set_type}) {
                $logger->message ({
                  type => 'unknown set_type',
                  value => $file->{set_type},
                  %{$pack->{error_location}},
                });
                $args{has_error}->();
                return;
              }
            }
          } # dataset
        } # $file_key
      })->finally (sub {
        return $repo->close if defined $repo and ref $repo;
      });
    });
  })->then (sub {
    if ($args{with_props} or $args{with_snapshot_hash}) {
      unshift @$files, $pack_file
          unless @$files and $files->[0]->{type} eq 'package';
      if ($args{with_snapshot_hash}) {
        $self->_set_snapshot_hash
            ($files,
             with_snapshot_hash_items => $args{with_snapshot_hash_items});
      }

      $pack_file->{package_item}->{file_time} //= time;
    } # with_props
  })->then (sub {
    return $files;
  });
} # get_item_list

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
