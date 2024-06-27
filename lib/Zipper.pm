package Zipper;
use strict;
use warnings;
use Path::Tiny;
use Promised::Command;
use Promised::File;
use JSON::PS;

my $RootPath = path (__FILE__)->parent->parent->absolute;
my $PerlPath = $RootPath->child ('perl');
my $ZipperPath = $RootPath->child ('bin/zipper.pl');

sub _run ($$) {
  my ($logger, $args) = @_;
  
  my $cmd = Promised::Command->new ([
    $PerlPath,
    $ZipperPath,
  ]);
  my $in = perl2json_bytes $args;
  $cmd->stdin (\$in);
  my $out = '';
  my $final;
  my $process_output = sub {
    while ($out =~ s{^([^\x0A]*)\x0A}{}) {
      if (length $1) {
        my $json = json_bytes2perl $1;
        return $logger->throw ({
          type => 'Bad value from zipper',
          value => (substr $1, 0, 100),
        }) unless defined $json;
        if ($json->{type} eq 'final') {
          $final = $json
        } else {
          $logger->propagate ($json);
        }
      }
    }
  };
  $cmd->stdout (sub {
    $out .= $_[0] if defined $_[0];
    $process_output->();
  });
  return $cmd->run->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    $out .= "\x0A";
    $process_output->();
    if ($result->exit_code == 0) {
      return $final;
    } elsif ($result->exit_code == 1) {
      return $logger->throw ({
        type => 'zipper call failed',
        value => $final,
      });
    } else {
      die $result;
    }
  });
} # _run

sub create ($$$) {
  my ($class, $app, $in_files, $out_path) = @_;
  my $logger = $app->logger;

  return _run ($logger, {
    command => 'create',
    files => $in_files,
    output_file_name => $out_path->absolute,
  }); # {length, sha256}
} # create

sub extract ($$$$) {
  my ($class, $app, $zip_path, $file_name, $out_path) = @_;
  my $logger = $app->logger;

  return _run ($logger, {
    command => 'extract',
    input_file_name => $zip_path->absolute,
    file_name => $file_name,
    output_file_name => $out_path->absolute,
  }); # {length, sha256}
} # extract

sub read_json ($$$) {
  my ($class, $app, $zip_path, $file_name) = @_;
  my $logger = $app->logger;

  my $out_path = $app->temp_storage->{path}->child (rand);

  return _run ($logger, {
    command => 'extract',
    input_file_name => $zip_path->absolute,
    file_name => $file_name,
    output_file_name => $out_path->absolute,
  })->then (sub {
    my $result = $_[0];
    my $out_file = Promised::File->new_from_path ($out_path);
    return $out_file->read_byte_string->then (sub {
      return json_bytes2perl $_[0];
    });
  });
} # read_json

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

