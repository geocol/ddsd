package Fetcher;
use strict;
use warnings;
use Promise;
use Promised::Flow;
use Web::Encoding;
use Web::Transport::BasicClient;
use Web::MIME::Type::Parser;
use Web::DateTime;
use JSON::PS;

sub fetch ($$$;%) {
  my ($class, $app, $original_url, %args) = @_;
  ## Assert: $original_url->is_http_s is true
  
  my $logger = $args{logger} // $app->logger;
  my $insecure = 0;
  my $as = $logger->start (undef, {type => 'fetch',
                                   url => $original_url->stringify});
  my $client;
  my $used_url = my $current_url = $original_url->no_fragment;

  my $error_reported;
  return Promise->resolve->then (sub {
    if (defined $args{rev} and defined $args{rev}->{sha256} and
        defined $args{file_def} and defined $args{file_def}->{sha256} and
        not $args{force_fetch}) {
      $as->info ({
        type => 'local copy with same sha256 found',
        url => $current_url->stringify,
      });
      return {not_modified => 1, url => $current_url, rev => $args{rev},
              insecure => $args{rev}->{insecure}};
    }

    my $v;
    my $redirect_count = 0;
    return Promise->resolve->then (sub {
      return promised_until {
        if ($redirect_count++ >= 20) {
          $as->message ({
            type => 'redirect loop',
            url => $current_url->stringify,
          });
          $v = {error => 1, url => $current_url, insecure => $insecure};
          return 'done';
        }

        return Promise->resolve->then (sub {
          if ($current_url->scheme eq 'https') {
            $as->info ({
              type => 'CA certificate file is specified',
              path => $args{cacert}->absolute,
            }) if $args{cacert};

            $used_url = $current_url;
            return $class->_fetch ($as, $current_url, %args, insecure => 0)->catch (sub {
              my $e = $_[0];
              if ($args{insecure}) {
                $as->message ({
                  type => 'retry with insecure transport',
                  url => $current_url->stringify,
                });
                $insecure = 1;
                return $class->_fetch ($as, $current_url, %args);
              } else {
                die $e;
              }
            });
          } elsif ($current_url->scheme eq 'http') {
            my $u = $current_url->stringify;
            $u =~ s/^http:/https:/g;
            my $https_url = Web::URL->parse_string ($u);
            $as->message ({
              type => 'upgrade to HTTPS',
              url => $current_url->stringify,
            });
            $used_url = $https_url;
            return $class->_fetch ($as, $https_url, %args, insecure => 0)->catch (sub {
              my $e = $_[0];
              $as->message ({
                type => 'fetch error',
                detail => '' . $e,
                url => $https_url->stringify,
              });
              if ($args{insecure}) {
                $as->message ({
                  type => 'retry with insecure transport',
                  url => $https_url->stringify,
                });
                $insecure = 1;
                return $class->_fetch ($as, $https_url, %args)->catch (sub {
                  my $e = $_[0];
                  $as->message ({
                    type => 'fetch error',
                    detail => '' . $e,
                    url => $https_url->stringify,
                  });
                  return {};
                });
              } else {
                return {};
              }
            })->then (sub {
              my $x = $_[0];
              return $x if $x->{ok} or $x->{not_modified} or $x->{redirect};

              if (not $args{insecure}) {
                $as->message ({
                  type => 'blocked insecure request',
                  url => $current_url->stringify,
                });
                return {error => 1, url => $current_url,
                        insecure => $insecure}; # can be false
              } else {
                $as->message ({
                  type => 'retry with insecure transport',
                  url => $current_url->stringify,
                });
                $insecure = 1;
                $used_url = $current_url;
                return $class->_fetch ($as, $current_url, %args);
              }
            });
          } else {
            die "Bad URL scheme";
          }
        })->then (sub {
          my $x = $_[0];
          if ($x->{redirect}) {
            if ($args{no_redirect}) {
              $as->message ({
                type => 'redirect not allowed',
                url => $used_url->stringify,
              });
              $x->{error} = 1;
              $v = $x;
              return 'done';
            }
            
            if (defined $x->{location}) {
              my $new_url = Web::URL->parse_string ($x->{location}, $used_url);
              if (defined $new_url and $new_url->is_http_s) {
                $as->info ({
                  type => 'retry with new URL',
                  url => $new_url->stringify,
                });
                $current_url = $new_url;
                return not 'done';
              }
            }
            
            $as->message ({
              type => 'redirect with bad location',
              url => $used_url->stringify,
              value => $x->{redirect},
            });
            $x->{error} = 1;
            $v = $x;
            return 'done';
          } else {
            $v = $x;
            return 'done';
          }
        });
      };
    })->then (sub { $v });
  })->then (sub {
    my $x = $_[0];
    $x->{insecure} = 1 if $insecure;
    return $x unless $x->{ok};
    my $res = $x->{res};
    $client = $x->{client};
    
    # XXX incomplete response

    my $cl = $res->header ('content-length') // '';
    if ($cl =~ /\A([0-9]+)\z/) {
      $as->{next}->(1, 1+$1, {url => $used_url->stringify});
    } else {
      $as->{next}->(undef, undef, {url => $used_url->stringify});
    }

    my $is_json;
    my $is_html;
    if (defined $args{mime} or $args{sniffing}) {
      my $ct = $res->header ('content-type');
      if (defined $ct) {
        my $parser = Web::MIME::Type::Parser->new;
        $parser->onerror (sub { });
        my $type = $parser->parse_string ($ct);
        if (not defined $type) {
          $is_json = 1;
          $is_html = 1;
        } else {
          my $mt = $type->mime_type_portion;
          if ($mt eq 'application/json') {
            $is_json = 1;
          } elsif ($mt eq 'text/html') {
            $is_html = 1;
          } elsif ($mt eq 'text/plain' or $mt eq 'application/octet-stream') {
              #"text/plain; charset=utf-8"
            $is_json = 1;
          }
        }
      } else {
        $is_html = 1;
        $is_json = 1;
      }
    } # need mime

    if (defined $args{mime}) {
      if ($args{mime} eq 'json') {
        unless ($is_json) {
          $res->body_stream->cancel;
          $error_reported = 1;
          return $as->throw ({
            type => 'not json mime type',
            url => $used_url->stringify,
            value => $res->header ('content-type'),
          });
        }
      } elsif ($args{mime} eq 'html') {
        unless ($is_html) {
          $res->body_stream->cancel;
          $error_reported = 1;
          return $as->throw ({
            type => 'not html mime type',
            url => $used_url->stringify,
            value => $res->header ('content-type'),
          });
        }
      } elsif ($args{mime} eq 'turtle' or $args{mime} eq 'sparql-json') {
        #
      } else {
        die "Unknown |mime| value: |$args{mime}|";
      }
    } # mime

    my $need_bytes = 0;
    if ($args{sniffing}) {
      $need_bytes = 10240 if $is_html;
      $need_bytes = 0+"Inf" if $is_json or $args{sniffing} eq 'full';
      if (not $is_html and not $is_json) {
        $res->body_stream->cancel;
        my $r = {};
        $r->{url} = $used_url;
        $r->{original_url} = $original_url;
        $r->{res} = $res;
        $r->{insecure} = 1 if $insecure;
        return $r;
      }
    }
    
    my $storage = $app->temp_storage;
    return $storage->write_by_readable (
      $res->body_stream, $as,
      sha256 => $args{sha256},
      need_body_bytes => $need_bytes,
    )->then (sub {
      my $r = $_[0];
      $r->{url} = $used_url;
      $r->{original_url} = $original_url;
      $r->{res} = $res;
      $r->{insecure} = 1 if $insecure;
      if ($args{sniffing}) {
        $r->{is_html} = 1 if $is_html;
        $r->{json} = json_bytes2perl $r->{body_bytes} if $is_json;
      }
      if (defined $args{file_def} and defined $args{file_def}->{sha256}) {
        unless ($r->{sha256} eq $args{file_def}->{sha256}) {
          $r->{sha256_mismatch} = 1;
        }
      }
      return $r;
    })->finally (sub {
      $res->body_stream->cancel;
    });
  })->catch (sub {
    my $e = $_[0];
    $as->message ({
      type => 'fetch error',
      detail => '' . $e,
      url => $used_url->stringify,
    }) unless $error_reported;
    return {error => 1, url => $used_url, insecure => $insecure};
  })->finally (sub {
    if (defined $client) {
      $client->abort;
      return $client->close;
    }
  })->then ($as->{ok}, $as->{ng});
} # fetch

