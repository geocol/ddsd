# -*- perl -*-
use strict;
use warnings;
use Path::Tiny;
use JSON::PS;
use Web::Encoding;
use Wanage::HTTP;
use Web::DateTime;

$Wanage::HTTP::UseXForwardedScheme = 1;

my $Files = {};
my $FilePaths = {};
my $Meta = {};
my $Accesses = {};

return sub {
  my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);

  if ($http->request_method eq 'PUT' or not $ENV{TEST_DEBUG}) {
    print STDERR ".";
  } else {
    warn sprintf "Access: [%s] %s %s\n",
        scalar gmtime, $http->request_method, $http->url->stringify;
  }
  
  $http->send_response (onready => sub {
    if ($http->request_method eq 'PUT') {
      my $u = $http->get_request_header ('content-location');

      my $def = json_bytes2perl ${ $http->request_body_as_ref };
      my $body;
      delete $FilePaths->{$u};
      $Accesses->{$u} = 0;
      if (exists $def->{json}) {
        $body = perl2json_bytes $def->{json};
      } elsif (exists $def->{jsonl}) {
        $body = join '', map { perl2json_bytes ($_) . "\x0A" } @{$def->{jsonl}};
      } elsif (exists $def->{text}) {
        $body = encode_web_utf8 $def->{text};
      } elsif (defined $def->{file}) {
        $FilePaths->{$u} = path ($def->{file});
        $body = '';
      } elsif (defined $def->{status} and $def->{status} == 304) {
        $body = '';
      } elsif (defined $def->{redirect}) {
        $body = '';
      } else {
        $http->set_status (500);
        $http->close_response_body;
        die "Bad file definition: " . perl2json_bytes_for_record $def;
      }
      $Files->{$u} = $body;
      $Meta->{$u} = $def;
      my $headers = delete $def->{headers};
      $def->{headers} = [];
      if ($def->{redirect}) {
        push @{$def->{headers}}, ['location', $def->{redirect}];
        $def->{status} ||= 302;
      }
      $def->{status} ||= 200;
      if (defined $headers) {
        for (keys %$headers) {
          push @{$def->{headers}}, [$_, $headers->{$_}];
        }
      }
      push @{$Meta->{$u}->{headers} ||= []}, ['content-type', $def->{mime}]
          if defined $def->{mime};
      push @{$Meta->{$u}->{headers} ||= []},
          ['last-modified', Web::DateTime->new_from_unix_time ($def->{last_modified})->to_http_date_string]
          if defined $def->{last_modified};
      push @{$Meta->{$u}->{headers} ||= []},
          ['date', Web::DateTime->new_from_unix_time ($def->{date})->to_http_date_string]
          if defined $def->{date};
      return $http->close_response_body;
    }

    if ($http->url->{path} eq '/COUNT') {
      $http->send_response_body_as_ref
          (\($Accesses->{$http->query_params->{url}->[0] // ''} || 0));
      return $http->close_response_body;
    }
    
    my $url = $http->url->stringify;
    if (defined $Files->{$url}) {
      my $meta = $Meta->{$url} || {};
      if (defined $meta->{if_etag}) {
        my $header = $http->get_request_header ('if-none-match') // '';
        if ($header eq $meta->{if_etag}) {
          #
        } else {
          $http->set_status (500);
          return $http->close_response_body;
        }
      }
      $http->set_status ($meta->{status});
      if (defined $meta->{etag}) {
        $http->add_response_header (etag => $meta->{etag});
      }
      for my $h (@{$meta->{headers} or []}) {
        $http->add_response_header ($h->[0], $h->[1]);
      }
      if (defined $FilePaths->{$url}) {
        $http->send_response_body_as_ref (\$FilePaths->{$url}->slurp);
      } elsif (length $Files->{$url}) {
        $http->add_response_header ('content-length', length $Files->{$url});
        $http->send_response_body_as_ref (\$Files->{$url});
      }
      $Accesses->{$url}++;
      return $http->close_response_body;
    }
    
    $http->set_status (404);
    warn "XS: URL <$url> not found";
    return $http->close_response_body;
  });
};

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
