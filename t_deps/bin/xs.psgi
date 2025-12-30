# -*- perl -*-
use strict;
use warnings;
use File::Temp;
use Path::Tiny;
use JSON::PS;
use Web::Encoding;
use Wanage::HTTP;
use Web::DateTime;
use Promise;
use Promised::Command;

$Wanage::HTTP::UseXForwardedScheme = 1;

my $Files = {};
my $FilePaths = {};
my $Meta = {};
my $Accesses = {};

our $temp = File::Temp->newdir (CLEANUP => ! $ENV{TEST_NO_CLEANUP});
my $TempPath = path ($temp->dirname)->absolute;
$TempPath->mkpath;

my $RootPath = path (__FILE__)->parent->parent->parent;
my $PerlPath = $RootPath->child ('perl')->absolute;
my $ZipperPath = $RootPath->child ('bin/zipper.pl');

sub create_files ($$$);

sub create_zip ($$;%) {
  my ($items, $onerror, %args) = @_;
  my $in_files = [];
  return create_files ($items, sub {
    my ($key, $def, $body, $path) = @_;
    if (not defined $path) {
      $path = $TempPath->child (rand);
      $path->spew ($body);
    }
    push @$in_files, {
      input_file_name => $path,
      file_name => $key,
      timestamp => $def->{timestamp}, # or undef
      byte_file_name => $def->{byte_file_name},
      comment => $def->{comment},
      byte_comment => $def->{byte_comment},
      is_directory => $def->{is_directory},
    };
  }, $onerror)->then (sub {
    my $cmd = Promised::Command->new ([
      $PerlPath,
      $ZipperPath,
    ]);
    my $out_path = $TempPath->child (rand);
    $cmd->stdin (\perl2json_bytes {
      command => 'create',
      files => $in_files,
      output_file_name => $out_path->absolute,
      comment => $args{comment},
      byte_comment => $args{byte_comment},
    });
    $cmd->stdout (\my $stdout);
    return $cmd->run->then (sub {
      return $cmd->wait;
    })->then (sub {
      my $result = $_[0];
      warn $stdout if $ENV{TEST_DEBUG} || $ENV{TEST_PREPARE_DEBUG};
      die $result unless $result->exit_code == 0;
      return $out_path;
    });
  });
} # create_zip

sub create_files ($$$) {
  my ($items, $code, $onerror) = @_;
  my $pp = [];
  for my $key (keys %$items) {
    my $def = $items->{$key};
    my $body;
    my $path;
    if (exists $def->{json}) {
      $body = perl2json_bytes $def->{json};
    } elsif (exists $def->{jsonl}) {
      $body = join '', map { perl2json_bytes ($_) . "\x0A" } @{$def->{jsonl}};
    } elsif (exists $def->{text}) {
      $body = encode_web_utf8 $def->{text};
    } elsif (exists $def->{bytes}) {
      $body = $def->{bytes};
      utf8::downgrade ($body) if utf8::is_utf8 ($body);
    } elsif (defined $def->{file}) {
      $path = path ($def->{file});
      $body = '';
    } elsif (exists $def->{zip}) {
      $def->{mime} //= 'application/zip';
      push @$pp, create_zip ($def->{zip}, $onerror,
        comment => $def->{comment},
        byte_comment => $def->{byte_comment},
      )->then (sub {
        $code->($key, $def, '', $_[0]);
      });
      next;
    } elsif (defined $def->{status} and $def->{status} == 304) {
      $body = '';
    } elsif (defined $def->{redirect}) {
      $body = '';
    } elsif ($def->{is_directory}) {
      $path = $TempPath->child (rand);
      $path->mkpath;
      $body = '';
    } else {
      $onerror->($def);
      next;
    }
    $code->($key, $def, $body, $path);
  } # $json
  return Promise->all ($pp);
} # create_files

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
      my $json = json_bytes2perl ${ $http->request_body_as_ref };
      return create_files ($json, sub {
        my ($key, $def, $body, $path) = @_;
        my $u = Web::URL->parse_string ($key)->stringify;
        delete $FilePaths->{$u};
        $FilePaths->{$u} = $path if defined $path;
        $Accesses->{$u} = 0;
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
            ['last-modified', Web::DateTime->new_from_unix_time ($def->{last_modified} // $def->{timestamp})->to_http_date_string]
            if defined $def->{last_modified} or defined $def->{timestamp};
        push @{$Meta->{$u}->{headers} ||= []},
            ['date', Web::DateTime->new_from_unix_time ($def->{date})->to_http_date_string]
            if defined $def->{date};
      }, sub {
        my $def = $_[0];
        $http->set_status (500);
        $http->close_response_body;
        die "Bad file definition: " . perl2json_bytes_for_record $def;
      })->then (sub {
        return $http->close_response_body;
      });
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
        $meta->{etag} = qq{"$meta->{etag}"} unless $meta->{etag} =~ /^"/;
        $http->add_response_header (etag => $meta->{etag});
      }
      for my $h (@{$meta->{headers} or []}) {
        $http->add_response_header ($h->[0], $h->[1]);
      }
      if ($meta->{status} == 304 or $meta->{status} == 204) {
        #
      } elsif (defined $FilePaths->{$url}) {
        $http->send_response_body_as_ref (\$FilePaths->{$url}->slurp);
      } elsif (length $Files->{$url}) {
        $http->send_response_body_as_ref (\$Files->{$url});
      }
      $Accesses->{$url}++;
      if ($Meta->{$url}->{incomplete}) {
        sleep 3;
        die "incomplete response";
      } else {
        return $http->close_response_body;
      }
    }
    
    $http->set_status (404);
    warn "$$: XS: URL <$url> not found";
    return $http->close_response_body;
  });
};

=head1 LICENSE

Copyright 2024-2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
