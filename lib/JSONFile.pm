package JSONFile;
use strict;
use warnings;
use JSON::PS;
use AbortController;
use Promise;
use Promised::File;

sub _open_by_app_and_path ($$$;%) {
  my ($class, $app, $path, %args) = @_;

  my $self = bless {
    app => $app, path => $path,
    done => Promise->resolve,
    format => $args{format},
  }, $class;
  my $logger = $app->logger;

  $logger->info ({
    type => 'open file', format => $args{format},
    path => $path->absolute,
  });
  my $file = $self->{file} = Promised::File->new_from_path ($path);
  return Promise->resolve->then (sub {
    return unless $args{lock};

    if (not $args{allow_missing}) {
      my $parent_path = $path->parent;
      my $parent_file = Promised::File->new_from_path ($parent_path);
      return $parent_file->is_directory->then (sub {
        if ($_[0]) {
          return 1;
        } else {
          return $logger->throw ({
            type => 'failed to open file', format => $args{format},
            path => $path->absolute,
            _ => 1,
          });
        }
      });
    }
  })->then (sub {
    return unless $args{lock};

    $self->{lock} = AbortController->new;
    $logger->info ({
      type => 'lock file', format => $args{format},
      path => $path->absolute,
    });
    return $file->lock_new_file (
      signal => $self->{lock}->signal,
      timeout => 10,
    );
  })->then (sub {
    return $file->stat;
  })->then (sub {
    if (-f $_[0]) { # found
      return $file->read_byte_string->then (sub {
        my $json = ($_[0] eq '') ? {} : json_bytes2perl $_[0];
        my $empty = ($args{allow_missing} and $_[0] eq '');
        return Promise->resolve->then (sub {
          if ($empty) {
            return $args{init_empty}->($self, format => $args{format});
          } else {
            return $args{init}->($self, $logger, $path, $json,
                                 format => $args{format});
          }
        })->then (sub {
          $logger->info ({
            type => 'loaded file', format => 'package list',
            path => $path->absolute,
            package_count => 0+keys %$json,
          });
        });
      });
    } else { # not a file
      if ($args{allow_missing} and not -e $_[0]) {
        return $args{init_empty}->($self, format => $args{format});
      } else {
        $logger->throw ({
          type => 'failed to open file', format => $args{format},
          path => $path->absolute,
          _ => 2,
        });
      }
    }
  }, sub { # no container directory or permission error
    my $e = $_[0];
    if ($args{allow_missing}) {
      return $args{init_empty}->($self, format => $args{format});
    }
    my $parent_path = $path->parent;
    my $parent_file = Promised::File->new_from_path ($parent_path);
    return $parent_file->is_directory->then (sub {
      if ($_[0]) {
        ## e.g. |config/dsdd| is a directory but
        ## |config/dsdd/packages.json| is unreadable.
        $logger->throw ({
          type => 'failed to open file', format => $args{format},
          path => $path->absolute,
          error_message => '' . $e,
          _ => 3,
        });
      } else {
        my $gparent_path = $parent_path->parent;
        my $gparent_file = Promised::File->new_from_path ($gparent_path);
        return $gparent_file->is_directory->then (sub {
          if ($_[0]) {
            ## e.g. |config| is a directory but |config/dsdd| is unreadable.
            $logger->throw ({
              type => 'failed to open file', format => $args{format},
              path => $path->absolute,
              error_message => '' . $e,
              _ => 4,
              __ => $gparent_path->absolute,
            });
          } else {
            if ($args{allow_missing}) {
              return $args{init_empty}->($self, format => $args{format});
            } else {
              return $logger->throw ({
                type => 'failed to open file', format => $args{format},
                path => $path->absolute,
                error_message => '' . $e,
                _ => 5,
              });
            }
          }
        });
      }
    });
  })->then (sub {
    return $self;
  });
} # _open_by_app_and_path

sub app ($) { $_[0]->{app} } 
sub path ($) { $_[0]->{path} }

sub touch ($) { $_[0]->{touched} = 1 }

sub save ($;%) {
  my ($self, %args) = @_;
  die "The file is not locked" unless defined $self->{lock};
  return Promise->resolve unless $_[0]->{touched};

  $self->app->logger->info ({
    type => 'save file', format => $self->{format},
    path => $self->path->absolute,
  });
  return $self->{done} = $self->{done}->then (sub {
    return $self->{file}->write_byte_string
        (perl2json_bytes_for_record $self->{json});
  })->then (sub {
    return $self->{file}->chmod (0444) if $args{readonly};
  });
} # save

sub close ($) {
  my $self = $_[0];
  return $self->{done}->then (sub {
    $self->{lock}->abort if defined $self->{lock};
  });
} # close

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
