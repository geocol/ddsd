package PullCommand;
use strict;
use warnings;
use Web::URL;
use JSON::PS;
use Promised::Flow;
use Promised::File;

use Command;
push our @ISA, qw(Command);

use PackageListFile;

sub run ($;%) {
  my ($self, %args) = @_;
  my $logger = $self->app->logger;

  return $self->_pull_ddsd_data (%args)->then (sub {
    return PackageListFile->open_by_app ($self->app, allow_missing => 1);
  })->then (sub {
    my $plist = $_[0];
    my $list = $plist->defs;
    my $as = $logger->start (0+keys %$list, {
      type => 'pull packages',
    });
    return Promise->resolve->then (sub {
      return promised_for {
        my $key = shift;
        $as->{next}->(undef, undef, {key => $key});
        return if $key =~ /^\s*#/;
        
        my $def = $list->{$key};

        my $repo = $self->app->repo_set->get_repo_by_source
            ($def, path => $plist->path);
        return $repo->_find_mirror ($key, $def)->then (sub {
          return $repo->fetch (
            cacert => $args{cacert},
            insecure => $args{insecure} || $def->{insecure},
            file_defs => $def->{files},
            has_error => sub { $self->has_error (1) },
            skip_other_files => $def->{skip_other_files},
            data_area_key => $key,
            logger => $as,
          );
        })->then (sub {
          my $ret = $_[0];
          unless ($ret->{has_package}) {
            $as->message ({
              type => 'package data not available',
              value => $key,
            });
            return;
          }
          
          my $da_repo = $self->app->data_area->get_repo ($key);
          if (not defined $da_repo) {
            $as->message ({
              type => 'bad data area name',
              value => $key,
              path => $plist->path,
            });
            $self->has_error (1);
            return;
          }
          return $da_repo->construct_file_list_of (
            $repo, $def,
            has_error => sub {
              $self->has_error (1);
            },
            skip_other_files => $def->{skip_other_files},
            data_area_key => $key,
          )->then (sub {
            my $files = shift;
            return $da_repo->sync ($repo, $files);
          })->finally (sub {
            return $da_repo->close;
          });
        })->finally (sub {
          return $repo->close;
        });
      } [keys %$list];
    })->then ($as->{ok}, $as->{ng})->finally (sub {
      return $plist->close;
    });
  });
} # run

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
