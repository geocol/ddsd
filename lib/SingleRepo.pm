package SingleRepo;
use strict;
use warnings;
use Time::HiRes qw(time);
use Web::URL;
use Promised::Flow;
use Promised::File;
use JSON::PS;

use Repo;
push our @ISA, qw(Repo);

use PackRef;

sub new_from_set_and_url ($$$) {
  my ($class, $set, $url) = @_;

  my $self = bless {
    set => $set,
    url => $url,
  }, $class;

  my $u = $url->stringify;
  $u =~ s{#.*}{}s; # XXX
  $self->_set_key ($u);

  return $self;
} # new_from_set_and_url

sub type () { "single" }

sub fetch ($;%) {
  my ($self, %args) = @_;
  my $logger = $args{logger} // $self->set->app->logger;
  my $file_defs = $args{file_defs} || {};
  my $package_item_key;
  my $ret = {has_package => 1};
  return $self->_fetch_file (
    $self->{url}, $file_defs->{file},
    %args,
    set_repo_type => 1,
    skip_if_found => $args{no_update},
    check_is_new_insecure => $args{is_special_repo},
    logger => $logger,
  )->then (sub {
    my $r = $_[0];
    $package_item_key = $r->{key}; # or undef
    $ret->{insecure} = 1 if $r->{insecure};
    if ($r->{error}) {
      $ret->{broken} = 1;
      $args{has_error}->();
      $logger->count (['fetch_failure']);
      return;
    } elsif ($r->{not_modified}) {
      if ($r->{is_new}) {
        $ret->{timestamp} = $r->{is_new};
        $ret->{insecure} = 1 if $r->{is_new_insecure};
        $ret->{not_modified} = 1;
        $ret->{_skip} = 1;
        if ($r->{is_new_broken}) {
          $args{has_error}->();
          $ret->{broken} = 1;
          return;
        }
        return;
      } else {
        #
      }
    } else {
      $ret->{has_modified} = 1;
    }
  })->then (sub {
    return if $ret->{_skip};
    return $self->_fetch_post_legal (
      %args,
      has_error => sub {
        $args{has_error}->();
        $ret->{broken} = 1;
      },
      dest_item_key => $package_item_key,
      site_legal_key_url => $self->{url},
      logger => $logger,
    );
  })->then (sub {
    return $ret;
  });
} # fetch

sub get_item_list ($;%) {
  my ($self, %args) = @_;
  my $logger = $self->set->app->logger;
  my $file_defs = $args{file_defs} || {};
  my $files = [];

  my $pack_file = {
    type => 'package',
    key => 'package',
    package_item => {
      title => '', desc => '', author => '', org => '',
      lang => '',
      dir => 'auto',
      writing_mode => 'horizontal-tb',
    },
  };
  
  return $self->read_index->then (sub {
    my $in = $_[0];
    my (undef, $item) = $in->get_item
        (url_string => $self->{url}->stringify, file_def => undef);

    return Promise->all ([
      (($args{with_props} and defined $item->{files}->{log}) ? Promised::File->new_from_path ($self->storage->{path}->child ($item->{files}->{log}))->read_byte_string : undef),
    ])->then (sub {
      my ($log_bytes) = @{$_[0]};

      if ($args{with_props}) {
        $pack_file->{package_item}->{legal} = [];
        if (defined $log_bytes) {
          $self->_parse_log_legal
              ($log_bytes => $pack_file->{package_item}->{legal});
        } # $log_bytes
      } # props

      {
        my $file_key = 'file';
        my $fdef = $file_defs->{$file_key};

        my $file = {key => $file_key};
        $file->{type} = 'file';
        my $skipped;
        if (defined $fdef and $fdef->{skip}) {
          $skipped = 1;
          if ($args{with_skipped}) {
            #
          } else {
            $logger->info ({
              type => 'item ignored by skip',
              value => $file->{key},
              path => $in->path->absolute,
            });
            next;
          }
        } # skip

        my $url = $self->{url};
        $file->{source}->{url} = $url->stringify
            if ($args{with_source_meta} or
                ($file->{type} eq 'dataset' and $file->{set_type} eq 'sparql')) and
                    defined $url;
        $self->_set_item_file_info ([url_string => $url->stringify],
                                    $fdef, $in, $file, %args)
            unless $skipped; # XXX tests for skipped

        if (defined $file->{package_item}->{file_time}) {
          $pack_file->{package_item}->{file_time} //= $file->{package_item}->{file_time};
          $pack_file->{package_item}->{file_time} = $file->{package_item}->{file_time}
              if $pack_file->{package_item}->{file_time} < $file->{package_item}->{file_time};
        }

        push @$files, $file;

        if ($file->{type} eq 'dataset') {
          $self->_expand_dataset
              ($file, $file_defs, $in => $pack_file, $files, $logger, %args);
        } # dataset
      } # file
    });
  })->then (sub {
    if ($args{with_props} or $args{with_snapshot_hash}) {
      unshift @$files, $pack_file
          unless @$files and $files->[0]->{type} eq 'package';
      if ($args{with_snapshot_hash}) {
        $self->_set_snapshot_hash ($files);
      }

      $pack_file->{package_item}->{file_time} //= time;
    } # with_props
  })->then (sub {
    return $files;
  });
} # get_item_list

sub _get_item_by_key ($$$) {
  my ($self, $ix, $item_key) = @_;
  if ($item_key eq 'file') {
    my (undef, $item) = $ix->get_item
        (url_string => $self->{url}->stringify, file_def => undef);
    return $item; # or undef
  }
  return undef;
} # _get_item_by_key

1;

=head1 LICENSE

Copyright 2024-2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
