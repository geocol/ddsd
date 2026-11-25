package FilteredRepo;
use strict;
use warnings;
use Carp;
use Digest::SHA qw(sha256_hex);
use Promise;
use Promised::Flow;
use Promised::File;
use Web::Encoding;
use Web::MIME::Type::Parser;

use Repo;
push our @ISA, qw(Repo);

sub new_from_upstream ($$$;%) {
  my ($class, $upstream_repo, $upstream_args, %args) = @_;

  my $uargs = { %{$upstream_args || {}} };
  my $inferred;
  if (not defined $uargs->{url} and not defined $uargs->{path_string}) {
    if ($upstream_repo->type eq 'single' and defined $upstream_repo->{url}) {
      $uargs->{url} = $upstream_repo->{url};
      $inferred = 1;
    }
  }

  my $self = bless {
    set => $upstream_repo->set,
    upstream_repo => $upstream_repo,
    upstream_args => $uargs,
    inferred_upstream => $inferred,
    filter => $args{filter},
    upstream_file_key => $args{upstream_file_key} // 'file',
  }, $class;
  my $upkey = '';
  $upkey = $self->{upstream_args}->{url}->stringify if defined $self->{upstream_args}->{url};
  $upkey = $self->{upstream_args}->{path_string} if defined $self->{upstream_args}->{path_string};
  $self->_set_key (join $;, 'filtered', $self->{filter}//'', $self->{upstream_file_key}//'', $upkey, join $;, @{$self->{upstream_repo}->{key} || []});

  return $self;
}

sub type ($) { "filtered" }
sub is_nested ($) { 1 }

sub _upstream_mirror_def ($) {
  my $self = $_[0];
  return {
    type => $self->{upstream_repo}->type,
    (defined $self->{upstream_args}->{url} ? (url => $self->{upstream_args}->{url}->stringify) : ()),
  };
}

sub _find_mirror ($$$) {
  my ($self, $key, $def) = @_;
  my $updef = $self->_upstream_mirror_def;
  return $self->{upstream_repo}->_find_mirror ($key, $updef)->then (sub {
    return $self->SUPER::_find_mirror ($key, $def);
  });
}

sub _use_mirror ($$$) {
  my ($self, $key, $def) = @_;
  my $updef = $self->_upstream_mirror_def;
  return $self->{upstream_repo}->_use_mirror ($key, $updef)->then (sub {
    return $self->SUPER::_use_mirror ($key, $def);
  });
}

sub read_index ($) {
  my $self = $_[0];
  return $self->{upstream_repo}->read_index->then (sub {
    my $upix = $_[0];
    # try to get upstream item if upstream_args specify url/path
    if (!$self->{inferred_upstream} and (defined $self->{upstream_args}->{url} or defined $self->{upstream_args}->{path_string})) {
      my $upitem = $self->{upstream_repo}->_get_item
          ($upix, $self->{upstream_args});
      if (not defined $upitem and defined $self->{upstream_args}->{url}) {
        eval {
          (undef, $upitem) = $upix->get_item (url_string => $self->{upstream_args}->{url}->stringify, file_def => undef);
        };
      }
      if (not defined $upitem) {
        return $self->SUPER::read_index;
      }
      my $storage = $upix->get_storage_of
          ($upitem, "filtered-" . $self->type, allow_missing => 1,
           nested => $self->{upstream_repo}->is_nested);
      unless (defined $storage) {
        return $self->SUPER::read_index (
          upstream_index => $upix,
          upstream_item => $upitem,
        );
      }
      return RepoIndexFile->open_by_app_and_storage (
        $self->set->app, $storage, allow_missing => 1,
        upstream_index => $upix,
        upstream_item => $upitem,
        path_index_key => (join "-", @{$self->{key}}),
      );
    } else {
      # no upstream item pointer; still allow nested storage under upstream context not directly
      return $self->SUPER::read_index (upstream_index => $upix);
    }
  });
}

sub lock_index ($) {
  my $self = $_[0];
  return $self->{upstream_repo}->lock_index->then (sub {
    my $upix = $_[0];
    if (!$self->{inferred_upstream} and (defined $self->{upstream_args}->{url} or defined $self->{upstream_args}->{path_string})) {
      my $upitem = $self->{upstream_repo}->_get_item
          ($upix, $self->{upstream_args});
      if (not defined $upitem and defined $self->{upstream_args}->{url}) {
        eval {
          (undef, $upitem) = $upix->get_item (url_string => $self->{upstream_args}->{url}->stringify, file_def => undef);
        };
      }
      if (not defined $upitem) {
        return $upix->close->then (sub {
          return $self->SUPER::lock_index;
        });
      }
      my $storage = $upix->get_storage_of
          ($upitem, "filtered-" . $self->type, prefix => 'filtered-',
           create_if_missing => 1, nested => $self->{upstream_repo}->is_nested);
      return $storage->mkpath->then (sub { $upix->save })->finally (sub { $upix->close })->then (sub {
        return RepoIndexFile->open_by_app_and_storage (
          $self->set->app, $storage, allow_missing => 1, lock => 1,
          upstream_index => $upix,
          upstream_item => $upitem,
          path_index_key => (join "-", @{$self->{key}}),
        );
      });
    } else {
      # no upstream item pointer; use own storage
      return $upix->close->then (sub {
        return $self->SUPER::lock_index;
      });
    }
  });
}

sub _charset_from_mime ($) {
  my ($mime) = @_;
  return undef unless defined $mime and length $mime;
  my $parser = Web::MIME::Type::Parser->new;
  $parser->onerror (sub { });
  my $type = $parser->parse_string ($mime);
  return undef unless defined $type;
  my $cs = $type->param ('charset');
  return undef unless defined $cs and $cs =~ /\A[A-Za-z0-9_-]+\z/;
  return $cs;
} # _charset_from_mime

sub _strip_tags ($) {
  my ($html) = @_;
  $html =~ s{<[sS][cC][rR][iI][pP][tT]\b[^>]*>.*?</[sS][cC][rR][iI][pP][tT]>}{ }gs;
  $html =~ s{<[sS][tT][yY][lL][eE]\b[^>]*>.*?</[sS][tT][yY][lL][eE]>}{ }gs;
  $html =~ s{<!--.*?-->}{ }gs;
  $html =~ s{<[^>]+>}{ }gs;
  return $html;
}

sub fetch ($;%) {
  my ($self, %args) = @_;
  my $file_defs = $args{file_defs} || {};
  my $ret = {};
  return Promise->resolve->then (sub {
    my %uargs = (
      %args,
      skip_other_files => 0,
    );
    if (defined $self->{upstream_args}->{url}) {
      $uargs{skip_unless_url} = $self->{upstream_args}->{url};
      $uargs{skip_unless_path_string} = undef;
    } elsif (defined $self->{upstream_args}->{path_string}) {
      $uargs{skip_unless_url} = undef;
      $uargs{skip_unless_path_string} = $self->{upstream_args}->{path_string};
    }
    return $self->{upstream_repo}->fetch (%uargs)->then (sub {
      my $uret = $_[0] || {};
      if (exists $uret->{has_package}) {
        $ret->{has_package} = $uret->{has_package};
      } elsif (!$uret->{broken}) {
        $ret->{has_package} = 1;
      }
      $ret->{broken} = 1 if $uret->{broken};
      $ret->{not_modified} = 1 if $uret->{not_modified};
      $ret->{has_modified} = 1 if $uret->{has_modified};
      $ret->{timestamp} = $uret->{timestamp} if defined $uret->{timestamp};
      $ret->{insecure} = 1 if $uret->{insecure};
    });
  })->then (sub {
    return if $args{min};
    return $self->get_item_list (
      with_path => 1, with_item_key => 1, with_source_meta => 1,
      file_defs => $file_defs,
      has_error => $args{has_error},
      with_skipped => defined $args{file_key},
      skip_other_files => (defined $args{skip_unless_path_string} ? 0 : $args{skip_other_files}),
      skip_if_found => $args{no_update},
      skip_unless_path_string => $args{skip_unless_path_string},
      data_area_key => $args{data_area_key},
    )->then (sub {
      my $files = shift;
      # get_item_list performs filtering+storage; nothing else to do
      $ret->{has_package} = 1 if @$files;
    });
  })->then (sub {
    return $ret;
  });
}

sub get_item_list ($;%) {
  my ($self, %args) = @_;
  my $logger = $self->set->app->logger;
  my $files = [];

  if ($args{skip_if_found}) {
    my $fdef = ($args{file_defs} || {})->{$self->{upstream_file_key} // 'file'};
    if (defined $fdef and $fdef->{skip}) {
      return Promise->resolve ([]);
    }
    return $self->read_index->then (sub {
      my $ix = $_[0];
      my $item = $ix->{json}->{items}->{file};
      if (defined $item and defined $item->{files}->{data}) {
        my $file = {
          key => 'file',
          type => 'file',
          rev => $item->{rev},
          package_item => {
            mime => 'text/plain',
            file_name => (($item->{file_name} // 'file.txt') . ''),
          },
        };
        my $expected_sha = (($args{file_defs} || {})->{file} || {})->{sha256};
        if (defined $expected_sha and length $expected_sha and
            ($item->{rev}->{sha256} // '') ne $expected_sha) {
          $logger->message ({
            type => 'sha256 different from expected',
            key => 'file',
            value => ($item->{rev}->{sha256} // ''),
            expected => $expected_sha,
          });
          $args{has_error}->() if $args{has_error};
          return $ix->close->then (sub { return [] });
        }
        if ($args{with_path}) {
          my $p;
          eval { $p = $ix->get_path_of ($item, 'data') };
          if (defined $p and -f $p) {
            $file->{path} = $p;
          } else {
            return $ix->close->then (sub { return undef });
          }
        }
        return $ix->close->then (sub { return [$file] });
      }
      return $ix->close->then (sub { return undef });
    })->then (sub {
      my $found = $_[0];
      return $found if defined $found;
      # fall through to normal generation
      return $self->_generate_item_list (\%args);
    });
  }

  return $self->_generate_item_list (\%args);
}

sub _generate_item_list ($$) {
  my ($self, $args_ref) = @_;
  my %args = %$args_ref;
  my $logger = $self->set->app->logger;
  my $files = [];

  return $self->{upstream_repo}->get_item_list (
    %args,
    with_props => 1,
    with_source_meta => 1,
    with_path => 1,
    with_item_key => 1,
    with_skipped => 1,
    skip_other_files => 0,
  )->then (sub {
    my $upfiles = shift;
    # find upstream file by upstream_file_key
    my $upfile;
    for my $f (@$upfiles) {
      if (($f->{key} // '') eq ($self->{upstream_file_key} // 'file')) {
        $upfile = $f;
        last;
      }
    }
    unless (defined $upfile) {
      my $fdef = ($args{file_defs} || {})->{$self->{upstream_file_key} // 'file'};
      if (defined $fdef and $fdef->{skip}) {
        return [];
      }
      $logger->message ({ type => 'filtered upstream file not found', key => $self->{upstream_file_key} });
      $args{has_error}->() if $args{has_error};
      return [];
    }

    # check filter
    if ((defined $self->{filter} ? $self->{filter} : '') ne 'strip_tags') {
      $logger->message ({ type => 'unknown filter', value => $self->{filter} });
      $args{has_error}->() if $args{has_error};
      return [];
    }

    # if explicit upstream item is specified, verify it exists/matches
    my $verify_p = Promise->resolve (1);
    if (!$self->{inferred_upstream} and
        (defined $self->{upstream_args}->{url} or defined $self->{upstream_args}->{path_string})) {
      my $ok = 0;
      if (defined $self->{upstream_args}->{url}) {
        my $want = $self->{upstream_args}->{url}->stringify;
        my $rev = $upfile->{rev} || {};
        my $src = $upfile->{source} || {};
        for my $u ($rev->{url}, $rev->{original_url}, $src->{url}) {
          if (defined $u and $u eq $want) { $ok = 1; last }
        }
      }
      if ($ok) {
        $verify_p = Promise->resolve (1);
      } else {
        $verify_p = $self->{upstream_repo}->read_index->then (sub {
          my $upix = $_[0];
          my $upitem = $self->{upstream_repo}->_get_item ($upix, $self->{upstream_args});
          if (not defined $upitem and defined $self->{upstream_args}->{url}) {
            eval { (undef, $upitem) = $upix->get_item (url_string => $self->{upstream_args}->{url}->stringify, file_def => undef) };
          }
          my $ok2 = defined $upitem ? 1 : 0;
          return $upix->close->then (sub { return $ok2 });
        }, sub { return 0 });
      }
    }

    return $verify_p->then (sub {
      my $verified = $_[0];
      unless ($verified) {
        $logger->message ({ type => 'filtered upstream item not found' });
        $args{has_error}->() if $args{has_error};
        return [];
      }

      my $upstream_sha256 = $upfile->{rev}->{sha256} // '';
      my $filter_name = $self->{filter} // '';
      my $cache_p = $self->read_index->then (sub {
        my $ix = $_[0];
        my $item = $ix->{json}->{items}->{file};
        if (defined $item and
            defined $item->{files}->{data} and
            ($item->{upstream_sha256} // '') eq $upstream_sha256 and
            length $upstream_sha256 and
            ($item->{upstream_filter} // '') eq $filter_name) {
          my $file = {
            key => 'file',
            type => 'file',
            rev => $item->{rev},
            package_item => {
              mime => 'text/plain',
              file_name => (($upfile->{package_item}->{file_name} || 'file.txt') . ''),
            },
          };
          my $cs = _charset_from_mime ($upfile->{package_item}->{mime});
          $file->{package_item}->{mime} = "text/plain; charset=$cs" if defined $cs;
          my $expected_sha = (($args{file_defs} || {})->{file} || {})->{sha256};
          if (defined $expected_sha and length $expected_sha and
              ($item->{rev}->{sha256} // '') ne $expected_sha) {
            $logger->message ({
              type => 'sha256 different from expected',
              key => 'file',
              value => ($item->{rev}->{sha256} // ''),
              expected => $expected_sha,
            });
            $args{has_error}->() if $args{has_error};
            return $ix->close->then (sub { return [] });
          }
          if ($args{with_path}) {
            my $p;
            eval { $p = $ix->get_path_of ($item, 'data') };
            if (defined $p and -f $p) {
              $file->{path} = $p;
              return $ix->close->then (sub { return [$file] });
            }
            return $ix->close->then (sub { return undef });
          }
          return $ix->close->then (sub { return [$file] });
        }
        return $ix->close->then (sub { return undef });
      });

      return $cache_p->then (sub {
        my $cached = $_[0];
        return $cached if defined $cached;

        my $data_path = $upfile->{path};
        my $read_p;
        if (defined $data_path) {
          $read_p = Promised::File->new_from_path ($data_path)->read_byte_string;
        } else {
          # Fallback: locate upstream item data via upstream index
          $read_p = $self->{upstream_repo}->read_index->then (sub {
            my $upix = $_[0];
            my $upitem;
            if (defined $upfile->{item_key}) {
              $upitem = $upix->{json}->{items}->{$upfile->{item_key}};
            }
            if (not defined $upitem) {
              $upitem = $self->{upstream_repo}->_get_item ($upix, $self->{upstream_args});
            }
            if (not defined $upitem and defined $self->{upstream_args}->{url}) {
              eval {
                (undef, $upitem) = $upix->get_item (url_string => $self->{upstream_args}->{url}->stringify, file_def => undef);
              };
            }
            unless (defined $upitem) {
              $logger->message ({ type => 'filtered cannot find upstream item' });
              $args{has_error}->() if $args{has_error};
              return $upix->close->then (sub { return undef });
            }
            my $p;
            eval { $p = $upix->get_path_of ($upitem, 'data') };
            unless (defined $p) {
              $logger->message ({ type => 'filtered cannot find upstream data path' });
              $args{has_error}->() if $args{has_error};
              return $upix->close->then (sub { return undef });
            }
            return $upix->close->then (sub {
              return Promised::File->new_from_path ($p)->read_byte_string;
            });
          })->then (sub { return $_[0] });
        }

        return $read_p->then (sub {
          my $bytes = $_[0];
          return [] unless defined $bytes;

          my $filtered = _strip_tags ($bytes);
          my $fsha = sha256_hex ($filtered);
          my $expected_sha = (($args{file_defs} || {})->{file} || {})->{sha256};
          if (defined $expected_sha and length $expected_sha and $expected_sha ne $fsha) {
            $logger->message ({
              type => 'sha256 different from expected',
              key => 'file',
              value => $fsha,
              expected => $expected_sha,
            });
            $args{has_error}->() if $args{has_error};
            return [];
          }
          return $self->lock_index->then (sub {
            my $ix = $_[0];
            $ix->ensure_type ('data');
            my $temp_storage = $self->set->app->temp_storage;
            return $temp_storage->mkpath->then (sub {
              my $temp_path = $temp_storage->create_child_path;
              return Promised::File->new_from_path ($temp_path)->write_byte_string ($filtered)->then (sub {
                my $file = {
                  key => 'file',
                  type => 'file',
                  package_item => {
                    mime => 'text/plain',
                    file_name => (($upfile->{package_item}->{file_name} || 'file.txt') . ''),
                  },
                };
                my $cs = _charset_from_mime ($upfile->{package_item}->{mime});
                $file->{package_item}->{mime} = "text/plain; charset=$cs" if defined $cs;

                my $rev = {
                  timestamp => time,
                  sha256 => sha256_hex ($filtered),
                  length => length ($filtered),
                };
                my $index = $ix->index;
                $ix->touch;
                my $item = $index->{items}->{file} = {
                  type => 'file',
                  rev => $rev,
                  upstream_sha256 => $upstream_sha256,
                  upstream_filter => $filter_name,
                  file_name => $file->{package_item}->{file_name},
                  files => {},
                };
                my $dpath = $ix->{storage}->create_child_path (dir_name => 'objects', ext => 'dat');
                $item->{files}->{data} = $dpath->relative ($ix->{storage}->{path});
                $file->{rev} = $rev;
                $file->{path} = $dpath;

                return $ix->{storage}->hardlink_from ($item->{files}->{data}, $temp_path)->then (sub {
                  return Promised::File->new_from_path ($temp_path)->chmod (0444);
                })->then (sub {
                  return $ix->save;
                })->finally (sub { $ix->close })->then (sub {
                  push @$files, $file;
                  return $files;
                });
              });
            });
          });
        });
      });
    });
  })->then (sub {
    my $res = shift;
    return $res if ref $res eq 'ARRAY';
    return $files;
  });
}

1;

=head1 LICENSE

Copyright 2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