sub _fetch ($$$%) {
  my ($class, $logger, $url, %args) = @_;
  
  my $headers = {};
  my $has_old = 0;
  if (defined $args{rev} and $args{rev}->{url} eq $url->stringify) {
    if (defined $args{rev}->{http_etag}) {
      $headers->{'if-none-match'} = encode_web_utf8 $args{rev}->{http_etag};
      $has_old = 1;
    } elsif (defined $args{rev}->{http_last_modified}) {
      my $dt = Web::DateTime->new_from_unix_time
          ($args{rev}->{http_last_modified});
      $headers->{'if-modified-since'} = $dt->to_http_date_string;
      $has_old = 1;
    }
  }
  if (defined $args{mime} and $args{mime} eq 'turtle') {
    $headers->{accept} = 'text/turtle';
  } elsif (defined $args{mime} and $args{mime} eq 'sparql-json') {
    $headers->{accept} = 'application/sparql-results+json';
  }
  $logger->info ({
    type => 'conditional request',
    url => $url->stringify,
  }) if $has_old;

  my $client = Web::Transport::BasicClient->new_from_url ($url, {
    tls_options => {
      ca_file => $args{cacert},
      insecure => $args{insecure},
    },
  });
  $logger->count (['http_request']);
  return $client->request (
    url => $url,
    headers => $headers,
    stream => 1,
  )->then (sub {
    my $res = $_[0];
    if ($has_old and $res->status == 304) {
      $res->body_stream->cancel;
      $logger->info ({
        type => 'remote not modified',
        url => $url->stringify,
      });
      return $client->close->catch (sub { })->then (sub {
        return {not_modified => 1, url => $url, rev => $args{rev},
                304 => 1};
      });
    } elsif ({
      301 => 1, 302 => 1, 303 => 1, 307 => 1, 308 => 1,
    }->{$res->status}) {
      $res->body_stream->cancel;
      $logger->message ({
        type => 'HTTP redirect',
        url => $url->stringify,
        status => $res->status,
        value => $res->header ('location'),
      });
      return $client->close->catch (sub { })->then (sub {
        return {redirect => 1, url => $url,
                location => $res->header ('location')};
      });
    } elsif ($res->status != 200) {
      $res->body_stream->cancel;
      $logger->message ({
        type => 'HTTP error',
        url => $url->stringify,
        status => $res->status,
      });
      return $client->close->catch (sub { })->then (sub {
        return {error => 1, url => $url};
      });
    }

    return {ok => 1, res => $res, client => $client};
  })->catch (sub {
    my $e = $_[0];
    return $client->close->finally (sub { die $e });
  });
} # _fetch

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
