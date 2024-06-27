package ExportRepo;
use strict;
use warnings;
use Web::Encoding;
use Promised::Flow;
use JSON::PS;

use Repo;
push our @ISA, qw(Repo);

use FileNames;
use ListWriter;

sub new_from_set_and_storage ($$$) {
  my ($class, $set, $storage) = @_;

  my $self = bless {
    set => $set,
    storage => $storage,
  }, $class;

  return $self;
} # new_from_set_and_storage

sub type { "mirrorzip" }

sub construct_file_list_of ($$$;%) {
  my ($self, $from_repo, $def, %args) = @_;
  my $app = $self->set->app;
  my $logger = $app->logger;
  return $from_repo->get_item_list (
    with_path => 1, file_defs => $def->{files},
    has_error => $args{has_error},
    skip_other_files => $args{skip_other_files},
    data_area_key => $args{data_area_key},
  )->then (sub {
    my $all_files = shift;
    my $files = [];
    for my $file (@$all_files) {
      if (not defined $file->{path}) { # no copy available
          unless ($file->{key} =~ /^package:/) {
            $args{has_error}->();
            $logger->message ({
              type => 'no local copy available',
              key => $file->{key},
            });
          }
          next;
      }
      
      if (defined $def->{files} and
          defined $def->{files}->{$file->{key}} and
          $def->{files}->{$file->{key}}->{skip}) {
        next;
      }

      push @$files, $file;
    } # $file
    return $files;
  });
} # construct_file_list_of

sub prepare_files ($$$;%) {
  my ($self, $from_repo, $files, %args) = @_;
  my $storage = $self->storage;
  my $map = [];

  my $legal_path = $storage->{path}->child ('LICENSE');
  my $ix;
  my $cleanup = sub { };
  return $self->lock_index->then (sub {
    $ix = $_[0];
    $ix->ensure_type ($self->type);
    $ix->touch;

    push @$map, {input_file_name => $ix->{path}->absolute,
                 file_name => 'index.json'};
    push @$map, {input_file_name => $legal_path->absolute,
                 file_name => 'LICENSE'};

    my $outer = ListWriter->new_from_filehandle ($legal_path->openw);
    return $from_repo->get_legal (data_area_key => $args{data_area_key})->then (sub {
      my $legal = $_[0];
      $ix->index->{legal} = $legal;
      $cleanup = $from_repo->format_legal ($outer, json_chars2perl perl2json_chars $legal); # XXX locale
    })->finally (sub {
      $cleanup->();
      return $outer->close;
    });
  })->then (sub {
    my $items = $ix->items;
    return promised_for {
      my $file = shift;

      my $item = {};
      $item->{type} = $file->{type};
      $item->{rev} = $file->{rev};
      $item->{key} = $file->{key};
      $items->{$file->{key}} = $item;
      
      my $name = $file->{rev}->{sha256};
      $item->{files}->{data} = 'data/' . $name . '.dat';
      push @$map, {input_file_name => $file->{path}->absolute,
                   file_name => $item->{files}->{data}};
      my $x = rand;
      if (defined $file->{meta_path}) {
        $item->{files}->{meta} = 'meta/' . $x . '-meta.json';
        push @$map, {
          input_file_name => $file->{meta_path},
          file_name => $item->{files}->{meta},
        };
      }
      if (defined $file->{log_path}) {
        $item->{files}->{log} = 'meta/' . $x . '-log.jsonl';
        push @$map, {
          input_file_name => $file->{log_path},
          file_name => $item->{files}->{log},
        };
      }
    } $files;
  })->then (sub { $ix->save })->then (sub {
    return $map;
  });
} # prepare_files

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
