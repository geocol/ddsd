package JSONLogger;
use strict;
use warnings;
use Path::Tiny;
use Time::HiRes qw(time);
use ArrayBuffer;
use DataView;
use WritableStream;
use Streams::Filehandle;
use JSON::PS;
use Promised::File;

use App;

sub new_from_filehandle ($$) {
  my $self = bless {}, $_[0];
  $self->{ws} = Streams::Filehandle->create_writable ($_[1]);
  $self->{writer} = $self->{ws}->get_writer;
  return $self;
} # new_from_filehandle

sub new_from_path ($$) {
  my $self = bless {}, $_[0];
  my $file = Promised::File->new_from_path ($_[1]);
  $self->{ws} = $file->write_bytes;
  $self->{writer} = $self->{ws}->get_writer;
  return $self;
} # new_from_path

sub new_null ($) {
  my $self = bless {}, $_[0];
  $self->{ws} = WritableStream->new ({
    start => sub { },
    write => sub { },
    close => sub { },
    abort => sub { },
  });
  $self->{writer} = $self->{ws}->get_writer;
  return $self;
} # new_null

sub _write ($$) {
  my $self = $_[0];
  my $dv = DataView->new (ArrayBuffer->new_from_scalarref (\($_[1])));
  return $self->{writer}->write ($dv);
} # _write

sub _error ($$) {
  my ($self, $error) = @_;
  return $self->_write ((perl2json_bytes $error) . "\x0A")->then (sub {
    return $error;
  });
} # _error

sub propagate ($$) {
  my ($self, $opts) = @_;
  return $self->_error ($opts);
} # propagate

sub info ($$) {
  my ($self, $opts) = @_;
  return $self->_error ({level => 'info', time => time, error => $opts});
} # info

sub message ($$) {
  my ($self, $opts) = @_;
  my $error = {level => 'message', time => time, error => $opts};
  $self->_error ($error);
  if (delete $self->{stderr_continue}) {
    print STDERR "\n";
  }
  print STDERR (App::Error->new ($error));
} # message

sub message_counts ($;%) {
  my ($self, %args) = @_;

  my $cc = $self->{counts} || {};
  my $error = {level => 'message', time => time, counts => $cc,
               error => {type => 'counts'}};
  $self->_error ($error);

  if (delete $self->{stderr_continue}) {
    print STDERR "\n";
  }
  # XXX locale
  printf STDERR "%s HTTP requests, %s files transferred, %s fetches failed.\n",
      $cc->{http_request} || 0, $cc->{http_request_completed} || 0,
      $cc->{fetch_failure} || 0;
  if ($cc->{add_package}) {
    printf STDERR "%s data package added, %s files skipped.\n",
        $cc->{add_package}, $cc->{add_skipped} || 0;
    if (defined $args{data_package_key} and $cc->{add_skipped}) {
      printf STDERR "Run:\n\n  \$ %s use %s --all\n\n... to use skipped files.\n",
          $self->ddsd_path_string,
          (quotemeta $args{data_package_key});
    }
  }
} # message_counts

sub message_completed ($$) {
  my ($self, $exit) = @_;
  $self->info ({
    type => 'completed',
    value => $exit,
  });

  unless ($exit == 0) {
    if (delete $self->{stderr_continue}) {
      print STDERR "\n";
    }
    # XXXlocale
    printf STDERR "Exit status: %d\n", $exit;
  }
} # message_completed

