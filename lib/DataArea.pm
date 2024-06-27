package DataArea;
use strict;
use warnings;

use RepoSet;
push our @ISA, qw(RepoSet);

use FileNames;

sub get_repo ($$) {
  my ($self, $short_name) = @_;
  return undef unless FileNames::is_free_file_name $short_name;
  my $storage = $self->storage->child ($short_name);
  require SnapshotRepo;
  return SnapshotRepo->new_from_set_and_storage ($self, $storage);
} # get_repo

sub get_export_repo ($) {
  my ($self) = @_;
  my $storage = $self->storage->child (rand);
  require ExportRepo;
  return ExportRepo->new_from_set_and_storage ($self, $storage);
} # get_export_repo

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
