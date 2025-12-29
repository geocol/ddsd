package ZipRepo;
use strict;
use warnings;
use Promise;
use Promised::Flow;

use Repo;
push our @ISA, qw(Repo);

use Zipper;
use RepoIndexFile;

sub new_from_upstream ($$$) {
  my ($class, $upstream_repo, $key) = @_;

  my $self = bless {
    set => $upstream_repo->set,
    upstream_repo => $upstream_repo,
    upstream_item_key => $key,
  }, $class;

  return $self;
} # new_from_and_upstream

sub type () { "zip" }

sub fetch ($;%) {
  my ($self, %args) = @_;
  my $ret = {};
  return Promise->resolve->then (sub {
    if (defined $self->{upstream_item_key}) {
      return $self->{upstream_repo}->fetch (%args, file_defs => {
        $self->{upstream_item_key} => {},
      }, skip_other_files => 1)->then (sub {
        $ret->{has_package} = 1;
      });
    } # else : Assert: never
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

  return $self->{upstream_repo}->read_index->then (sub {
    my $upix = $_[0];
    my $upitem = $self->{upstream_repo}->_get_item_by_key
        ($upix, $self->{upstream_item_key});
    if (not defined $upitem) {
      $logger->message ({
        type => 'no local copy available',
        key => $self->{upstream_item_key},
      });
      $args{has_error}->();
      return;
    }

    $self->{upstream_repo}->_set_item_file_info (undef, {}, undef, $upitem);

    if (defined $upitem->{rev}) {
      $pack_file->{rev} = $upitem->{rev};
      $pack_file->{package_item}->{file_time} = $pack_file->{rev}->{http_last_modified}
          if $pack_file->{rev}->{http_last_modified};
    }
    for (keys %{$upitem->{package_item} or {}}) {
      $pack_file->{package_item}->{$_} = $upitem->{package_item}->{$_};
    }

    my $storage = $upix->get_storage_of
        ($upitem, 'extracted', allow_missing => 1); # or undef
    my $zip_path = $upix->get_path_of ($upitem, 'data'); # or throw
    return Promise->all ([
      Zipper->list (
        $self->set->app, $zip_path,
        url_string => ($upitem->{rev} || {})->{url}, # string or undef # XXX or parent url, if nested archive
        #path_encoding => $args{XXX}, # XXX overridden, or parent archive's encoding if nested
      )->catch (sub {
        my $e = $_[0];
        die $e unless UNIVERSAL::isa ($e, 'App::Error');

        ## If $e is our error, it is already reported.  Just discard
        ## it.  Maybe the ZIP file is broken, or our data repository
        ## is broken.

        $logger->message ({
          type => 'broken file', format => 'zip',
          url => ($upitem->{rev} || {})->{url}, # string or undef
        });
        $args{has_error}->();

        return {files => []};
      }),
      (defined $storage ? RepoIndexFile->open_by_app_and_storage (
        $self->set->app, $storage, allow_missing => 1,
      ) : undef),
    ])->then (sub {
      my ($info, $zipix) = @{$_[0]};

      my $seen = {};
      my $i = 0;
      for my $zipped_file (@{$info->{files}}) {
        ## $zipped_file->{name} is always available.  It may or may
        ## not be a character string.  It can be used to obtain a file
        ## from ZIP.
        ##
        ## $zipped_file->{path} may or may not be available.  It is a
        ## character string.  If a non-standard Unicode file name is
        ## specified, that value is used with no
        ## $zipped_file->{path_encoding}.  Otherwise, the sniffed
        ## encoding used to decode the file name is set to
        ## $zipped_file->{path_encoding}.
        
        my $file_key = 'file:' . ($zipped_file->{path} // $zipped_file->{name});
        if (defined $seen->{$file_key}) {
          $file_key = 'file:' . $zipped_file->{name}; # raw path
        }
        while (defined $seen->{$file_key}) {
          $file_key = 'object:' . $i++;
        }
        $seen->{$file_key}++;
        my $fdef = $file_defs->{$file_key};

        my $file = {key => $file_key};
        $file->{type} = 'file';
        
        my $skipped;
        if (defined $fdef and $fdef->{skip}) {
          $skipped = 1;
            if ($args{with_skipped}) {
              #
            } else {
              $logger->info ({
                type => 'item ignored by skip',
                value => $file->{key},
                #path => $in->path->absolute,
              });
              next;
            }
          } # skip

        $file->{source}->{file_name} = $zipped_file->{path} // $zipped_file->{name};
        $file->{package_item}->{file_time} = $zipped_file->{time};
        $file->{package_item}->{mime} = 'application/octet-stream';
        $file->{package_item}->{title} = '';
        if ($args{with_source_meta}) {
          for (qw(path_encoding time)) {
            $file->{archive_item}->{$_} = $zipped_file->{$_} if defined $zipped_file->{$_};
          }
          $file->{archive_item}->{byte_length} = $zipped_file->{size};
          $file->{archive_item}->{raw_path} = $zipped_file->{name};
          $file->{archive_item}->{path} = $file->{source}->{file_name};
        } # meta

        ## These need to be redone in _extract_files
        $self->_set_item_file_info
            ([raw_path_string => $zipped_file->{name}],
             $fdef, $zipix, $file, %args)
            unless $skipped; # XXX tests for skipped

        if (defined $file->{package_item}->{file_time}) {
          $pack_file->{package_item}->{file_time} //= $file->{package_item}->{file_time};
          $pack_file->{package_item}->{file_time} = $file->{package_item}->{file_time}
              if $pack_file->{package_item}->{file_time} < $file->{package_item}->{file_time};
        }

        push @$files, $file;
      } # $zipped_file
    });
  })->then (sub {
    if ($args{with_props} or $args{with_snapshot_hash}) {
      unshift @$files, $pack_file
          unless @$files and $files->[0]->{type} eq 'package';
      if ($args{with_snapshot_hash}) {
        $self->_set_snapshot_hash ($files);
      }

      $pack_file->{package_item}->{file_time} //= time;
    } # with_props
  })->then (sub {
    return $files;
  });
} # get_item_list

sub _extract_files ($$;%) {
  my ($self, $files, %args) = @_;
  my $pack_file = $files->[0]; # must be type=package
  my $file_defs = $args{file_defs} || {};
  my $logger = $self->set->app->logger;
  return Promise->resolve->then (sub {
    return $self->{upstream_repo}->lock_index;
  })->then (sub {
    my $upix = $_[0];
    my $upitem = $self->{upstream_repo}->_get_item_by_key
        ($upix, $self->{upstream_item_key});
    return unless defined $upitem;

    my $storage = $upix->get_storage_of
        ($upitem, 'extracted', prefix => $self->type . '-',
         create_if_missing => 1);
    return $storage->mkpath->then (sub { $upix->save })->finally (sub { $upix->close })->then (sub {
      return RepoIndexFile->open_by_app_and_storage (
        $self->set->app, $storage, allow_missing => 1, lock => 1,
      );
    })->then (sub {
      my $zipix = $_[0];
      $zipix->ensure_type ('archive');

      my $temp_storage = $self->set->app->temp_storage;
      return $temp_storage->mkpath->then (sub {
        my $zip_path = $upix->get_path_of ($upitem, 'data'); # or throw
        return promised_for {
          my $file = shift;
          return unless $file->{type} eq 'file';
          my $fdef = $file_defs->{$file->{key}};

          if (defined $fdef and $fdef->{skip} and
              not $args{with_skipped}) {
            return;
          }
          
          if (defined $file->{path}) {
            $logger->info ({
              type => 'item already expanded',
              value => $file->{path},
            });
            return;
          }
          
          my $zip_item = $zipix->get_item
              (raw_path_string => $file->{archive_item}->{raw_path});
          if (defined $zip_item) {
            $file->{path} = $zipix->get_path_of ($zip_item, 'data'); # or throw
          } else {
            my $dest_path = $temp_storage->create_child_path;
            return Zipper->extract (
              $self->set->app, $zip_path, $file->{archive_item}->{raw_path},
              $dest_path,
            )->then (sub {
              return $zipix->put_zip_item (
                $file, $_[0], $dest_path,
            #, insecure => $XXX
              )->then (sub {
                my $r = $_[0];
                $file->{path} = $r->{data_path};
                return $zipix->save;
              });
            })->then (sub {
              ## These are done once in _extract_files
              $self->_set_item_file_info
                  ([raw_path_string => $file->{archive_item}->{raw_path}],
                   $fdef, $zipix, $file, %args);

              if (defined $file->{package_item}->{file_time}) {
                $pack_file->{package_item}->{file_time} //= $file->{package_item}->{file_time};
                $pack_file->{package_item}->{file_time} = $file->{package_item}->{file_time}
                    if $pack_file->{package_item}->{file_time} < $file->{package_item}->{file_time};
              }
            });
          }
        } $files;
      })->then (sub { $zipix->save })->finally (sub { $zipix->close });
    });
  });
} # _extract_files

1;

=head1 LICENSE

Copyright 2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