sub start ($$$;%) {
  my ($self, $max, $opts, %args) = @_;
  my $n = 0;
  my $progress_id = '' . rand;
  $self->_error ({level => 'info', time => time, error => $opts,
                  action => 'start',
                  n => $n,
                  max => $max, # or undef
                  progress_id => $progress_id});
  
  my $prev_time = time;
  my $current = {
    delta => 0,
    p => ($max ? 1 / $max : 1),
    q => ($max ? 100 : 1),
    value => 0,
    label => '',
  };
  my $this_up = sub ($$$) {
    my $v = ($_[0] // $max) * $current->{p} * $current->{q};
    printf STDERR "\r%2.1f %% %s ", $v, substr $_[1], 0, 60;
    $current->{written} = 1;
    if ($v >= 100) {
      printf STDERR "\n";
      delete $self->{stderr_continue};
    } else {
      $self->{stderr_continue} = 1;
    }
  }; # $this_up
  my $upstream_up = $args{update_progress} || $this_up;
  my $up = sub {
    my ($value, $v, $depth) = @_;
    if (defined $value) {
      $current->{value} += $current->{delta} * $value;
      $upstream_up->($current->{value} * $current->{p}, $v, $depth + 1);
    } else {
      $current->{value} = $max;
      $upstream_up->($max * $current->{p}, $v, $depth + 1);
    }
    $current->{written} = 1;
  };
  return bless {
    logger => $self,
    update_progress => $up,
    next => sub {
      my $delta = $_[0] // 1;
      $max = $_[1] if defined $_[1];
      my $args = $_[2] || {};
      my $now = time;
      my $elapsed = $now - $prev_time;
      $current->{delta} += $delta;
      if ($elapsed > 1) {
        my $err = {%$opts, %$args};
        $self->_error ({level => 'info', time => $now, error => $err,
                        action => 'progress',
                        n => $n, delta => $delta,
                        max => $max, # or undef
                        progress_id => $progress_id});
        $current->{q} = $max ? 100 : 1;
        $current->{p} = $max ? 1 / $max : 1;
        $current->{value} = $n;
        my $v = $err->{value} // $err->{key} // (defined $err->{url} and ref $err->{url} ? $err->{url}->stringify : $err->{url}) // $err->{type} // '';
        $current->{label} = $v if length $v;
        if ($max) {
          # XXX upstream's value need to be recomputed if $max is updated
          $upstream_up->($current->{value} * $current->{p}, $current->{label}, 0);
        } else {
          $this_up->($current->{value}, $current->{label}, 0);
        }
        $prev_time = $now;
        $current->{delta} = 0;
      }
      $n += $delta;
    },
    ok => sub {
      my $v = $_[0];
      $self->_error ({level => 'info', time => time, error => $opts,
                      action => 'done', progress_id => $progress_id});
      if ($current->{written}) {
        if ($max) {
          $upstream_up->(undef, $current->{label}, 0);
        } else {
          $max = 1;
          $current->{p} = 1;
          $current->{q} = 100;
          $this_up->(undef, $current->{label}, 0);
        }
      }
      return $v;
    },
    ng => sub {
      my $v = $_[0];
      $self->_error ({level => 'info', time => time, error => $opts,
                      action => 'aborted', progress_id => $progress_id});
      die $v;
    },
  }, 'JSONLogger::Child';
} # start

sub throw ($$) {
  my ($self, $opts) = @_;
  my $error = {level => 'fatal', time => time, error => $opts};
  $self->_error ($error);
  die App::Error->new ($error);
} # throw

sub count ($$) {
  my ($self, $names) = @_;
  $self->{counts}->{$_}++ for @$names;
} # count

sub ddsd_path_string ($) {
  my $path1 = path ($0)->parent->parent->child ('ddsd');
  my $path2 = $path1->relative (".");
  my $path = (length $path1) > (length $path2) ? $path2 : $path1;
  $path = './' . $path if $path eq 'ddsd';
  return '' . $path;
} # ddsd_path_string

sub close ($) {
  my $self = $_[0];
  if ($self->{stderr_continue}) {
    print STDERR "\n";
  }
  return $self->{writer}->close;
} # close

package JSONLogger::Child;

sub info ($@) { shift->{logger}->info (@_) }
sub message ($@) { shift->{logger}->message (@_) }
sub throw ($@) { shift->{logger}->throw (@_) }
sub propagate ($@) { shift->{logger}->propagate (@_) }
sub count ($@) { shift->{logger}->count (@_) }

sub start ($@) {
  my $self = shift;
  return $self->{logger}->start (@_, update_progress => $self->{update_progress});
} # start

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
