package AddCommand;
use strict;
use warnings;
use Web::URL;
use Web::URL::Encoding;

use Command;
push our @ISA, qw(Command);

use Fetcher;
use PackageListFile;

sub run ($$;%) {
  my ($self, $input, %args) = @_;
  my $logger = $self->app->logger;

  my $url = Web::URL->parse_string ($input);
  if (not defined $url or not $url->is_http_s) {
    $logger->throw ({
      type => 'bad URL',
      value => $input,
    });
  }

  my $name;
  return $self->_pull_ddsd_data (%args)->then (sub {
    return Fetcher->fetch (
      $self->app, $url,
      sha256 => 1,
      cacert => $args{cacert},
      insecure => $args{insecure},
      sniffing => 1,
    );
  })->then (sub {
    my $r = $_[0];
    if ($r->{error}) {
      return $logger->throw ({
        type => 'failed to fetch URL',
        url => $url->stringify,
      });
    }
    
    my $def;

    if (defined $r->{json}) {
      if (ref $r->{json} eq 'HASH' and
          defined $r->{json}->{type} and
          $r->{json}->{type} eq 'packref') {
        $def = {
          type => 'packref',
          url => $url->stringify,
        };
      }

      if ($r->{url}->path =~ m{([^/]+)\z}) {
        my $n = percent_decode_c $1;
        $n =~ s/\.json\z//;
        $name = $n;
      }

    } elsif ($r->{is_html} and
             do {
               if ($r->{body_bytes} =~ m{<meta name="generator" content="(ckan[^"]+)"}) {
                 1;
               } elsif ($r->{body_bytes} =~ m{<link rel="shortcut icon" href="[^"]*/ckan.ico()"}) {
                 1;
               } else {
                 0;
               }
             }) {
      $logger->info ({
        type => 'CKAN generated page',
        value => $1,
        url => $r->{url}->stringify,
      });

      my $root_url;
      if ($r->{body_bytes} =~ m{<body data-site-root="([^"&]+)"}) {
        $root_url = $1;
        $logger->info ({
          type => 'CKAN site root URL detected',
          value => $root_url,
          url => $r->{url}->stringify,
        });
      } else {
        $logger->info ({
          type => 'CKAN site root URL missing',
          url => $r->{url}->stringify,
        });
        if ($r->{url}->path =~ m{^/(.+/)dataset/}) {
          $root_url = Web::URL->parse_string (q</>.$1, $r->{url})->stringify;
        } else {
          $root_url = Web::URL->parse_string (q</>, $r->{url})->stringify;
        }
      }

      if ($r->{url}->path =~ m{^.*/dataset/activity/([^/]+)}) {
        my $page_url = $root_url . 'dataset/' . $1;
        $def = {
          type => 'ckan',
          url => $page_url,
        };
        $name = percent_decode_c $1;
      } elsif ($r->{url}->path =~ m{^.*/(dataset/([^/]+))}) {
        my $page_url = $root_url . $1;
        $def = {
          type => 'ckan',
          url => $page_url,
        };
        $name = percent_decode_c $2;
      } else {
        $def = {
          type => 'ckansite',
          url => $root_url,
        };
        $name = $r->{url}->host->to_ascii;
      }
    } elsif ($r->{url}->get_origin->to_ascii eq 'https://search.ckan.jp') {
      if ($r->{url}->path =~ m{^/datasets/([^/]+)}) {
        $def = {
          type => 'ckan',
          url => $r->{url}->get_origin->to_ascii . '/datasets/' . $1,
        };
        $name = percent_decode_c $1;
      } else {
        $def = {
          type => 'ckansite',
          url => 'https://search.ckan.jp/',
        };
        $name = $r->{url}->host->to_ascii,
      }
    }

    unless (defined $def and defined $name) {
      return $logger->throw ({
        type => 'package type not detected',
        url => $input,
      });
    }

    $name = $args{name} if defined $args{name};
    $name = rand unless length $name;
    $name = FileNames::escape_file_name $name;
    $name = FileNames::truncate_file_name $name;
    if (defined $args{name}) {
      return $logger->throw ({
        type => 'bad data package key specified',
        value => $args{name},
      }) unless $args{name} eq $name;
    }

    my $repo = $self->app->repo_set->get_repo_by_source
        ($def, error_location => {});
    return $repo->_find_mirror ($name, $def)->then (sub {
      return $repo->fetch (
        cacert => $args{cacert},
        insecure => $args{insecure} || $def->{insecure},
        min => 1, requires_package => 1,
        has_error => sub { $self->has_error (1) },
        #file_defs
        data_area_key => $name,
      );
    })->then (sub {
      return PackageListFile->open_by_app (
        $self->app, lock => 1, allow_missing => 1,
      )->then (sub {
        my $plist = $_[0];

        my $n = $name;
        my $i = 2;
        while (defined $plist->get_def ($name)) {
          $name = $n . '-' . $i++;
          return $logger->throw ({
            type => 'conflicting data package key specified',
            value => $args{name},
          }) if defined $args{name};
        }
        my $da_repo = $self->app->data_area->get_repo ($name);
        die "Bad data package key |$name|" unless defined $da_repo;
        my $files;
        return $da_repo->construct_file_list_of (
          $repo, $def,
          skip_all => $args{min},
          init_by_default => 1, has_error => sub { },
          data_area_key => $name,
        )->then (sub {
          $files = shift;

          delete $def->{files} unless keys %{$def->{files} or {}};
          $plist->defs->{$name} = $def;
          $plist->touch;
          $logger->message ({
            type => 'data package added',
            key => $name,
          });
          $logger->count (['add_package']);

          return $plist->save;
        })->finally (sub {
          return $plist->close;
        })->then (sub {
          return $da_repo->sync ($repo, $files, data_area_key => $name)->finally (sub {
            return $da_repo->close;
          });
        });
      });
    })->finally (sub {
      return $repo->close;
    });
  })->finally (sub {
    $logger->message_counts (data_package_key => $name);
  });
} # run

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
