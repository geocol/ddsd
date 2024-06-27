package CKANSiteRepo;
use strict;
use warnings;
use Web::URL;
use Web::Encoding;
use Promise;
use Promised::Flow;
use Promised::File;

use Repo;
push our @ISA, qw(Repo);

sub new_from_set_and_url ($$$) {
  my ($class, $set, $url) = @_;

  my $self = bless {
    set => $set,
    url => $url,
  }, $class;

  if ($url->stringify eq 'https://search.ckan.jp/') {
    $self->{api_url} = Web::URL->parse_string
        ('https://search.ckan.jp/backend/api/package_list');
  } else {
    $self->{api_url} = Web::URL->parse_string
        ('api/action/package_list', $self->{url});
  }
  $self->_set_key ($url->stringify);

  return $self;
} # new_from_set_and_url

sub type () { "ckansite" }

sub fetch ($;%) {
  my ($self, %args) = @_;
  my $logger = $args{logger} // $self->set->app->logger;
  my $file_defs = $args{file_defs} || {};
  my $package_item_key;
  my $ret = {};
  $ret->{has_package} = 1; # no package for this repo
    my $as;
    return $self->get_item_list (
      with_source_meta => 1, file_defs => $file_defs,
      has_error => $args{has_error},
      skip_other_files => $args{skip_other_files},
      requires_package => 1,
      requires_legal => 1,
      with_skipped => defined $args{file_key},
      skip_if_found => $args{no_update},
      with_item_key => 1,
      data_area_key => $args{data_area_key},
    )->then (sub {
      my $all_files = shift;
      my $files = [];
      if (defined $args{only}) {
        if ($args{only} eq 'package') {
          return;
        } else {
          for my $file (@$all_files) {
            if ($file->{key} eq $args{only}) {
              push @$files, $file;
              last;
            }
          }
        }
      } else {
        push @$files, @$all_files;
      }

      $as = $logger->start (0+@$files, {
        type => 'pull package files',
        all_count => 0+@$all_files,
        selected_count => 0+@$files,
      });
      return promised_for {
        my $file = shift;
        $as->{next}->(undef, undef, {key => $file->{key}, url => $file->{source}->{url}});
        return if $file->{type} eq 'package';

        my $url = $file->{source}->{url};
        if (not defined $url or not $url->is_http_s) {
          $args{has_error}->();
          $as->message ({
            type => 'bad URL',
            value => $file->{source}->{url},
            file => $file,
          });
          return;
        }

        # XXXX skip vs legal
        return $self->_fetch_file (
          $url, $file_defs->{$file->{key}},
          %args,
          mime => $file->{source}->{mime},
          has_error => $args{has_error},
          index_seen => 1, rev => $file->{rev}, item_key => $file->{item_key},
          set_repo_type => 1,
          skip_if_found => $args{no_update},
          skip_if_new => $args{is_special_repo},
          fetch_log => $args{is_special_repo} ? {} : undef,
          logger => $as,
        )->then (sub {
          my $r = $_[0];
          $package_item_key = $r->{key} if $file->{key} eq 'file:index.html';
          $ret->{insecure} = 1 if $r->{insecure};
          if ($r->{error}) {
            $args{has_error}->();
          }
        });
      } $files;
  })->then ($as->{ok}, $as->{ng})->then (sub {
    return if $ret->{_skip};
    return if not defined $package_item_key;
    return if $self->{mirror_url};
    return $self->_fetch_post_legal (
      %args,
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
  my $storage_path = $self->storage->{path};
  my $file_defs = $args{file_defs} || {};
  my $files = [];
  my $fs = {};
  return $self->read_index->then (sub {
    my $in = $_[0];

    my $with_package = $args{with_props} || $args{requires_legal};
    if ($with_package) {
      push @$files, {
        type => 'package',
        key => 'package',
        package_item => {
          title => '',
          lang => '',
          dir => 'auto',
          writing_mode => 'horizontal-tb',
        },
      };
    } # with_props

    my $items = {};
    for (
      ['file:index.html', $self->{url}, 'text/html', 'index.html'],
      ['file:about.html', Web::URL->parse_string ('about', $self->{url}),
       'text/html', 'about.html'],
      ['file:package_list.json', $self->{api_url},
       'application/json', 'package_list.json'],
    ) {
      my ($file_key, $url, $mime, $name) = @$_;
      my $file = {
        type => 'file',
        key => $file_key,
        package_item => {
          mime => $mime,
          title => '',
        },
        file => {
          directory => 'files',
          name => $name,
        },
      };
      push @$files, $file;
      $fs->{$file_key} = $file;
      if ($args{with_source_meta}) {
        $file->{source}->{url} = $url;
      }
      my $item = $self->_set_item_file_info
          ($url, $file_defs->{$file_key}, $in, $file, %args);
      $items->{$file_key} = $item; # or undef
    } # for

    return Promise->all ([
      (($with_package and defined $items->{'file:index.html'} and defined $items->{'file:index.html'}->{files}->{data}) ? Promised::File->new_from_path ($self->storage->{path}->child ($items->{'file:index.html'}->{files}->{data}))->read_byte_string : undef),
      (($with_package and defined $items->{'file:about.html'} and defined $items->{'file:about.html'}->{files}->{data}) ? Promised::File->new_from_path ($self->storage->{path}->child ($items->{'file:about.html'}->{files}->{data}))->read_byte_string : undef),
      (($with_package and defined $items->{'file:index.html'}->{files}->{log}) ? Promised::File->new_from_path ($self->storage->{path}->child ($items->{'file:index.html'}->{files}->{log}))->read_byte_string : undef),
    ]);
  })->then (sub {
    my ($index_bytes, $about_bytes, $log_bytes) = @{$_[0]};

    my $pi = $files->[0]->{package_item};
    if (defined $about_bytes) {
      if ($about_bytes =~ m{<html lang="([^"&]+)">}) {
        $pi->{lang} = $1;
        $pi->{lang} =~ tr/A-Z_/a-z-/;
      }
      if ($about_bytes =~ m{<link rel="stylesheet"[^<>]*href="[^"]+main(-rtl|)\.(?:min\.|)css"\s*/>}) {
        $pi->{dir} = $1 ? 'rtl' : 'ltr';
      } elsif ($about_bytes =~ m{<link[^<>]*href="[^"]+main(-rtl|)\.(?:min\.|)css"\s*rel="stylesheet"\s*/>}) {
        $pi->{dir} = $1 ? 'rtl' : 'ltr';
      }
    } # about_bytes

    if (defined $index_bytes) {
      if ($index_bytes =~ m{<title>([^<&]+)</title>}) {
        $pi->{title} = decode_web_utf8 $1;
        $pi->{title} =~ s/^\s+//;
        $pi->{title} =~ s/\s+$//;
      }

      my $base_url = Web::URL->parse_string
          ($fs->{'file:index.html'}->{rev}->{url});
      my $url = $self->_sniff_terms_url_in_html ($index_bytes, $base_url);
      $fs->{'file:index.html'}->{parsed}->{site_terms_url} = $url
          if defined $url;
    } # index_bytes

    $pi->{legal} = [];
    if (defined $log_bytes) {
      $self->_parse_log_legal ($log_bytes => $pi->{legal});
    } # $log_bytes

    if ($args{with_props} and $args{with_snapshot_hash}) {
      if (@$files and $files->[0]->{type} eq 'package') { # XXX never
        $self->_set_snapshot_hash ($files);
      }
    } # with_snapshot_hash

    return $files;
  });
} # get_item_list

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
