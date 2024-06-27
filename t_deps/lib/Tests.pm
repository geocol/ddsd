package Tests;
use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('modules/*/lib');
use Carp;
use Time::HiRes qw(time);
use Promise;
use Web::Encoding;
use Web::URL;
use Web::URL::Encoding;
use Web::DateTime;
use JSON::PS;
use Web::Transport::FindPort;
use Test::More;
use Test::X1;
use POSIX;
use AbortController;
use ServerSet;

use Tests::Current;

my $RootPath = path (__FILE__)->parent->parent->parent;

our @EXPORT;
push @EXPORT,
    qw(time),
    @Web::Encoding::EXPORT,
    @Web::URL::Encoding::EXPORT,
    @JSON::PS::EXPORT,
    'test',
    (grep { not /\$/ } @Test::More::EXPORT);

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  no strict 'refs';
  for (@_ ? @_ : @{$from_class . '::EXPORT'}) {
    my $code = $from_class->can ($_)
        or croak qq{"$_" is not exported by the $from_class module at $file line $line};
    *{$to_class . '::' . $_} = $code;
  }
} # import

push @EXPORT, qw(ckan_timestamp);
sub ckan_timestamp ($) {
  return Web::DateTime->new_from_unix_time ($_[0])->to_local_date_and_time_string;
} # ckan_timestamp

my $CurrentOptions = {};

push @EXPORT, qw(Test);
sub Test (&;%) {
  my $code = shift;
  my %args = @_;
  test {
    my $current = Tests::Current->new (shift, $RootPath, $CurrentOptions);
    return Promise->resolve ($current)->then ($code)->catch (sub {
      my $e = shift;
      test {
        is 0, "no exception", $e;
      } $current->c;
    })->finally (sub {
      return $current->close;
    })->finally (sub {
      $current->c->done;
    });
  } timeout => 60*5, %args;
} # Test

sub serverset (@) {

  my $https_hosts = [qw(
    foo.test hoge search.ckan.jp hoge.xn--4gq data.bodik.jp
    gist.githubusercontent.com
    1.hoge 2.hoge 3.hoge 4.hoge 5.hoge 6.hoge 7.hoge 8.hoge 9.hoge
  )];
  my $remote_hosts = [qw(
    hoge.test www.test badserver.test hoge.badserver.test foo fo noserver.test
    raw.githubusercontent.com
  )];
  
  return ServerSet->run ({
    proxy => {
      handler => 'ServerSet::ReverseProxyHandler',
      prepare => sub {
        my ($handler, $self, $args, $data) = @_;

        for my $h (@$https_hosts) {
          $self->set_proxy_alias ($h => "xs.server.test");
        }

        return {
          client_urls => [map { Web::URL->parse_string (qq<https://$_/>) } @$https_hosts],
        };
      }, # prepare
    }, # proxy
    xs => {
      handler => 'ServerSet::SarzeHandler',
      prepare => sub {
        my ($handler, $self, $args, $data) = @_;
        return {
          hostports => [
            [$self->local_url ('xs')->host->to_ascii,
             $self->local_url ('xs')->port],
          ],
          psgi_file_name => $RootPath->child ('t_deps/bin/xs.psgi'),
          max_worker_count => 1,
          #debug => 2,
        };
      }, # prepare
    }, # xs
    _ => {
      requires => ['xs', 'proxy'],
      start => sub {
        my ($handler, $self, %args) = @_;
        my $data = {};

        $data->{app_client_url} = $self->client_url ('app');
        $self->set_local_envs ('proxy', $data->{local_envs} = {});
        $data->{local_envs}->{https_proxy} = $self->local_url ('proxy')->stringify;
        $data->{local_envs}->{no_proxy} = join ',', @$remote_hosts;

        return $args{receive_proxy_data}->then (sub {
          my $proxy_data = $_[0];
          
          $data->{ca_cert_path} = $proxy_data->{ca_cert_path};
          
          return [$data, undef];
        });
      },
    }, # _
  }, sub {
    my ($ss, $args) = @_;
    my $result = {};

    $result->{exposed} = {
      proxy => [$args->{proxy_host}, $args->{proxy_port}],
    };


    $result->{server_params} = {
      proxy => {
      },
      xs => {
      },
      _ => {},
    }; # $result->{server_params}

    return $result;
  }, @_);
} # serverset

push @EXPORT, qw(Run);
sub Run () {
  if ($> == 0) {
    POSIX::setuid (60000); # for permission tests
  }
  
  my $ac = AbortController->new;
  my $v = serverset (
    signal => $ac->signal,
  )->to_cv->recv;
  $CurrentOptions->{client_envs} = $v->{data}->{local_envs};
  $CurrentOptions->{ca_cert_path} = $v->{data}->{ca_cert_path};

  Test::X1::run_tests;

  $ac->abort;
  $v->{done}->to_cv->recv;
} # Run

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
