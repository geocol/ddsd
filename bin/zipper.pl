use strict;
use warnings;
use Time::HiRes qw(time);
use Path::Tiny;
use JSON::PS;
use Digest::SHA;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use Archive::Zip::MemberRead;

sub print_item ($) {
  print perl2json_bytes $_[0];
  print "\x0A";
} # print_item

sub print_info ($) {
  print_item {type => 'info', error => $_[0], time => time};
} # print_info

sub create ($) {
  my $in = shift;
  print_info {type => 'zipper command started', value => 'create'};

  my $zip = Archive::Zip->new;

  for my $file (@{$in->{files}}) {
    print_info {type => 'add file to archive', format => 'zip',
                path => $file->{input_file_name},
                input_size => (-s $file->{input_file_name}),
                path_in_archive => $file->{file_name}};
    $zip->addFile ($file->{input_file_name}, $file->{file_name})
        or die "$file->{input_file_name}: $!";
  }

  print_info {type => 'write file', format => 'zip',
              path => $in->{output_file_name}};
  unless ($zip->writeToFileNamed ($in->{output_file_name}) == AZ_OK) {
    die "$in->{output_file_name}: Failed to write a zip file";
  }

  my $zip_f = path ($in->{output_file_name})->openr;
  my $sha = Digest::SHA->new (256);
  my $chunk_size = 4096;
  my $buffer;
  my $length = 0;
  while (my $bytes_read = $zip_f->read ($buffer, $chunk_size)) {
    $sha->add ($buffer);
    $length += length $buffer;
  }
  return {length => $length, sha256 => $sha->hexdigest};
} # create

sub list ($) {
  my $in = shift;

  my $zip = Archive::Zip->new;
  unless ($zip->read ($in->{input_file_name}) == AZ_OK) {
    die "$in->{input_file_name}: Failed to read";
  }

  my @list;
  for my $member (($zip->members)) {
    my $file_name = $member->fileName;
    my $file_size = $member->uncompressedSize;
    push @list, {name => $file_name, size => $file_size};
  }

  return {files => \@list};
} # list

sub extract ($) {
  my $in = shift;

  my $zip = Archive::Zip->new;
  unless ($zip->read ($in->{input_file_name}) == AZ_OK) {
    die "$in->{input_file_name}: Failed to open";
  }

  my $member = $zip->memberNamed ($in->{file_name});
  unless ($member) {
    die "$in->{file_name}: File not found";
  }

  my $out_f = path ($in->{output_file_name})->openw;
  my $sha = Digest::SHA->new (256);

  my $fh = Archive::Zip::MemberRead->new ($zip, $in->{file_name});
  my $chunk_size = 4096;
  my $buffer;
  my $length = 0;
  while (my $bytes_read = $fh->read ($buffer, $chunk_size)) {
    print $out_f $buffer;
    $sha->add ($buffer);
    $length += length $buffer;
  }

  return {length => $length, sha256 => $sha->hexdigest};
} # extract

sub main ($) {
  my ($in_bytes) = @_;
  print_info {type => 'zipper invoked', value => $0};
  my $exit_code = 0;
  my $return;
  eval {
    my $in = json_bytes2perl $in_bytes;
    die "Bad input" unless defined $in and ref $in eq 'HASH';

    if ($in->{command} eq 'create') {
      $return = create ($in);
    } elsif ($in->{command} eq 'list') {
      $return = list ($in);
    } elsif ($in->{command} eq 'extract') {
      $return = extract ($in);
    } else {
      die "Bad command |$in->{command}|";
    }
  };
  if ($@) {
    $return = {
      exit_code => 1,
      error => ''.$@,
    };
  }
  $return->{exit_code} ||= 0;
  $return->{type} = 'final';
  $return->{time} = time;
  print_item $return;
  return $return->{exit_code};
} # main

$| = 1;
exit main (do {
  local $/ = undef;
  scalar <>;
});

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
