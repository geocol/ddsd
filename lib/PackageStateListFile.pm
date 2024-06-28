package PackageStateListFile;
use strict;
use warnings;

use JSONFile;
push our @ISA, qw(JSONFile);

sub open_by_app ($$;%) {
  my ($class, $app, %args) = @_;
  my $list_path = $app->states_path->child ('packages.json');

  my $init = sub {
    my ($self, $logger, $path, $json, %args) = @_;

    unless (defined $json and ref $json eq 'HASH') {
      return $logger->throw ({
        type => 'broken file', format => $args{format},
        path => $path->absolute,
      });
    }
    
    for (keys %$json) {
      my $v = $json->{$_};
      unless (defined $v and ref $v eq 'HASH') {
        return $logger->throw ({
          type => 'broken file', format => $args{format},
          path => $path->absolute,
          key => $v,
        });
      }
    }

    $self->{json} = $json;
  }; # $init

  my $init_empty = sub {
    my ($self, %args) = @_;
    $self->{json} = {};
  };
  
  return $class->_open_by_app_and_path
      ($app, $list_path,
       allow_missing => $args{allow_missing}, lock => $args{lock},
       format => 'ddsd package state list',
       init => $init, init_empty => $init_empty);
} # open_by_app

sub get ($$) {
  return $_[0]->{json}->{$_[1] // ''} //= {};
} # get

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
