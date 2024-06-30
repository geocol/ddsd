package SnapshotRepo;
use strict;
use warnings;
use Web::Encoding;
use Promised::Flow;

use Repo;
push our @ISA, qw(Repo);

use FileNames;
use ListWriter;

sub new_from_set_and_storage ($$$) {
  my ($class, $set, $storage) = @_;

  my $self = bless {
    set => $set,
    storage => $storage,
  }, $class;

  return $self;
} # new_from_set_and_storage

sub type () { "datasnapshot" }

sub construct_file_list_of ($$$;%) {
  my ($self, $from_repo, $def, %args) = @_;
  my $app = $self->set->app;
  my $logger = $app->logger;
  return $from_repo->get_item_list (
    with_path => 1, file_defs => $def->{files},
    has_error => $args{has_error},
    skip_other_files => $args{skip_other_files},
    with_source_meta => 1,
    data_area_key => $args{data_area_key},
  )->then (sub {
    my $files = shift;
    my $found = {};
    my $mod = {};
    my $skipped = {};
    for my $file (@$files) {
      if ($args{skip_all} and $args{init_by_default}) {
        if (defined $file->{path} and $file->{type} eq 'meta') {
          #
        } else {
          $def->{files}->{$file->{key}}->{skip} = \1;
          $skipped->{$file->{key}} = 1;
          $logger->count (['add_skipped']);
          next;
        }
      }

      if (defined $file->{set_type}) {
        if (defined $def->{files} and
            defined $def->{files}->{$file->{key}} and
            $def->{files}->{$file->{key}}->{skip}) {
          $skipped->{$file->{key}} = 1;
          next;
        } else {
          $file->{snapshot}->{is_directory} = 1;
        }
      } elsif (not defined $file->{path}) { # no copy available
        if ($args{init_by_default}) {
          if (defined $args{init_key}) {
            if ($args{init_key} eq $file->{key}) {
              delete $def->{files}->{$file->{key}}->{skip};
            } else {
              unless ($file->{type} eq 'package' or $file->{key} =~ /^meta:/) {
                $args{has_error}->();
                $logger->message ({
                  type => 'no local copy available',
                  key => $file->{key},
                });
              }
            }
          } else {
            unless ($args{init_no_skip_marking}) {
              $def->{files}->{$file->{key}}->{skip} = \1;
              $skipped->{$file->{key}} = 1;
              $logger->count (['add_skipped']);
              next;
            }
          }
        } else {
          if (defined $def->{files} and
              defined $def->{files}->{$file->{key}} and
              $def->{files}->{$file->{key}}->{skip}) {
            $skipped->{$file->{key}} = 1;
            next;
          }
          
          unless ($file->{type} eq 'package' or $file->{key} =~ /^meta:/) {
            $args{has_error}->();
            $logger->message ({
              type => 'no local copy available',
              key => $file->{key},
            });
          }
          $skipped->{$file->{key}} = 1;
          next;
        }
      } # no copy
      
      my $name;
      if (defined $def->{files} and
          defined $def->{files}->{$file->{key}} and
          $def->{files}->{$file->{key}}->{skip}) {
        $skipped->{$file->{key}} = 1;
        next;
      } elsif (defined $file->{file}->{directory} and
               $file->{file}->{directory} eq '') {
        die "Bad file name |$file->{file}->{name}|"
            unless FileNames::is_free_file_name $file->{file}->{name};
        $name = $file->{file}->{name};
      } elsif (not defined $file->{file}->{directory} or
               $file->{file}->{directory} eq 'files' or
               $file->{file}->{directory} eq 'package') {
        if (defined $file->{file}->{name}) {
          if (defined $file->{file}->{directory_file_key}) {
            if ($skipped->{$file->{file}->{directory_file_key}}) {
              $skipped->{$file->{key}} = 1;
              next;
            }
            if (not FileNames::is_free_file_name $file->{file}->{name}) {
              $args{has_error}->();
              $logger->message ({
                type => 'not a safe file name',
                key => $file->{key},
                value => $file->{file}->{name},
                _ => 'directory_file_key',
              });
              $skipped->{$file->{key}} = 1;
              next;
            }
            $file->{snapshot}->{directory_file_key} = $file->{file}->{directory_file_key};
            $file->{snapshot}->{file_name} = $file->{file}->{name};
            next;
          } else {
            my $dir = $file->{file}->{directory} // 'files';
            if (not FileNames::is_free_file_name $file->{file}->{name}) {
              $args{has_error}->();
              $logger->message ({
                type => 'not a safe file name',
                key => $file->{key},
                value => $file->{file}->{name},
                _ => 'non directory',
              });
              $skipped->{$file->{key}} = 1;
              next;
            }
            $name = "$dir/$file->{file}->{name}";
          }
        } else {
          if (defined $file->{rev} and
              defined $file->{rev}->{mime_filename}) {
            $name = $file->{rev}->{mime_filename};
          } elsif ((defined $file->{rev} and defined $file->{rev}->{url}) or
                   (defined $file->{source} and (defined ($file->{source}->{url} // $file->{source}->{base_url})))) {
            $name = (defined $file->{rev} ? $file->{rev}->{url} : undef)
                // $file->{source}->{url} // $file->{source}->{base_url};
            $name =~ s{#.*}{}s;
            $name =~ s{\?.*}{}s;
            $name =~ s{^.*[/\\]}{}s;
            $name = encode_web_utf8 $name;
            $name =~ s/%([0-9A-Fa-f]{2})/pack 'C', hex $1/ge;
            $name = decode_web_utf8 $name;
          } else {
            $name = $file->{id}; # or undef
          }
          my $name0 = $name;
          $name = FileNames::escape_file_name $name if defined $name;
          undef $name unless length $name;
          undef $name if defined $name and 63 < length $name;
          undef $name if defined $name and $name =~ /\x{FFFD}/;
          if (defined $name and not $name eq $name0) {
            if ($args{init_by_default}) {
              if (defined $args{init_key}) {
                if ($args{init_key} eq $file->{key}) {
                  $mod->{"files/$name"} = 1;
                } else {
                  undef $name;
                }
              } else {
                $mod->{"files/$name"} = 1;
              }
            } else {
              undef $name;
            }
          }
          unless (defined $name) {
            $args{has_error}->();
            $logger->message ({
              type => 'not a safe file name',
              key => $file->{key},
              value => $name0,
              _ => 'name0',
            });
            $skipped->{$file->{key}} = 1;
            next;
          }
          $name = "files/$name" if defined $name;
        }
      } else {
        die "Bad directory |$file->{file}->{directory}|";
      }
      $found->{lc $name}++ if defined $name;
      $file->{snapshot}->{file_name} = $name if defined $name;
    } # $file
    my $i = 1;
    my $key_to_dir_name = {};
    for my $file (@$files) {
      if (defined $file->{file}->{directory_file_key}) {
        my $dir_name = $key_to_dir_name->{$file->{file}->{directory_file_key}};
        if (defined $dir_name) {
          $found->{"$dir_name/$file->{file}->{name}"}++;
          $file->{snapshot}->{file_name} = "$dir_name/$file->{file}->{name}";
          next;
        } else {
          die "Directory not defined for |$file->{file}->{directory_file_key}|";
        }
      } elsif ($args{init_by_default} and
               (not defined $args{init_key} or
                $args{init_key} eq $file->{key})) {
        if (defined $def->{files} and
            defined $def->{files}->{$file->{key}} and
            $def->{files}->{$file->{key}}->{skip}) {
          $skipped->{$file->{key}} = 1;
          next;
        } elsif (defined $def->{files} and
                 defined $def->{files}->{$file->{key}}->{name}) {
          #
        } elsif (not defined $file->{snapshot}->{file_name}) {
          my $n = $i;
          $n = ++$i while $found->{"files/$n"};
          $def->{files}->{$file->{key}}->{name} = '' . $n;
          $found->{"files/$n"}++;
          $file->{snapshot}->{file_name} = "files/$n";
        } elsif ($found->{lc $file->{snapshot}->{file_name}} > 1) {
          my $n0 = $file->{snapshot}->{file_name};
          $n0 =~ s{^files/}{};
          my $n = $n0 . '-' . $i;
          $n = $n0 . '-' . ++$i while $found->{"files/$n"};
          $found->{"files/$n"}++;
          $def->{files}->{$file->{key}}->{name} = $n;
          $file->{snapshot}->{file_name} = "files/$n";
        } elsif ($mod->{$file->{snapshot}->{file_name}}) {
          my $n = $file->{snapshot}->{file_name};
          if ($n =~ s{^files/}{}) {
            $def->{files}->{$file->{key}}->{name} = $n;
          }
        } elsif (defined $file->{rev} and
                 not $file->{rev}->{url} eq $file->{rev}->{original_url}) {
          my $n = $file->{snapshot}->{file_name};
          if ($n =~ s{^files/}{}) {
            $def->{files}->{$file->{key}}->{name} = $n;
          }
        }
      } else {
        if (defined $file->{snapshot}->{file_name} and
            $found->{lc $file->{snapshot}->{file_name}} > 1) {
          $args{has_error}->();
          $logger->message ({
            type => 'duplicate file name',
            key => $file->{key},
            value => $file->{snapshot}->{file_name},
          });
          delete $file->{snapshot}->{file_name};
          next;
        }
      }
      if ($file->{snapshot}->{is_directory} and
          defined $file->{snapshot}->{file_name}) {
        $key_to_dir_name->{$file->{key}} = $file->{snapshot}->{file_name};
      }
    }
    return $files;
  });
} # construct_file_list_of

sub sync ($$$;%) {
  my ($self, $from_repo, $files, %args) = @_;
  my $storage = $self->storage;
  return $self->lock_index->then (sub {
    my $ix = $_[0];
    $ix->ensure_type ($self->type);
    return Promise->all ([
      Promised::File->new_from_path ($storage->{path}->child ('files'))->remove_tree (unsafe => 1),
      Promised::File->new_from_path ($storage->{path}->child ('package'))->remove_tree (unsafe => 1),
      Promised::File->new_from_path ($storage->{path}->child ('LICENSE'))->remove_tree (unsafe => 1),
      Promised::File->new_from_path ($storage->{path}->child ('index.json'))->remove_tree (unsafe => 1),
    ])->then (sub {
      my $items = $ix->items;
      $ix->touch;
      return promised_for {
        my $file = shift;

        return if $file->{snapshot}->{is_directory};
        
        my $name = $file->{snapshot}->{file_name};
        return unless defined $name;

        my $item = {};
        $item->{type} = $file->{type};
        $item->{files}->{data} = $name;
        $item->{rev} = $file->{rev};
        $items->{$file->{key}} = $item;

        return $storage->hardlink_from ($name, $file->{path});
      } $files;
    })->then (sub { return $ix->save (readonly => 1) })->then (sub {
      my $legal_path = $storage->{path}->child ('LICENSE');
      my $outer = ListWriter->new_from_filehandle ($legal_path->openw);
      my $cleanup = sub { };
      return $from_repo->get_legal (data_area_key => $args{data_area_key})->then (sub {
        my $json = $_[0];
        $cleanup = $from_repo->format_legal ($outer, $json); # XXX locale
      })->finally (sub {
        $cleanup->();
        return $outer->close->then (sub {
          my $file = Promised::File->new_from_path ($legal_path);
          return $file->chmod (0444);
        });
      });
    });
  });
} # sync

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
