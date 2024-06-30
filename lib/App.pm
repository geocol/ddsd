package App;
use strict;
use warnings;
use Time::HiRes qw(time);
use Web::Encoding;
use Path::Tiny;
use Promise;
use Promised::File;
use Getopt::Long;
use JSON::PS;

use FSStorage;
use RepoSet;
use DataArea;
use JSONLogger;

sub new_from_path ($$) {
  my $self = bless {
    root_path => $_[1]->absolute,
  }, $_[0];
  return $self;
} # new

sub logger ($) { $_[0]->{logger} }
sub temp_storage ($) { $_[0]->{temp_storage} }

sub config_path ($) {
  return $_[0]->{config_path} //= $_[0]->{root_path}->child ('config/ddsd');
} # config_path

sub states_path ($) {
  return $_[0]->{states_path} //= $_[0]->{root_path}->child ('local/ddsd/states');
} # states_path

sub repo_set ($) {
  my $self = $_[0];
  return $self->{repo_set} //= do {
    my $repo_path = $self->{root_path}->child ('local/ddsd/repo');
    RepoSet->new_from_app_and_path ($self, $repo_path);
  };
} # repo_set

sub data_area ($) {
  my $self = $_[0];
  return $self->{data_area} //= do {
    my $data_path = $self->{root_path}->child ('local/data');
    DataArea->new_from_app_and_path ($self, $data_path);
  };
} # data_area

sub ddsd_data_area ($) {
  my $self = $_[0];
  return $self->{ddsd_data_area} //= do {
    my $data_path = $self->{root_path}->child ('local/ddsd/data');
    DataArea->new_from_app_and_path ($self, $data_path);
  };
} # ddsd_data_area

sub temp_data_area ($) {
  my $self = $_[0];
  return $self->{temp_data_area} //= do {
    DataArea->new_from_app_and_path ($self, $self->{temp_path});
  };
} # temp_data_area

sub is_new ($$) {
  my ($self, $ts) = @_;
  return $self->{now} - 24*60*60 < $ts;
} # is_new

sub escape_for_key ($$) {
  my $key = encode_web_utf8 $_[1];
  $key =~ s{([^0-9A-Za-z_])}{sprintf '_%02X', ord $1}ge;
  return $key;
}

sub escape_for_dir_name ($$) {
  my $key = encode_web_utf8 $_[1];
  $key =~ s{([^0-9A-Za-z_.-]|\A[.-]|\.\z)}{sprintf '_%02X', ord $1}ge;
  return $key;
}

sub is_short_name ($$) {
  return $_[1] =~ /\A[0-9A-Za-z_][0-9A-Za-z_.-]*\z(?<!\.)/;
} # is_short_name

