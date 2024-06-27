package LegalCommand;
use strict;
use warnings;
use Promise;

use Command;
push our @ISA, qw(Command);

use PackageListFile;
use ListWriter;

sub run ($$$;%) {
  my ($self, $out, $data_repo_name, %args) = @_;
  my $outer = ListWriter->new_from_filehandle ($out);
  my $cleanup = sub { };
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
    return $repo->_use_mirror ($data_repo_name, $def)->then (sub {
      return $repo->get_legal (data_area_key => $data_repo_name);
    })->then (sub {
      my $json = $_[0];
      $cleanup = $repo->format_legal ($outer, $json, json => $args{json}); # XXX locale
    })->finally (sub {
      return $repo->close;
    });
  })->finally (sub {
    $cleanup->();
    return $outer->close;
  });
} # run

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
