package CKANPackage;
use strict;
use warnings;
use Promised::File;
use JSON::PS;

sub open_api_response_by_app_and_path ($$$;%) {
  my ($class, $app, $path, %args) = @_;

  my $self = bless {app => $app}, $class;
  my $logger = $app->logger;
  $self->{error_location} = {
    (defined $args{url} ? (url => $args{url}->stringify) : ()),
    path => $path->absolute,
  };
  
  $logger->info ({
    type => 'open file', format => 'CKAN package',
    %{$self->{error_location}},
  });
  my $file = Promised::File->new_from_path ($path);
  return $file->read_byte_string->then (sub {
    my $json = json_bytes2perl $_[0];
    if (defined $json and ref $json eq 'HASH' and
        $json->{success} and
        defined $json->{result} and
        ref $json->{result} eq 'HASH') {
      $self->{package} = $json->{result};
      $logger->info ({
        type => 'loaded file', format => 'CKAN package',
        %{$self->{error_location}},
      });
      return $self;
    } else {
      $logger->message ({
        type => 'broken file', format => 'CKAN package',
        (defined $args{url} ? (url => $args{url}->stringify) : ()),
        %{$self->{error_location}},
      });
      return undef;
    }
  });
} # open_api_response_by_app_and_path

sub app ($) { $_[0]->{app} }

sub get_package ($) { $_[0]->{package} }

sub get_resources ($) {
  my $self = $_[0];

  my $items = [];
  my $logger = $self->app->logger;

  my $ds = $self->{package};
  if (defined $ds->{resources} and ref $ds->{resources} eq 'ARRAY') {
    $items = [grep {
      if (defined $_ and ref $_ eq 'HASH') {
        1;
      } else {
        $logger->info ({
          type => 'broken file', format => 'CKAN package',
          error_message => '|resources| has an item that is not a JSON object',
          %{$self->{error_location}},
        });
        0;
      }
    } @{$ds->{resources}}];
  } else {
    $logger->info ({
      type => 'broken file', format => 'CKAN package',
      error_message => '|resources| is not a JSON array',
      %{$self->{error_location}},
    });
  }

  return $items;
} # get_resources

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
