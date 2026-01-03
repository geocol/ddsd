package SnapshotRepo;
use strict;
use warnings;
use Promise;
use Promised::Flow;

use Repo;
push our @ISA, qw(Repo);

use ListWriter;

sub new_from_set_and_storage ($$$) {
  my ($class, $set, $storage) = @_;

  my $self = bless {
    set => $set,
    storage => $storage,
  }, $class;

  return $self;
} # new_from_set_and_storage

sub type () { "datasnapshot" }

sub sync ($$$;%) {
  my ($self, $from_repo, $files, %args) = @_;
  my $storage = $self->storage;
  return Promise->resolve->then (sub {
    return $self->lock_index;
  })->then (sub {
    my $ix = $_[0];
    $ix->ensure_type ($self->type);
    return Promise->all ([
      Promised::File->new_from_path ($storage->{path}->child ('files'))->remove_tree (unsafe => 1),
      Promised::File->new_from_path ($storage->{path}->child ('package'))->remove_tree (unsafe => 1),
      Promised::File->new_from_path ($storage->{path}->child ('LICENSE'))->remove_tree (unsafe => 1),
      Promised::File->new_from_path ($storage->{path}->child ('index.json'))->remove_tree (unsafe => 1),
    ])->then (sub {
      my $items = $ix->items;
      $ix->touch;
      return promised_for {
        my $file = shift;

        return if $file->{snapshot}->{is_directory};
        
        my $name = $file->{snapshot}->{file_name} //
                   $file->{snapshot}->{dup_file_name};
        return unless defined $name;

        my $item = {};
        $item->{type} = $file->{type};
        $item->{files}->{data} = $name;
        $item->{rev} = $file->{rev};
        $items->{$file->{key}} = $item;

        return unless defined $file->{snapshot}->{file_name};
        return $storage->hardlink_from ($name, $file->{path})->then (sub {
          my $path = $storage->child_path ($name);
          my $ff = Promised::File->new_from_path ($path);
          my $ts = $file->{package_item}->{file_time}; 
          return $ff->utime ($ts, $ts);
          ## Snapshot file's timestamp is changed to item's timestamp
          ## metadata.  As this file is a hardlink of the data file in
          ## the local data repository set, when there are multiple
          ## snapshots from same source, only one of their timestamps
          ## can be used as the file's timestamp.
        });
      } $files;
    })->then (sub { return $ix->save (readonly => 1) })->finally (sub { $ix->close })->then (sub {
      my $legal_path = $storage->{path}->child ('LICENSE');
      my $outer = ListWriter->new_from_filehandle ($legal_path->openw);
      my $cleanup = sub { };
      return $from_repo->get_legal (data_area_key => $args{data_area_key})->then (sub {
        my $json = $_[0];
        $cleanup = $from_repo->format_legal ($outer, $json); # XXX locale
      })->finally (sub {
        $cleanup->();
        return $outer->close->then (sub {
          my $file = Promised::File->new_from_path ($legal_path);
          return $file->chmod (0444);
        });
      });
    });
  });
} # sync

1;

=head1 LICENSE

Copyright 2024-2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
