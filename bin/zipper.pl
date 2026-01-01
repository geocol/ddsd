use strict;
use warnings;
use Carp;
use Time::HiRes qw(time);
use Path::Tiny;
use JSON::PS;
use Digest::SHA;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use Archive::Zip::MemberRead;
use Web::Encoding;
use Web::Encoding::Sniffer;
use Web::URL;

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

  if (defined $in->{comment}) {
    my $s;
    if ($in->{byte_comment}) {
      $s = $in->{comment};
      utf8::downgrade ($s);
    } else {
      $s = encode_web_utf8 $in->{comment};
    }
    $zip->zipfileComment ($s);
  }

  for my $file (@{$in->{files}}) {
    print_info {type => 'add file to archive', format => 'zip',
                path => $file->{input_file_name},
                input_size => (-s $file->{input_file_name}),
                path_in_archive => $file->{file_name}};

    my $name;
    my $utf8 = 0;
    if ($file->{file_name} =~ /[^\x00-\x7F]/) {
      if ($file->{byte_file_name}) {
        $name = $file->{file_name};
        utf8::downgrade ($name);
      } else {
        $name = $file->{file_name};
        $utf8 = 1;
      }
    } else { ## ASCII only
      $name = encode_web_utf8 $file->{file_name};
    }

    my $mem;
    {
      local $Archive::Zip::UNICODE = $utf8;
      if ($file->{is_directory}) {
        $mem = $zip->addDirectory ($file->{input_file_name}, $file->{file_name})
            or die "$file->{input_file_name}: $!";
      } else {
        $mem = $zip->addFile ($file->{input_file_name}, $file->{file_name})
            or die "$file->{input_file_name}: $!";
      }
    }
    $mem->setLastModFileDateTimeFromUnix ($file->{timestamp})
        if defined $file->{timestamp};
    
    if (defined $file->{comment}) {
      my $s;
      if ($file->{byte_comment}) {
        $s = $file->{comment};
        utf8::downgrade $s;
      } else {
        $s = $file->{comment};
        utf8::encode $s;
      }
      $mem->fileComment ($s);
    }
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
  {
    my $new = \&Archive::Zip::Member::endRead;
    local *Archive::Zip::Member::endRead = sub {
      my $mem = $_[0];
      my $ret = $new->(@_);
      $mem->{_raw_fileName} = $mem->{fileName};
      $mem->{_raw_fileComment} = $mem->{fileComment};
      return $ret;
    };
      
    unless ($zip->read ($in->{input_file_name}) == AZ_OK) {
      die "$in->{input_file_name}: Failed to read";
    }
    ## If the file is broken, |->read| can throw.
  }

  my $url;
  $url = Web::URL->parse_string ($in->{url}) if defined $in->{url};

  my $names1 = [];
  my $names2 = [];
  
  my $meta = {};
  $meta->{raw_comment} = $zip->zipfileComment;
  push @$names1, $meta->{raw_comment} if $meta->{raw_comment} =~ /[^\x00-\x7F]/;

  my @list;
  for my $member (($zip->members)) {
    push @list, my $item = {
      central => {
        raw_path => $member->{_raw_fileName},
        raw_comment => $member->{_raw_fileComment},
        ## Archive::Zip's $member->fileName returns text when general
        ## purpose bit 11 is set using Perl's Encode::decode_utf8 or
        ## bytes otherwise.  $member->fileComment always returns
        ## bytes.  We don't use them as it's not sure whether
        ## fileComment's current status is stable or whether
        ## Encode::decode_utf8 is compatible enough to Encoding
        ## Standard's utf-8.
        byte_length => $member->uncompressedSize,
        zip_general_purpose_bit_flag => $member->bitFlag,
      #fileAttributeFormat => $member->fileAttributeFormat,
      #versionMadeBy => $member->versionMadeBy,
      #internalFileAttributes => $member->internalFileAttributes,
        # zip_unicode_path zip_unicode_comment
      },
      time => $member->lastModTime,
      local => {
        ## Not accessible
        #raw_path
        #byte_length
        #zip_general_purpose_bit_flag
        #is_directory
        # zip_unicode_path zip_unicode_comment
      },
      # path path_encoding comment comment_encoding
    };
    $item->{is_directory} = 1 if $member->isDirectory; # comes from ->{central}->{raw_path} and ->{central}->uncompressed size

    my $times = {};
    ## last mod file time / last mod file date
    $times->{last_mod} = $member->lastModFileDateTime;

    {
      my $extra = $member->cdExtraField;
      last unless defined $extra;

      my $pos = 0;
      while ($pos + 4 <= length ($extra)) {
        my ($header_id, $data_len) = unpack ("vv", substr ($extra, $pos, 4));
        $pos += 4;
        my $data = substr ($extra, $pos, $data_len);
        $pos += $data_len;

        if ($header_id == 0x7075) { # Info-ZIP Unicode Path Extra Field
          my ($ver, $crc32, $utf8_name) = unpack("C N a*", $data);
          $item->{central}->{zip_unicode_path} //= decode_web_utf8_no_bom $utf8_name;
        } elsif ($header_id == 0x6375) { # Info-ZIP Unicode Comment Extra Field
          my ($ver, $crc32, $utf8_comment) = unpack("C N a*", $data);
          $item->{central}->{zip_unicode_comment} //= $utf8_comment;
          
        ## Not sure these are used in the wild or not:
        #} elsif ($header_id == 0x0008) { # Extended Language Encoding Extra Field
        #  $item->{extended_language_encoding} //= $data;
        #} elsif ($header_id == 0x5A4C) { # ZipArchive Extra Field
        #  my ($version, $flag) = unpack ("CC", substr ($data, 0, 2));
        #  my $offset = 2;
        #  if ($flag & 0x01) { # Filename Code Page
        #    my $filename_cp = unpack ("V", substr ($data, $offset, 4));
        #    $item->{ziparchive_filename_cp} //= $filename_cp;
        #    $offset += 4;
        #  }
        #  if ($flag & 0x04) { # Comment Code Page
        #    my $comment_cp = unpack ("V", substr ($data, -4));
        #    $item->{ziparchive_comment_cp} //= $comment_cp;
        #    substr ($data, -4) = '';
        #  }
        #  if ($flag & 0x02) { # Encoded Filename
        #    my $encoded_name = substr ($data, $offset);
        #    $item->{ziparchive_encoded_filename} //= $encoded_name;
        #  }
        #} elsif ($header_id == 0x554E) { # Xceed Unicode Extra Field
        #  my $sig = unpack 'V', substr $data, 0, 4;
        #  if ($sig == 0x5843554E) {
        #    my ($name_len, $comment_len) = unpack ("vv", substr ($data, 4, 4));
        #    $item->{xceed_unicode_filename} //= substr $data, 8, $name_len * 2;
        #    $item->{xceed_unicode_comment} //= substr $data, 8 + $name_len * 2, $comment_len * 2;
        #  }
        #} else {
        #  #
        }
      }
    } # cd

    push @{defined $item->{central}->{zip_unicode_path} ? $names2 : $names1}, $item->{central}->{raw_path}
        if not utf8::is_utf8 ($item->{central}->{raw_path}) and
           $item->{central}->{raw_path} =~ /[^\x00-\x7F]/;
    push @{defined $item->{central}->{zip_unicode_comment} ? $names2 : $names1}, $item->{central}->{raw_comment}
        if not utf8::is_utf8 ($item->{central}->{raw_comment}) and
           $item->{central}->{raw_comment} =~ /[^\x00-\x7F]/;
  } # $member
  if (@$names1) {
    my $det = Web::Encoding::Sniffer->new_from_context ('zip');
    $det->detect ((join "\x0A", @$names1, @$names2),
                  forced => $in->{forced_encoding},
                  context_url => $url);
    my $charset = $det->encoding;
    for my $item (@list) {
      if ($item->{central}->{zip_general_purpose_bit_flag} & 0x0800) { # UTF-8 flagged
        $item->{path} = decode_web_utf8_no_bom $item->{central}->{raw_path};
      } elsif (defined $item->{central}->{zip_unicode_path}) {
        $item->{path} = $item->{central}->{zip_unicode_path};
      } elsif (defined $charset and
               $item->{central}->{raw_path} =~ /[^\x00-\x7F]/) {
        if ($charset eq 'utf-8') {
          $item->{path} = decode_web_utf8_no_bom $item->{central}->{raw_path};
        } else {
          $item->{path} = decode_web_charset $charset, $item->{central}->{raw_path};
        }
        $item->{path_encoding} = $charset;
      } else {
        $item->{path} = $item->{central}->{raw_path};
        $item->{path_encoding} = 'ibm437';
      }
      if ($item->{central}->{zip_general_purpose_bit_flag} & 0x0800) { # UTF-8 flagged
        $item->{comment} = decode_web_utf8_no_bom $item->{central}->{raw_comment};
      } elsif (defined $item->{central}->{zip_unicode_comment}) {
        $item->{comment} = $item->{central}->{zip_unicode_comment};
      } elsif (defined $charset and
               $item->{central}->{raw_comment} =~ /[^\x00-\x7F]/) {
        if ($charset eq 'utf-8') {
          $item->{comment} = decode_web_utf8_no_bom $item->{central}->{raw_comment};
        } else {
          $item->{comment} = decode_web_charset $charset, $item->{central}->{raw_comment};
        }
        $item->{comment_encoding} = $charset;
      } else {
        $item->{comment} = $item->{central}->{raw_comment};
        $item->{comment_encoding} = 'ibm437';
      }
    }
    if ($charset eq 'utf-8') {
      $meta->{comment} = decode_web_utf8_no_bom $meta->{raw_comment};
    } else {
      $meta->{comment} = decode_web_charset $charset, $meta->{raw_comment};
    }
    $meta->{comment_encoding} = $charset;
  } else {
    for my $item (@list) {
      if (defined $item->{central}->{zip_unicode_path}) {
        $item->{path} = $item->{central}->{zip_unicode_path};
      } elsif (utf8::is_utf8 $item->{central}->{raw_path}) {
        $item->{path} = $item->{central}->{raw_path};
      } else {
        $item->{path} = $item->{central}->{raw_path};
        $item->{path_encoding} = 'ibm437';
      }
      if (defined $item->{central}->{zip_unicode_comment}) {
        $item->{comment} = $item->{central}->{zip_unicode_comment};
      } elsif (utf8::is_utf8 $item->{central}->{raw_comment}) {
        $item->{comment} = $item->{central}->{raw_comment};
      } else {
        $item->{comment} = $item->{central}->{raw_comment};
      }
    }
    $meta->{comment} = $meta->{raw_comment};
    $meta->{comment_encoding} = 'ibm437';
  } # names

  return {meta => $meta, files => \@list};
} # list

