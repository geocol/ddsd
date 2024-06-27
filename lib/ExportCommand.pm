package ExportCommand;
use strict;
use warnings;
use Path::Tiny;
use Promise;
use Promised::File;

use Command;
push our @ISA, qw(Command);

use Zipper;
use PackageListFile;
use ListWriter;

sub run ($$$$;%) {
  my ($self, $out_type, $repo_name, $out_file_name, $out, %args) = @_;
  if ($out_type eq 'mirrorzip') {
    return $self->app->logger->throw ({
      type => 'Bad output file name',
      value => $out_file_name,
    }) unless length $out_file_name;
    my $out_path = path ($out_file_name);
    return $self->run_mirror_zip ($repo_name => $out_path, $out);
  } else {
    my $logger = $self->app->logger;
    return $logger->throw ({
      type => 'Bad output type',
      value => $out_type,
    });
  }
} # run

sub run_mirror_zip ($$$$) {
  my ($self, $data_repo_name, $out_path, $out) = @_;
  my $outer = ListWriter->new_from_filehandle ($out);
  return Promise->all ([
    PackageListFile->open_by_app ($self->app, allow_missing => 1),
  ])->then (sub {
    my $plist = $_[0]->[0];
    my $logger = $self->app->logger;
    
    my $def = $plist->get_def ($data_repo_name);
    return $logger->throw ({
      type => 'data area key not found',
      value => $data_repo_name,
      path => $plist->path,
    }) unless defined $def;

    my $repo = $self->app->repo_set->get_repo_by_source
        ($def, path => $plist->path);
    return Promise->resolve->then (sub {
      my $out_dir = Promised::File->new_from_path ($out_path->parent);
      my $da_repo = $self->app->temp_data_area->get_export_repo;
      return $da_repo->construct_file_list_of (
        $repo, $def,
        has_error => sub {
          $self->has_error (1);
        },
        skip_other_files => $def->{skip_other_files},
        data_area_key => $data_repo_name,
      )->then (sub {
        my $files = shift;
        return $da_repo->prepare_files ($repo, $files, data_area_key => $data_repo_name);
      })->then (sub {
        my $map = $_[0];
        return $out_dir->mkpath->then (sub {
          return Zipper->create (
            $self->app,
            $map => $out_path,
          );
        });
      })->finally (sub {
        return $da_repo->close;
      });
    })->finally (sub {
      return $repo->close;
    });
  })->then (sub {
    $outer->item ($_[0]);
  })->finally (sub {
    return $outer->close;
  });
} # run_mirror_zip

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
