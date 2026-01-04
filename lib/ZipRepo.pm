package ZipRepo;
use strict;
use warnings;
use Carp;
use Promise;
use Promised::Flow;

use Repo;
push our @ISA, qw(Repo);

use Zipper;
use RepoIndexFile;
use FileTypes;

sub new_from_upstream ($$$;%) {
  my ($class, $upstream_repo, $upstream_args, %args) = @_;

  my $self = bless {
    set => $upstream_repo->set,
    upstream_repo => $upstream_repo,
    upstream_args => $upstream_args,
    forced_encoding => $args{forced_encoding}, # or undef
    forced_tzoffset => $args{forced_tzoffset}, # or undef
  }, $class;
  $self->_set_key (join $;, $self->{forced_encoding}//'');

  return $self;
} # new_from_and_upstream

sub type ($) { "zip" }
sub is_nested ($) { 1 } 

sub read_index ($) {
  my $self = $_[0];
  return $self->{upstream_repo}->read_index->then (sub {
    my $upix = $_[0];
    my $upitem = $self->{upstream_repo}->_get_item
        ($upix, $self->{upstream_args});
    if (not defined $upitem) {
      my $logger = $self->set->app->logger;
      $logger->message ({
        type => 'no local copy available',
        path => $self->{upstream_args}->{path_string}, # or undef
        (defined $self->{upstream_args}->{url} ? (url => $self->{upstream_args}->{url}->stringify) : ()),
      });
      #$args{has_error}->();
      return $self->SUPER::read_index;
    }

    my $storage = $upix->get_storage_of
        ($upitem, "archive-" . $self->type, allow_missing => 1,
         nested => $self->{upstream_repo}->is_nested); # or undef
    unless (defined $storage) {
      ## Dummy object used for new not-initialized-yet repo
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
  return $self->{upstream_repo}->lock_index->then (sub {
    my $upix = $_[0];
    my $upitem = $self->{upstream_repo}->_get_item
        ($upix, $self->{upstream_args});
    if (not defined $upitem) {
      # XXX This will create a broken index file...
      return $self->SUPER::lock_index;
    }

    my $storage = $upix->get_storage_of
        ($upitem, "archive-" . $self->type, prefix => 'archive-',
         create_if_missing => 1, nested => $self->{upstream_repo}->is_nested);
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

sub fetch ($;%) {
  my ($self, %args) = @_;
  my $file_defs = $args{file_defs} || {};
  my $ret = {};
  return Promise->resolve->then (sub {
    if (defined $self->{upstream_args}->{url}) {
      return $self->{upstream_repo}->fetch (
        %args,
        skip_unless_url => $self->{upstream_args}->{url},
        skip_unless_path_string => undef,
        skip_other_files => 1,
      )->then (sub {
        $ret->{has_package} = 1;
      });
    } elsif (defined $self->{upstream_args}->{path_string}) {
      return $self->{upstream_repo}->fetch (
        %args,
        skip_unless_url => undef,
        skip_unless_path_string => $self->{upstream_args}->{path_string},
        skip_other_files => 1,
      )->then (sub {
        $ret->{has_package} = 1;
      });
    } else {
      die "No |upstream_args| data";
    }
  })->then (sub {
    return if $args{min};
    return $self->get_item_list (
      with_path => 1, with_item_key => 1, with_source_meta => 1,
      file_defs => $file_defs,
      has_error => $args{has_error},
      with_skipped => defined $args{file_key},
      skip_other_files => (defined $args{skip_unless_path_string} ? 0 : $args{skip_other_files}),
      skip_if_found => $args{no_update},
      skip_unless_path_string => $args{skip_unless_path_string},
      data_area_key => $args{data_area_key},
    )->then (sub {
      my $files = shift;

      return $self->_extract_files ($files,
        file_defs => $file_defs,
        has_error => $args{has_error},
      );
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
      title => '',
      lang => '',
      dir => 'auto',
      writing_mode => 'horizontal-tb',
    },
  };

  return $self->read_index->then (sub {
    my $zipix = $_[0];
    my $upitem = $zipix->upstream_item;
    unless (defined $upitem) {
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
    $pack_file->{package_item}->{mime} = FileTypes::force_zip_mime_type $pack_file->{package_item}->{mime};

    my $zip_path = $zipix->upstream_index->get_path_of ($upitem, 'data'); # or throw
    return Promise->all ([
      Zipper->list (
        $self->set->app, $zip_path,
        url_string => ($upitem->{rev} || {})->{url}, # string or undef # XXX or parent url, if nested archive
        forced_encoding => $self->{forced_encoding}, # or undef
        forced_tzoffset => $self->{forced_tzoffset}, # or undef
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

        return {files => [], meta => {comment => ''}};
      }),
    ])->then (sub {
      my ($info) = @{$_[0]};

      if ($args{with_props}) {
        $pack_file->{package_item}->{desc} = $info->{meta}->{comment};
        $pack_file->{package_item}->{tzoffset} = $info->{meta}->{tzoffset}
            if defined $info->{meta}->{tzoffset};
      }
      $pack_file->{archive_meta} = $info->{meta} if $args{with_source_meta};
      
      my $seen = {};
      my $i = 0;
      for my $zipped_file (@{$info->{files}}) {
        ## At the moment we only can expose files.  We are not
        ## interested in directories and their attributes.
        next if $zipped_file->{is_directory};

        ## $zipped_file depends on sniffed encoding and tzoffset when
        ## they are not encoded within the ZIP archive itself or
        ## provided as forced_* options.  This means that, when a new
        ## version of ddsd updates its sniffing algortihm, it can
        ## start returning different sniffed encoding and tzoffset
        ## from those of earlier versions.  Still the connections
        ## between $file objects and items in the archive's repository
        ## index file are kept through the raw paths of them.
        
        ## $zipped_file->{central}->{raw_path} may or may not be a
        ## character string.  It can be used to obtain a file from
        ## ZIP.
        ##
        ## $zipped_file->{path} is a character string.  If a
        ## non-standard Unicode file name is specified, that value is
        ## set to here with no $zipped_file->{path_encoding}.
        ## Otherwise, the sniffed encoding used to decode the file
        ## name is set to $zipped_file->{path_encoding}.
        
        my $file_key = 'file:' . $zipped_file->{path};
        if (defined $seen->{$file_key}) {
          $file_key = 'file:' . $zipped_file->{central}->{raw_path};
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

        $self->_set_item_file_info
            ([raw_path_string => $zipped_file->{central}->{raw_path}],
             $fdef, $zipix, $file, %args)
            unless $skipped;
        $file->{archive_item} = $zipped_file if $args{with_source_meta};
        if ($args{with_props}) {
          my $pi = $file->{package_item};
          $pi->{file_name} = $zipped_file->{path};
          {
            my $cmime = FileTypes::get_mime_type_from_file_name $pi->{file_name};
            $pi->{mime} = $cmime // 'application/octet-stream';
          }
          $pi->{desc} = $zipped_file->{comment} // '';

          $pi->{file_time} = App::NumberString->new ($zipped_file->{mtime});
          if (defined $pi->{file_time}) {
            $pack_file->{package_item}->{file_time} //= $pi->{file_time};
            $pack_file->{package_item}->{file_time} = $pi->{file_time}
                if $pack_file->{package_item}->{file_time} < $pi->{file_time};
          }
          if (defined $zipped_file->{tzoffset}) {
            $pi->{tzoffset} = $zipped_file->{tzoffset};
          } else {
            # XXX local time flag
          }
        } # props
        
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

      if (defined $pack_file->{package_item}->{rev}) {
        $pack_file->{package_item}->{file_time} //= $pack_file->{package_item}->{rev}->{timestamp};        
      }
      $pack_file->{package_item}->{file_time} //= time;
    } # with_props
  })->then (sub {
    return $files;
  });
} # get_item_list

sub _get_item ($$$) {
  my ($self, $ix, $args) = @_;
  if (defined $args->{path_string}) {
    my (undef, $item) = $ix->get_item
        (path_string => $args->{path_string}, file_def => undef);
    return $item; # or undef
  }
  return undef;
} # _get_item

sub _extract_files ($$;%) {
  my ($self, $files, %args) = @_;
  my $pack_file = $files->[0]; # must be type=package
  my $file_defs = $args{file_defs} || {};
  my $logger = $self->set->app->logger;
  return $self->lock_index->then (sub {
    my $zipix = $_[0];
    my $upitem = $zipix->upstream_item;
    return unless defined $upitem;

    $zipix->ensure_type ('archive');
    my $zip_path = $zipix->upstream_index->get_path_of ($upitem, 'data'); # or throw
    my $temp_storage = $self->set->app->temp_storage;
    return $temp_storage->mkpath->then (sub {
      return promised_for {
        my $file = shift;
        return unless $file->{type} eq 'file';
        my $fdef = $file_defs->{$file->{key}};

          if (defined $fdef and $fdef->{skip} and
              not $args{with_skipped}) {
            return;
          }
          
          my $zip_item = $zipix->get_item
              (raw_path_string => $file->{archive_item}->{central}->{raw_path});
          if (defined $zip_item) {
            $logger->info ({
              type => 'item already expanded',
              value => $file->{path},
            });
            return $zipix->update_zip_item_index (
              $file, $zip_item,
              insecure => $upitem->{rev}->{insecure},
            );
          } else {
            my $dest_path = $temp_storage->create_child_path;
            return Zipper->extract (
              $self->set->app, $zip_path, $file->{archive_item}->{central}->{raw_path},
              $dest_path,
            )->then (sub {
              return $zipix->put_zip_item (
                $file, $_[0], $dest_path,
                insecure => $upitem->{rev}->{insecure},
              )->then (sub {
                my $r = $_[0];
                return $zipix->save;
              });
            });
          }
      } $files;
    })->then (sub { $zipix->save })->finally (sub { $zipix->close });
  });
} # _extract_files

1;

=head1 LICENSE

Copyright 2025-2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
