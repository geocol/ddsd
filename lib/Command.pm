package Command;
use strict;
use warnings;
use Promised::Flow;

sub new_from_app ($$) {
  return bless {app => $_[1]}, $_[0];
} # new_from_app

sub app ($) { $_[0]->{app} }
sub has_error ($;$) { if (@_ > 1) { $_[0]->{has_error} = $_[1] } $_[0]->{has_error} }

sub _pull_ddsd_data ($;%) {
  my ($self, %args) = @_;
  my $logger = $self->app->logger;

  $logger->info ({
    type => 'update local ddsd data',
  });
  
  return promised_for {
    my ($key, $def) = @{$_[0]};

    my $repo = $self->app->repo_set->get_repo_by_source
        ($def, error_location => {});
    # no mirror
    return $repo->fetch (
      cacert => $args{cacert},
      insecure => $args{insecure} || $def->{insecure},
      file_defs => $def->{files},
      has_error => sub { $self->has_error (1) },
      skip_other_files => $def->{skip_other_files},
      is_special_repo => 1,
      data_area_key => undef,
    )->then (sub {
      my $ret = $_[0];
      unless ($ret->{has_package}) {
        $logger->message ({
          type => 'package data not available',
          value => $key,
        });
        return;
      }
      
      my $da_repo = $self->app->ddsd_data_area->get_repo ($key);
      if (not defined $da_repo) {
        $logger->message ({
          type => 'bad data area name',
          value => $key,
        });
        $self->has_error (1);
        return;
      }
      return $da_repo->construct_file_list_of (
        $repo, $def,
        has_error => sub { $self->has_error (1) },
        skip_other_files => $def->{skip_other_files},
        data_area_key => undef,
      )->then (sub {
        my $files = shift;
        return $da_repo->sync ($repo, $files, data_area_key => undef);
      })->finally (sub {
        return $da_repo->close;
      });
    })->finally (sub {
      return $repo->close;
    });
  } [
    ['legal' => {
      type => 'packref',
      url => 'https://gist.githubusercontent.com/wakaba/30f9cce1283f1eceb34a495c78d2b431/raw/packref.json',
    }],
    ['mirrors' => {
      type => 'packref',
      url => 'https://gist.githubusercontent.com/wakaba/aed3fb2f2ed824dbe6d932527dbc0d94/raw/packref.json',
    }],
  ];
} # _pull_ddsd_data

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