# returns unsafe text
sub file_name_from_url ($$) {
  my $name = $_[1];
  $name =~ s{#.*}{}s;
  $name =~ s{\?.*}{}s;
  $name =~ s{^https?://[^/]+/}{};
  return $name;
} # file_name_from_url

# returns unsafe text
sub file_name_with_ext ($$;%) {
  my ($self, $name, %args) = @_;

  if (not $name =~ /\.([0-9A-Za-z]+)$/ or
      {
        dat => 1,
      }->{lc $1}) {

    if (defined $args{mime}) {
      my $mime = $args{mime};
      $mime =~ s{;.*$}{}s;
      $mime =~ tr{A-Z}{a-z};
      $mime =~ s{^\s+}{};
      $mime =~ s{\s+$}{};

      my $ext = {
        'application/vnd.geo+json' => 'geojson',
        'application/json' => 'json',
        'application/vnd.google-earth.kml+xml' => 'kml',
        'application/zip' => 'zip',
        'text/csv' => 'csv',
        'text/html' => 'html',
        'text/turtle' => 'ttl',
        'text/xml' => 'xml',
      }->{$mime};
      $name .= "." . $ext if defined $ext;
    }
  }

  return $name;
}

sub get_legal_json ($$) {
  my $self = $_[0];
  my $path = $self->ddsd_data_area->storage->{path}->child
      ('legal/files', $_[1]);
  my $logger = $self->{logger};
  my $el = {
    path => $path->absolute,
  };
  $logger->info ({
    type => 'open file', format => 'legal json',
    %$el,
  });
  my $file = Promised::File->new_from_path ($path);
  return $file->read_byte_string->then (sub {
    my $json = json_bytes2perl $_[0];
    unless (defined $json) {
      return $logger->throw ({
        type => 'broken file', format => 'legal json',
        %$el,
      });
    }
    $logger->info ({
      type => 'loaded file', format => 'legal json',
      %$el,
    });
    return $json;
  }, sub {
    my $e = $_[0];
    return $logger->throw ({
      type => 'failed to open file', format => 'legal json',
      %$el,
      error => '' . $e,
    });
  });
} # get_legal_json

sub main ($$$$$$$) {
  my ($self, $args, $envs, $out, $err, $in, $start_time) = @_;
  my $sub;
  my $exit = 0;
  my $opts = {};
  return Promise->resolve->then (sub {
    my $inited_time = $self->{now} = time;
    
    my $op = Getopt::Long::Parser->new; # (config => ['pass_through']);
    my $parsed = $op->getoptionsfromarray ($args,
      'cacert=s' => sub {
        $opts->{cacert} = path ($_[1]);
      },
      'insecure' => \$opts->{insecure},
      'insecure-fallback' => \$opts->{insecure_fallback},
      'json' => \$opts->{json},
      'jsonl' => \$opts->{jsonl},
      'with-source-meta' => \$opts->{with_source_meta},
      'with-file-meta' => \$opts->{with_file_meta},
      'min' => \$opts->{min},
      'all' => \$opts->{all},
      'name=s' => \$opts->{name},
      'now=s' => sub { $self->{now} = 0+$_[1] },
      'log-file=s' => sub { $self->{log_file} = $_[1] },
      'help|h' => \$opts->{help},
      'version|v' => \$opts->{version},
    );

    if (defined $self->{log_file}) {
      if ($self->{log_file} eq '-') {
        $self->{logger} = JSONLogger->new_from_filehandle ($out);
      } else {
        $self->{logger} = JSONLogger->new_from_path (path ($self->{log_file}));
      }
    } else {
      $self->{logger} = JSONLogger->new_null;
    }
    my $log_written = $self->{logger}->info ({
      type => 'initialized',
      elapsed => $inited_time - $start_time,
      reftime => $self->{now},
    });
    return $self->{logger}->throw ({
      type => 'Bad arguments',
    }) unless $parsed;
    return $log_written->catch (sub {
      my $e = $_[0];
      if (UNIVERSAL::can ($e, 'name') and $e->name eq 'Perl I/O error') {
        die "|$self->{log_file}|: Bad log file: @{[$e->message]}\n";
      } else {
        die $e;
      }
    });
  })->then (sub {
    $self->{temp_path} = $self->{root_path}->child
        ('local/ddsd/tmp', rand)->absolute;
    $self->{temp_storage} = FSStorage->new_from_path ($self->{temp_path});
    $self->{logger}->info ({
      type => 'Set temporary directory',
      path => '' . $self->{temp_path},
    });
    
    $sub = @$args ? shift @$args : '';
    if ($opts->{version}) {
      $sub = 'version';
    }
    if ($opts->{help}) {
      $opts->{help_command} = $sub;
      $sub = 'help';
    }
    $self->{logger}->info ({
      type => 'Start subcommand',
      subcommand => $sub,
    });
     if ($sub eq 'pull') {
       $self->{logger}->throw ({
         type => 'Bad arguments',
         args => $args,
       }) if @$args;
       require PullCommand;
       my $cmd = PullCommand->new_from_app ($self);
       return $cmd->run (
         cacert => $opts->{cacert}, insecure => $opts->{insecure},
         insecure_fallback => $opts->{insecure_fallback},
       )->then (sub {
         $exit = 12 if $cmd->has_error;
       });
     } elsif ($sub eq 'add') {
       $self->{logger}->throw ({
         type => 'Bad arguments',
         args => $args,
       }) unless @$args == 1;
       require AddCommand;
       my $cmd = AddCommand->new_from_app ($self);
       return $cmd->run (
         $args->[0],
         min => $opts->{min},
         name => $opts->{name},
         cacert => $opts->{cacert}, insecure => $opts->{insecure},
         insecure_fallback => $opts->{insecure_fallback},
       )->then (sub {
         $exit = 12 if $cmd->has_error;
       });
     } elsif ($sub eq 'use' or $sub eq 'unuse') {
       $self->{logger}->throw ({
         type => 'Bad arguments',
         args => $args,
       }) unless @$args == (($opts->{all} and $sub eq 'use') ? 1 : 2);
       require UseCommand;
       my $cmd = UseCommand->new_from_app ($self);
       return $cmd->run (
         $sub, $args->[0], $args->[1],
         all => $opts->{all},
         name => $opts->{name},
         cacert => $opts->{cacert}, insecure => $opts->{insecure},
         insecure_fallback => $opts->{insecure_fallback},
       )->then (sub {
         $exit = 12 if $cmd->has_error;
       });
     } elsif ($sub eq 'freeze') {
       $self->{logger}->throw ({
         type => 'Bad arguments',
         args => $args,
       }) unless @$args == 1;
       require FreezeCommand;
       my $cmd = FreezeCommand->new_from_app ($self);
       return $cmd->run ($args->[0]);
     } elsif ($sub eq 'ls') {
       my %args;
       if (@$args) {
         $args{data_repo_name} = shift @$args;
       }
       $self->{logger}->throw ({
         type => 'Bad arguments',
         args => $args,
       }) if @$args;
       require LsCommand;
       my $cmd = LsCommand->new_from_app ($self);
       return $cmd->run ($out, %args,
                         jsonl => $opts->{jsonl},
                         with_source_meta => $opts->{with_source_meta},
                         with_file_meta => $opts->{with_file_meta});
     } elsif ($sub eq 'legal') {
       $self->{logger}->throw ({
         type => 'Bad arguments',
         args => $args,
       }) unless @$args == 1;
       require LegalCommand;
       my $cmd = LegalCommand->new_from_app ($self);
       return $cmd->run ($out, $args->[0], json => $opts->{json});
     } elsif ($sub eq 'export') {
       $self->{logger}->throw ({
         type => 'Bad arguments',
         args => $args,
       }) unless @$args == 3;
       require ExportCommand;
       my $cmd = ExportCommand->new_from_app ($self);
       return $cmd->run ($args->[0], $args->[1], $args->[2], $out);
     } elsif ($sub eq 'help') {
       if (not defined $opts->{help_command} and @$args) {
         $opts->{help_command} = shift @$args;
       }
       require HelpCommand;
       my $cmd = HelpCommand->new_from_app ($self);
       return $cmd->run ($out, $opts->{help_command} // '');
     } elsif ($sub eq 'version') {
       require HelpCommand;
       my $cmd = HelpCommand->new_from_app ($self);
       return $cmd->run_version ($out, json => $opts->{json});
     } else {
       $self->{logger}->info ({
         type => 'bad subcommand',
         subcommand => $sub,
       });
       require HelpCommand;
       my $cmd = HelpCommand->new_from_app ($self);
       return $cmd->run ($out, '')->then (sub { $exit = 1 });
     }
  })->then (sub {
    $self->{logger}->info ({
      type => 'completed subcommand',
      subcommand => $sub,
    });
    $self->{logger}->message_completed ($exit);
    return $exit;
  });
} # main

sub cleanup ($) {
  my $self = $_[0];
  return Promise->resolve->then (sub {
    return unless defined $self->{temp_path};
    
    $self->{logger}->info ({
      type => 'Remove temporary files',
      path => '' . $self->{temp_path},
    });
    return Promised::File->new_from_path ($self->{temp_path})->remove_tree->catch (sub { });
  })->then (sub {
    return Promise->all ([
      (defined $self->{logger} ? (delete $self->{logger})->close : undef),
      delete $self->{repo_set},
      delete $self->{data_area},
      delete $self->{ddsd_data_area},
      delete $self->{temp_data_area},
    ]);
  });
} # cleanup

package App::Error;
use overload '""' => 'stringify',
    fallback => 1;

sub new ($$) {
  my $self = bless $_[1], $_[0];
} # new

sub stringify ($) {
  my $self = $_[0];
  my $error = $self->{error};
  my $msg = $error->{type};
  if (defined $error->{detail}) {
    $msg .= " ($error->{detail})";
  }
  if (defined $error->{format}) {
    $msg .= " ($error->{format})";
  }
  if (defined $error->{path}) {
    $msg .= ", path |$error->{path}|";
  }
  if (defined $error->{url}) {
    $msg .= ", URL <$error->{url}>";
  } elsif (defined $error->{source} and defined $error->{source}->{url}) {
    $msg .= ", URL <$error->{source}->{url}>";
  }
  if (defined $error->{status}) {
    $msg .= ", status " . $error->{status};
  }
  if (defined $error->{mime}) {
    $msg .= ", MIME type |" . $error->{mime} . "|";
  }
  if (defined $error->{key}) {
    $msg .= ', key "'.$error->{key}.'"';
  }
  if (defined $error->{value}) {
    $msg .= ', value "'.$error->{value}.'"';
  }
  my $m = sprintf "[%s] (%s) %s\n",
      (scalar gmtime $self->{time}),
      $self->{level},
      $msg;
  if (defined $error->{error_message}) {
    $m .= "  " . $error->{error_message} . "\n";
  }
  return $m;
} # stringify

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