sub extract ($) {
  my $in = shift;

  my $zip = Archive::Zip->new;
  {
    my $new = \&Archive::Zip::Member::endRead;
    local *Archive::Zip::Member::endRead = sub {
      my $mem = $_[0];
      my $ret = $new->(@_);
      $mem->{_raw_fileName} = $mem->{fileName};
      #$mem->{_raw_fileComment} = $mem->{fileComment};
      return $ret;
    };

    unless ($zip->read ($in->{input_file_name}) == AZ_OK) {
      die "$in->{input_file_name}: Failed to open";
    }
    ## If the file is broken, |->read| can throw.
  }

  my $member;
  for my $mem (($zip->members)) {
    if ($mem->{_raw_fileName} eq $in->{file_name}) {
      $member = $mem;
      last;
    }
  }
  die "$in->{file_name}: File not found" unless defined $member;

  my $out_f = path ($in->{output_file_name})->openw;
  my $sha = Digest::SHA->new (256);

  my $fh = Archive::Zip::MemberRead->new ($member);
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
  Archive::Zip::setErrorHandler (sub {
    my $info = {
      type => 'Archive::Zip error',
      error => ''.$_[0],
      location => {short => Carp::shortmess},
    };
    $info->{location}->{long} = Carp::longmess if $ENV{DDSD_DEBUG};
    print_info $info;
  });
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

Copyright 2024-2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
