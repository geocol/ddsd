package LsCommand;
use strict;
use warnings;
use Web::DateTime;
use JSON::PS;

use Command;
push our @ISA, qw(Command);

use PackageListFile;
use ListWriter;

sub run ($$;%) {
  my ($self, $out, %args) = @_;
  if (defined $args{data_repo_name}) {
    my $outer = ListWriter->new_from_filehandle ($out);
    $outer->formatter (sub {
      my $item = $_[0];
      my $m = '';
      my @v;
      my $no_local = not defined $item->{rev};
      if (defined $item->{rev} and defined $item->{rev}->{length}) {
        push @v, sprintf "%d B", # XXX formatting
            $item->{rev}->{length};
      }
      if (defined $item->{package_item}->{mime} and
          length $item->{package_item}->{mime}) {
        push @v, sprintf "|%s|", $item->{package_item}->{mime};
      }
      if (defined $item->{package_item}->{file_time}) {
        push @v, sprintf "%s",
            Web::DateTime->new_from_unix_time ($item->{package_item}->{file_time})->to_global_date_and_time_string; # XXX locale
      }
      $m .= sprintf "%s |%s| %s\x0A",
          {
            package => 'Package',
            meta => 'Metadata',
            dataset => 'Dataset',
            file => 'File',
            part => 'Part of dataset',
          }->{$item->{type}} // 'File',
          $item->{key} // '',
          ($no_local ? ($item->{type} eq 'package' or $item->{type} eq 'dataset') ? '' : '(No local copy)' : ((defined $item->{rev} and $item->{rev}->{insecure}) ? '(Insecure)' : ''));
      $m .= sprintf "  %s\x0A",
          {
            'fiware-ngsi' => 'FIWARE-NGSI API',
            sparql => 'SPARQL endpoint',
          }->{$item->{set_type}} // 'Unknown' if defined $item->{set_type};
      $m .= sprintf "  %s\x0A", join ' ', @v if @v;
      if (defined $item->{package_item}->{title}) {
        $m .= sprintf qq{  "%s"\x0A}, $item->{package_item}->{title};
      }
      if (defined $item->{rev} and defined $item->{rev}->{original_url}) {
        $m .= sprintf "  <%s>\x0A", $item->{rev}->{original_url};
      } elsif (defined $item->{package_item}->{page_url}) {
        $m .= sprintf "  <%s>\x0A", $item->{package_item}->{page_url};
      }
      if (defined $item->{path}) {
        $m .= sprintf qq{  "%s"\x0A}, $item->{path}->relative ('.');
      } else {
        $m .= sprintf "  %s\x0A", '(No file)'; # XXX locale
      }
      if ($args{with_source_meta} and defined $item->{ckan_resource}) {
        $m .= sprintf "  CKAN resource:\x0A";
        my $v = perl2json_chars_for_record $item->{ckan_resource};
        $v =~ s/\x0A/\x0A  /g;
        $v =~ s/\x0A  \z/\x0A/;
        $m .= "  " . $v;
      }
      if ($args{with_source_meta} and defined $item->{ckan_package}) {
        $m .= sprintf "  CKAN package:\x0A";
        local $item->{ckan_package}->{resources};
        delete $item->{ckan_package}->{resources};
        my $v = perl2json_chars_for_record $item->{ckan_package};
        $v =~ s/\x0A/\x0A  /g;
        $v =~ s/\x0A  \z/\x0A/;
        $m .= "  " . $v;
      }
      if ($args{with_item_meta} and defined $item->{package_item}) {
        $m .= sprintf "  Item:\x0A";
        my $v = perl2json_chars_for_record $item->{package_item};
        $v =~ s/\x0A/\x0A  /g;
        $v =~ s/\x0A  \z/\x0A/;
        $m .= "  " . $v;
      }
      if ($args{with_item_meta} and defined $item->{rev}) {
        $m .= sprintf "  File revision:\x0A";
        my $v = perl2json_chars_for_record $item->{rev};
        $v =~ s/\x0A/\x0A  /g;
        $v =~ s/\x0A  \z/\x0A/;
        $m .= "  " . $v;
      }
      return $m;
    }) unless $args{jsonl};

    my $def;
    my $plist;
    my $da_items = {};
    return PackageListFile->open_by_app ($self->app, allow_missing => 1)->then (sub {
      $plist = $_[0];
      my $logger = $self->app->logger;
      
      $def = $plist->get_def ($args{data_repo_name});
      return $logger->throw ({
        type => 'data area key not found',
        value => $args{data_repo_name},
        path => $plist->path,
      }) unless defined $def;

      my $da_repo = $self->app->data_area->get_repo ($args{data_repo_name});
      if (defined $da_repo) {
        return $da_repo->read_index->then (sub {
          my $in = $_[0];
          my $da_repo_path = $da_repo->storage->{path};
          my $items = $in->items;
          for my $key (keys %{$items}) {
            my $item = $items->{$key};
            if (defined $item->{files} and
                ref $item->{files} eq 'HASH' and
                defined $item->{files}->{data}) {
              $da_items->{$key} = $da_repo_path->child ($item->{files}->{data})->absolute;
            }
          }
        })->finally (sub {
          return $da_repo->close;
        });
      }
    })->then (sub {
      my $repo = $self->app->repo_set->get_repo_by_source
          ($def, path => $plist->path);
      return $repo->_use_mirror ($args{data_repo_name}, $def)->then (sub {
        return $repo->get_item_list (
          file_defs => $def->{files},
          with_source_meta => $args{with_source_meta},
          with_props => 1,
          with_snapshot_hash => 1,
          with_skipped => 1,
          has_error => sub { },
          data_area_key => $args{data_repo_name},
        );
      })->then (sub {
        my $items = $_[0];
        for my $item (@$items) {
          $item->{path} = $da_items->{$item->{key}};
          delete $item->{path} unless defined $item->{path};
          $outer->item ($item);
        }
        if (not $args{jsonl} and @$items and
            $items->[0]->{type} eq 'package') {
          if (defined $items->[0]->{package_item}->{snapshot_hash}) {
            $outer->formatted ("This snapshot: |$items->[0]->{package_item}->{snapshot_hash}|\n");
          }
        }
      })->finally (sub {
        return $repo->close;
      });
    })->finally (sub {
      return $outer->close;
    });
  } else {
    my $outer = ListWriter->new_from_filehandle ($out);
    return $self->run_data_area_list ($outer, jsonl => $args{jsonl})->finally (sub {
      return $outer->close;
    });
  }
} # run

sub run_data_area_list ($$;%) {
  my ($self, $outer, %args) = @_;
  $outer->formatter (sub {
    my $item = $_[0];
    if (defined $item->{path}) {
      return sprintf qq{%s\t"%s"\x0A},
          $item->{data_package_key}, $item->{path}->relative ('.');
    } else {
      return sprintf "%s\t-\x0A",
          $item->{data_package_key};
    }
  }) unless $args{jsonl};
  my $logger = $self->app->logger;
  return PackageListFile->open_by_app ($self->app, allow_missing => 1)->then (sub {
    my $plist = $_[0];
    my $defs = $plist->defs;
    return $self->app->data_area->storage->for_child_directories (sub {
      my $item = $_[0];
      my $def = delete $defs->{$item->{short_name}};
      return unless defined $def;

      my $it = {
        path => $item->{path}->absolute,
        data_package_key => $item->{short_name},
      };
      $outer->item ($it);
    }, $logger)->then (sub {
      for my $key (keys %$defs) {
        my $it = {data_package_key => $key};
        $outer->item ($it);
      }
    });
  });
} # run

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
