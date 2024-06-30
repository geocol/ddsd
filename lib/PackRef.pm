package PackRef;
use strict;
use warnings;
use Promised::File;
use JSON::PS;

sub open_by_app_and_path ($$$;%) {
  my ($class, $app, $path, %args) = @_;

  my $self = bless {app => $app}, $class;
  my $logger = $app->logger;
  $self->{error_location} = {
    (defined $args{url} ? (url => $args{url}->stringify) : ()),
    path => $path->absolute,
  };
  
  $logger->info ({
    type => 'open file', format => 'packref',
    %{$self->{error_location}},
  });
  my $file = Promised::File->new_from_path ($path);
  return $file->read_byte_string->then (sub {
    my $json = json_bytes2perl $_[0];
    if (defined $json and ref $json eq 'HASH' and
        defined $json->{type} and $json->{type} eq 'packref') {
      $json->{meta} //= {};
      unless (ref $json->{meta} eq 'HASH') {
        $logger->message ({
          type => 'broken file', format => 'packref',
          key => 'meta',
          (defined $args{url} ? (url => $args{url}->stringify) : ()),
          %{$self->{error_location}},
        });
        return undef;
      }
      
      $self->{package} = $json;
      $logger->info ({
        type => 'loaded file', format => 'packref',
        %{$self->{error_location}},
      });
      return $self;
    } else {
      $logger->message ({
        type => 'broken file', format => 'packref',
        (defined $args{url} ? (url => $args{url}->stringify) : ()),
        %{$self->{error_location}},
      });
      return undef;
    }
  });
} # open_by_app_and_path

sub app ($) { $_[0]->{app} }

sub get_package ($) { $_[0]->{package} }

sub get_file_defs ($$) {
  my ($self, $file_defs) = @_;

  my $source = $self->{package}->{source};
  return $file_defs unless defined $source and ref $source eq 'HASH';
  
  return $file_defs unless defined $source->{files} and ref $source->{files} eq 'HASH';

  my $fdefs = {};
  my %file = (%$file_defs, %{$source->{files}});
  for my $key (keys %file) {
    my $fdef1 = $file_defs->{$key} || {};
    my $fdef2 = $source->{files}->{$key} || {};
    next unless ref $fdef2 eq 'HASH';
    my $fdef3 = {};
    if (defined $fdef1->{skip} or defined $fdef2->{skip}) {
      $fdef3->{skip} = $fdef1->{skip} // $fdef2->{skip};
    }
    $fdef3->{name} = $fdef1->{name} // $fdef2->{name}; # or undef
    $fdef3->{url} = $fdef1->{url} // $fdef2->{url}; # or undef
    $fdef3->{set_type} = $fdef1->{set_type} // $fdef2->{set_type}; # or undef
    if (defined $fdef1->{sha256} and defined $fdef2->{sha256}) {
        if ($fdef1->{sha256} eq $fdef2->{sha256}) {
          $fdef3->{sha256} = $fdef1->{sha256};
          $fdef3->{sha256_insecure} = 1
              if $fdef1->{sha256_insecure} and $fdef2->{sha256_insecure};
        } else {
          if ($fdef1->{sha256_insecure}) {
            $fdef3->{sha256} = $fdef2->{sha256};
          } elsif ($fdef2->{sha256_insecure}) {
            $fdef3->{sha256} = $fdef1->{sha256};
          } else {
            $fdef3->{sha256} = 'CONFLICT';
          }
        }
      } elsif (defined $fdef1->{sha256}) {
        $fdef3->{sha256} = $fdef1->{sha256};
        $fdef3->{sha256_insecure} = 1 if $fdef1->{sha256_insecure};
      } elsif (defined $fdef2->{sha256}) {
        $fdef3->{sha256} = $fdef2->{sha256};
        $fdef3->{sha256_insecure} = 1 if $fdef2->{sha256_insecure};
      }
      $fdefs->{$key} = $fdef3;
    }

  return $fdefs;
} # get_file_defs

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
