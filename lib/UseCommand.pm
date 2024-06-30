package UseCommand;
use strict;
use warnings;

use Command;
push our @ISA, qw(Command);

use PackageListFile;

sub run ($$$$;%) {
  my ($self, $mode, $da_name, $file_key, %args) = @_;
  my $logger = $self->app->logger;
  my $def;
  my $plist;
  my $repo;
  my $da_repo;
  return Promise->resolve->then (sub {
    return $self->_pull_ddsd_data (%args) if $mode eq 'use';
  })->then (sub {
    return PackageListFile->open_by_app ($self->app, lock => 1, allow_missing => 1);
  })->then (sub {
    $plist = $_[0];

    $def = $plist->get_def ($da_name);
    return $logger->throw ({
      type => 'data area key not found',
      value => $da_name,
      path => $plist->path,
    }) unless defined $def;

    $repo = $self->app->repo_set->get_repo_by_source
        ($def, path => $plist->path);
    $da_repo = $self->app->data_area->get_repo ($da_name);
    
    if ($mode eq 'use') {
      if (defined $file_key) {
        die "Bad --all" if $args{all};
        delete $def->{files}->{$file_key}->{skip};
        if (defined $args{name}) {
          $def->{files}->{$file_key}->{name} = $args{name};
        }
      } else {
        die "No file key" unless $args{all};
        for my $key (keys %{$def->{files} or {}}) {
          delete $def->{files}->{$key}->{skip};
        }
      }
      $plist->touch;
    } elsif ($mode eq 'unuse') {
      die "No file_key" unless defined $file_key;
      $def->{files}->{$file_key}->{skip} = \1;
      $plist->touch;
    } else {
      die "Bad mode |$mode|";
    }
  })->then (sub {
    return $plist->save;
  })->finally (sub {
    return $plist->close if defined $plist;
  })->then (sub {
    if ($mode eq 'use') {
      return $repo->_find_mirror ($da_name, $def);
    } elsif ($mode eq 'unuse') {
      return $repo->_use_mirror ($da_name, $def);
    }
  })->then (sub {
    return $repo->fetch (
      cacert => $args{cacert},
      insecure => $args{insecure} || $def->{insecure},
      file_defs => $def->{files},
      has_error => sub { $self->has_error (1) },
      skip_other_files => $def->{skip_other_files},
      no_update => 1,
      data_area_key => $da_name,
    );
  })->then (sub {
    if (($mode eq 'use' and defined $file_key and
         not defined $def->{files}->{$file_key}->{name}) or
        ($mode eq 'use' and not defined $file_key)) {
      return PackageListFile->open_by_app ($self->app, lock => 1, allow_missing => 1)->then (sub {
        $plist->close;
        $plist = $_[0];
        $def = $plist->get_def ($da_name);
        return $logger->throw ({
          type => 'data area key not found',
          value => $da_name,
          path => $plist->path,
        }) unless defined $def;
        $logger->info ({
          type => 'reassign file name if necessary',
          key => $file_key, # or undef
        });
        return $da_repo->construct_file_list_of (
          $repo, $def,
          has_error => sub { },
          init_by_default => $mode eq 'use',
          init_key => $file_key, # or undef
          init_no_skip_marking => 1,
          data_area_key => $da_name,
        );
      })->then (sub {
        return $plist->save;
      })->finally (sub {
        return $plist->close;
      });
    }
  })->then (sub {
    return $da_repo->construct_file_list_of (
      $repo, $def,
      has_error => sub { },
      data_area_key => $da_name,
    );
  })->then (sub {
    my $files = shift;
    if ($mode eq 'use' and defined $file_key) {
      my $found = 0;
      for my $file (@$files) {
        if ($file->{key} eq $file_key) {
          $found = 1;
        }
      }
      unless ($found) {
        $logger->message ({
          type => 'added file not found',
          key => $file_key,
        });
        $self->has_error (1);
      }
    } # use
    return $da_repo->sync ($repo, $files, data_area_key => $da_name);
  })->finally (sub {
    return $da_repo->close if defined $da_repo;
  })->finally (sub {
    return $repo->close if defined $repo;
  })->finally (sub {
    $logger->message_counts;
  });
} # run

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
