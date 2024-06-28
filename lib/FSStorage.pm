package FSStorage;
use strict;
use warnings;
use ArrayBuffer;
use DataView;
use Promise;
use Promised::Flow;
use Promised::File;
use Digest::SHA;
use JSON::PS;

sub new_from_path ($$) {
  my ($class, $path) = @_;

  my $self = bless {}, $class;
  $self->{path} = $path->absolute;

  return $self;
} # new_from_path

sub child ($@) {
  my $self = shift;
  my $path = $self->{path}->child (@_);
  my $storage = (ref $self)->new_from_path ($path);
  return $storage;
} # child

sub write_by_readable ($$;%) {
  my ($self, $rs, %args) = @_;
  my $dest_path = $self->{path}->child (rand);
  my $d;
  $d = Digest::SHA->new ("sha256") if $args{sha256};
  my $length = 0;
  my $r = {};
  my $need = $args{need_body_bytes} || 0;
  $r->{body_bytes} = '' if $need > 0;
  return Promise->resolve->then (sub {
    my $dest_file = Promised::File->new_from_path ($dest_path);
    my $dest_ws = $dest_file->write_bytes;
    my $dest_w = $dest_ws->get_writer;
    
    my $reader = $rs->get_reader ('byob');
    return promised_until {
      my $ab = ArrayBuffer->new (1024*10);
      my $dv = DataView->new ($ab);
      return $reader->read ($dv)->then (sub {
        if ($_[0]->{done}) {
          return $dest_w->close->then (sub {
            return 'done';
          });
        }

        if ($args{sha256}) {
          $d->add ($_[0]->{value}->manakai_to_string);
        }
        if (defined $r->{body_bytes}) {
          unless ($need <= length $r->{body_bytes}) {
            $r->{body_bytes} .= $_[0]->{value}->manakai_to_string;
          }
        }
        $dest_w->write ($_[0]->{value}); # XXX catch
        $length += $_[0]->{value}->byte_length;
        $args{as}->{next}->($_[0]->{value}->byte_length);
        
        return not 'done';
      });
    };
  })->then (sub {
    $r->{path} = $dest_path;
    $r->{sha256} = $d->hexdigest if $args{sha256};
    $r->{length} = $length;
    return $r;
  });
} # write_by_readable

sub write_json ($$) {
  my ($self, $name, $json) = @_;
  my $path = $self->{path}->child ($name);
  return Promised::File->new_from_path ($path)->write_byte_string (perl2json_bytes_for_record $json);
} # write_json

sub write_jsonl ($$) {
  my ($self, $name, $items) = @_;
  my $path = $self->{path}->child ($name);
  return Promised::File->new_from_path ($path)->write_byte_string
      (join '', map { (perl2json_bytes $_) . "\x0A" } @$items);
} # write_jsonl

sub hardlink_from ($$) {
  my ($self, $name, $from_path) = @_;
  my $path = $self->{path}->child ($name);
  return Promised::File->new_from_path ($path)->hardlink_from
      ($from_path, fallback_to_copy => 1);
} # hardlink_from

sub for_child_directories ($$$) {
  my ($self, $code, $logger) = @_;
  $logger->info ({
    type => 'iterate child directories',
    path => $self->{path}->absolute,
  });
  my $dir = Promised::File->new_from_path ($self->{path});
  return $dir->get_child_names->then (sub {
    return promised_for {
      my $short_name = $_[0];
      my $path = $self->{path}->child ($short_name);
      return Promised::File->new_from_path ($path)->is_directory->then (sub {
        if ($_[0]) {
          return $code->({short_name => $short_name, path => $path});
        } else {
          $logger->info ({
            type => 'not a directory',
            path => $path->absolute,
          });
        }
      }, sub {
        my $e = $_[0];
        $logger->info ({
          type => 'failed to read directory entry',
          path => $path->absolute,
          error_message => '' . $e,
        });
      });
    } $_[0];
  }, sub {
    my $e = $_[0];
    $logger->info ({
      type => 'failed to iterate children',
      path => $self->{path}->absolute,
      error_message => '' . $e,
    });
  });
} # for_child_directories

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
