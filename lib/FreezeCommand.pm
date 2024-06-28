package FreezeCommand;
use strict;
use warnings;

use Command;
push our @ISA, qw(Command);

use PackageListFile;

sub run ($$;%) {
  my ($self, $da_name, %args) = @_;
  my $logger = $self->app->logger;
  return PackageListFile->open_by_app ($self->app, lock => 1)->then (sub {
    my $plist = $_[0];

    my $def = $plist->get_def ($da_name);
    return $logger->throw ({
      type => 'data area key not found',
      value => $da_name,
      path => $plist->path,
    }) unless defined $def;
    
    my $repo = $self->app->repo_set->get_repo_by_source
        ($def, path => $plist->path);
    my $da_repo = $self->app->data_area->get_repo ($da_name);
    return $da_repo->construct_file_list_of (
      $repo, $def,
      has_error => sub { },
      data_area_key => $da_name,
    )->then (sub {
      my $files = shift;
      for my $file (@$files) {
        if (defined $file->{path} and
            not $def->{files}->{$file->{key}}->{skip} and
            defined $file->{snapshot}->{file_name}) {
          if (defined $file->{rev} and $file->{rev}->{sha256}) {
            $def->{files}->{$file->{key}}->{sha256} = $file->{rev}->{sha256};
            $def->{files}->{$file->{key}}->{sha256_insecure} = 1
                if $file->{rev}->{insecure};
          }
          unless ($file->{type} eq 'part') {
            my $name = $file->{snapshot}->{file_name};
            if ($name =~ s{^files/}{}) {
              $def->{files}->{$file->{key}}->{name} = $name;
            }
          }
        } elsif ($file->{type} eq 'package' or
                 $file->{type} eq 'part' or
                 $file->{type} eq 'dataset') {
          $def->{files}->{$file->{key}} ||= {};
        } else { # local copy not available
          $def->{files}->{$file->{key}}->{skip} = \1;
        }
      } # $file
      $def->{skip_other_files} = \1;
      $plist->touch;
      return $plist->save;
    })->finally (sub {
      return $plist->close;
    })->finally (sub {
      return $repo->close;
    })->finally (sub {
      return $da_repo->close;
    });
  });
} # run

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
