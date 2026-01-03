use strict;
use warnings;
use Carp;
use Time::HiRes qw(time);
use POSIX qw(floor);
use Math::BigFloat;
use Path::Tiny;
use JSON::PS;
use Digest::SHA;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use Archive::Zip::MemberRead;
use Web::Encoding;
use Web::Encoding::Sniffer;
use Web::URL;
use Web::DateTime;

sub print_item ($) {
  print perl2json_bytes $_[0];
  print "\x0A";
} # print_item

sub print_info ($) {
  print_item {type => 'info', error => $_[0], time => time};
} # print_info

{
  my $x = Math::BigFloat->new ('116444736000000000');
  my $y = Math::BigFloat->new ('10000000');

  sub _unix2ntfstime ($) {
    return ((Math::BigFloat->new ($_[0]) * $y + $x)->bstr);
  } # _unix2ntfstime

  sub _ntfs2unixtime ($) {
    return (((Math::BigFloat->new ($_[0]) - $x) / $y)->bstr);
  } # _ntfs2unixtime
}

## <https://wiki.suikawiki.org/n/FAT%E3%81%AE%E6%97%A5%E6%99%82%E5%BD%A2%E5%BC%8F>
sub _from_dostime ($) {
  my $dos = $_[0];
  my $y = (($dos >> 25) & 0x7F) + 1980;
  my $M = (($dos >> 21) & 0x0F);
  my $d = (($dos >> 16) & 0x1F);
  my $h = (($dos >> 11) & 0x1F);
  my $m = (($dos >> 5) & 0x3F);
  my $s = (($dos << 1) & 0x3E);
  return Web::DateTime->new_from_components ($y, $M, $d, $h, $m, $s);
} # _from_dostime

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
    if (defined $file->{timestamp}) {
      local $ENV{TZ} = 'UTC';
      $mem->setLastModFileDateTimeFromUnix
          ($file->{timestamp} + ($file->{tzoffset} || 0));
      if (defined $file->{tzoffset}) {
        my $cd_extra = '';
        my $local_extra = '';
        if ($file->{ntfs}) {
          $cd_extra .= pack 'vvL<vvQ<Q<Q<',
              0x000A, 4+2+2+8+8+8,
              0,
              0x01, 24,
              _unix2ntfstime ($file->{timestamp}),
              0,
              defined $file->{birthtime} ? _unix2ntfstime ($file->{birthtime}) : 0;
        } else {
          if (defined $file->{birthtime}) {
            $cd_extra .= pack 'vvCV',
                0x5455, 1+4,
                0x01 | 0x04,
                $file->{timestamp};
            $local_extra .= pack 'vvCVV',
                0x5455, 1+4+4,
                0x01 | 0x04,
                $file->{timestamp}, $file->{birthtime};
          } else {
            $cd_extra .= pack 'vvCV',
                0x5455, 1+4,
                0x01,
                $file->{timestamp};
          }
        }
        $mem->cdExtraField ($cd_extra);
        $mem->localExtraField ($local_extra);
      }
    }
    
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
  $meta->{tzoffset} = $in->{forced_tzoffset} if defined $in->{forced_tzoffset};

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

        ## last mod file time / last mod file date
        zip_raw_last_mod_file_date_time => $member->lastModFileDateTime,

        #fileAttributeFormat => $member->fileAttributeFormat,
        #versionMadeBy => $member->versionMadeBy,
        #internalFileAttributes => $member->internalFileAttributes,

        # zip_unicode_path zip_unicode_comment
      },
      local => {
        ## Not accessible
        #raw_path
        #byte_length
        #zip_general_purpose_bit_flag
        #zip_raw_last_mod_file_date_time
        
        # zip_unicode_path zip_unicode_comment
      },
      # path path_encoding comment comment_encoding
      # mtime birthtime tzoffset
    };
    $item->{is_directory} = 1 if $member->isDirectory; # comes from ->{central}->{raw_path} and ->{central}->uncompressed size

    my $mod_dt = _from_dostime ($item->{central}->{zip_raw_last_mod_file_date_time});
    my $unix = $mod_dt->year < 2038 ? 'L<' : 'V'; # signed / unsigned 32-bit

    for (
      ['central', 'cdExtraField'],
      ['local', 'localExtraField'],
    ) {
      my ($meta_key, $method) = @$_;
      my $extra = $member->$method;
      my $pos = 0;
      while ($pos + 4 <= length ($extra)) {
        my ($header_id, $data_len) = unpack ("vv", substr ($extra, $pos, 4));
        $pos += 4;
        my $data = substr ($extra, $pos, $data_len);
        $pos += $data_len;

        if ($header_id == 0x7075) { # Info-ZIP Unicode Path Extra Field
          my ($ver, $crc32, $utf8_name) = unpack("C N a*", $data);
          $item->{$meta_key}->{zip_unicode_path} //= decode_web_utf8_no_bom $utf8_name;
        } elsif ($header_id == 0x6375) { # Info-ZIP Unicode Comment Extra Field
          my ($ver, $crc32, $utf8_comment) = unpack("C N a*", $data);
          $item->{$meta_key}->{zip_unicode_comment} //= $utf8_comment;
        } elsif ($header_id == 0x5455) { # Extended Timestamp
          my $flags = unpack ('C', $data);
          my $off = 1;
          $item->{$meta_key}->{zip_ext_mtime} = unpack ($unix, substr($data, $off, 4))
              if $flags & 0x01; # ModTime
          $off += 4 if $flags & 0x01;
          $item->{$meta_key}->{zip_ext_atime} = unpack ($unix, substr($data, $off, 4))
              if $flags & 0x02; # AcTime
          $off += 4 if $flags & 0x02;
          $item->{$meta_key}->{zip_ext_birthtime} = unpack ($unix, substr($data, $off, 4))
              if $flags & 0x04; # CrTime
        } elsif ($header_id == 0x000A) { # NTFS Extra Field
          my $p = 4; # Reserved
          while ($p + 4 <= length($data)) {
            my ($tag, $sz) = unpack ('vv', substr ($data, $p, 4)); # Tag / Size
            my $v = substr ($data, $p + 4, $sz);
            if ($tag == 0x0001) {
              my ($m, $a, $c) = unpack ('Q<Q<Q<', $v);
              ## Stringify values such that |ddsd ls|'s JSON outputs
              ## are JS compatible.
              $item->{$meta_key}->{zip_ntfs_mtime} = ''.$m; # Mtime
              $item->{$meta_key}->{zip_ntfs_atime} = ''.$a; # Atime
              $item->{$meta_key}->{zip_ntfs_birthtime} = ''.$c; # Ctime
            }
            $p += 4 + $sz;
          }
        } elsif ($header_id == 0x5855) { # Info-ZIP Unix Extra Field
          my ($actime, $modtime) = unpack ($unix.$unix, $data);
          $item->{$meta_key}->{infozip_unix_atime} = $actime;
          $item->{$meta_key}->{infozip_unix_mtime} = $modtime;
        } elsif ($header_id == 0x000D) { # UNIX Extra Field
          my ($atime, $mtime) = unpack ($unix.$unix, $data);
          $item->{$meta_key}->{zip_unix_atime} = $atime; # Atime
          $item->{$meta_key}->{zip_unix_mtime} = $mtime; # Mtime
          
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
    } # $meta_key

    ## <https://wiki.suikawiki.org/n/%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E3%81%AE%E6%99%82%E5%88%BB$47512>
    #
    ## Use copies of mtime and birthtime for any numeric operations
    ## such that IV / UV / NV is not generated before the JSON
    ## stringification.
    my $mtime;
    my $birthtime;
    if ($item->{central}->{zip_ntfs_mtime}) { # non-zero
      $item->{mtime} = _ntfs2unixtime ($item->{central}->{zip_ntfs_mtime});
    } elsif ($item->{local}->{zip_ntfs_mtime}) {
      $item->{mtime} = _ntfs2unixtime ($item->{local}->{zip_ntfs_mtime});
    } else {
      for my $key (qw(zip_ext_mtime infozip_unix_mtime zip_unix_mtime)) {
        if ($item->{central}->{$key}) {
          $item->{mtime} = $item->{central}->{$key};
          last;
        } elsif ($item->{local}->{$key}) {
          $item->{mtime} = $item->{local}->{$key};
          last;
        }
      }
    }
    $mtime = $item->{mtime};
    if (defined $mtime) { ## If UTC mtime is known,
      if (defined $in->{forced_tzoffset}) {
        $item->{tzoffset} = $in->{forced_tzoffset};
      } else {
        my $offset = $mod_dt->to_unix_number - $mtime;
        if ($offset >= 0) {
          $offset = int ( ($offset + 900/2) / 900 ) * 900;
          undef $offset if $offset > 24*60*60;
        } else {
          $offset = -int ( (-$offset + 900/2) / 900 ) * 900;
          undef $offset if $offset < -24*60*60;
        }
        if (defined $offset) {
          $item->{tzoffset} = $offset;
          $meta->{tzoffset} //= $offset;
        }
      }
    } else { ## If only local mtime is known,
      if (defined $in->{forced_tzoffset}) {
        $item->{tzoffset} = $in->{forced_tzoffset};
        $item->{mtime} = $mod_dt->to_unix_number - $item->{tzoffset};
      } else {
        $item->{mtime} = $mod_dt->to_unix_number;
        push @$names1, 1;
      }
    }
    if ($item->{central}->{zip_ntfs_birthtime}) { # non-zero
      $item->{birthtime} = _ntfs2unixtime ($item->{central}->{zip_ntfs_birthtime});
    } elsif ($item->{local}->{zip_ntfs_birthtime}) {
      $item->{birthtime} = _ntfs2unixtime ($item->{local}->{zip_ntfs_birthtime});
    } else {
      for my $key (qw(zip_ext_birthtime)) {
        if ($item->{central}->{$key}) {
          $item->{birthtime} = $item->{central}->{$key};
          last;
        } elsif ($item->{local}->{$key}) {
          $item->{birthtime} = $item->{local}->{$key};
          last;
        }
      }
      # or undef
    }
    $birthtime = $item->{birthtime};
    if (defined $birthtime and $mtime < $birthtime) {
      $item->{mtime} = $item->{birthtime};
    }

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

    ## <https://wiki.suikawiki.org/n/%E3%83%AD%E3%82%B1%E3%83%BC%E3%83%AB%E7%AD%89%E3%81%AB%E3%82%88%E3%82%8B%E6%96%87%E5%AD%97%E3%82%B3%E3%83%BC%E3%83%89%E5%88%A4%E5%AE%9A%E3%81%AE%E8%A3%9C%E5%8A%A9#section-%E6%96%87%E5%AD%97%E3%82%B3%E3%83%BC%E3%83%89%E3%81%8B%E3%82%89%E6%99%82%E5%B7%AE%E3%82%92%E6%8E%A8%E5%AE%9A>
    my $tz_guessed = {
      shift_jis => 9*60*60, 'euc-jp' => 9*60*60, 'euc-kr' => 9*60*60,
      big5 => 8*60*60, gb18030 => 8*60*60,
      'windows-874' => 7*60*60,
      ## XXX
      # windows-1254 ibm857  3*60*60/2*60*60
      # windows-1253 iso-8859-7 ibm737 windows-1257 ibm775 windows-1255 ibm862 2*60*60/3*60*60
      # windows-1250 ibm852 ibm865 1*60*60/2*60*60
    }->{$charset};
    # XXX $url based guesses
    $meta->{tzoffset} //= $tz_guessed;

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

      if (defined $meta->{tzoffset} and not defined $item->{tzoffset}) {
        $item->{tzoffset} = $meta->{tzoffset};
        $item->{mtime} -= $meta->{tzoffset};
      }
    } # $item
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
