package RepoSet;
use strict;
use warnings;
use Web::URL;

use FSStorage;

sub new_from_app_and_path ($$$) {
  my ($class, $app, $path) = @_;

  my $self = bless {
    app => $app,
  }, $class;
  $self->{storage} = FSStorage->new_from_path ($path->absolute);

  return $self;
} # new_from_path

sub app ($) { $_[0]->{app} }
sub storage ($) { $_[0]->{storage} }

sub get_repo_by_source ($$%) {
  my ($self, $source, %args) = @_;
  my $logger = $self->app->logger;

  my $el = $args{error_location} || {path => $args{path}->absolute};
  
  my $type = $source->{type} // '';
  my $bad_method = $args{allow_bad_repo_type} ? 'message' : 'throw';
  if ($type eq 'ckan') {
    require CKANRepo;
    my $url = Web::URL->parse_string ($source->{url} // '');
    if (not defined $url or not $url->is_http_s) {
      $logger->$bad_method ({
        type => 'bad source url',
        value => $source->{url} // '',
        %$el,
      });
      return undef;
    }
    return CKANRepo->new_from_set_and_url ($self, $url);
  } elsif ($type eq 'ckansite') {
    require CKANSiteRepo;
    my $url = Web::URL->parse_string ($source->{url} // '');
    if (not defined $url or not $url->is_http_s) {
      $logger->$bad_method ({
        type => 'bad source url',
        value => $source->{url} // '',
        %$el,
      });
      return undef;
    }
    return CKANSiteRepo->new_from_set_and_url ($self, $url);
  } elsif ($type eq 'packref') {
    require PackRefRepo;
    my $url = Web::URL->parse_string ($source->{url} // '');
    if (not defined $url or not $url->is_http_s) {
      $logger->$bad_method ({
        type => 'bad source url',
        value => $source->{url} // '',
        %$el,
      });
      return undef;
    }
    return PackRefRepo->new_from_set_and_url ($self, $url);
  } elsif ($type eq 'files' and $args{allow_files}) {
    return '';
  } else {
    $logger->$bad_method ({
      type => 'unknown repo type',
      value => $type,
      %$el,
    });
    return undef;
  }
} # get_repo_by_source

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
