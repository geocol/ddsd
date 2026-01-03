package HelpCommand;
use strict;
use warnings;

use Command;
push our @ISA, qw(Command);

use ListWriter;

my $HelpText = {
  add => qq{%%DDSD%% [<options>] add <url> [--single-file] [--name=<package>] [--insecure] [--forced-encoding=<charset>]

Add a package specified by the URL <url> to the local data repository
set.

Arguments

  <options>     Zero or more common options.  See |ddsd help|.

  <url>         The absolute URL of the package, as a UTF-8 text.

  --forced-encoding=<charset>
                The character encoding used to decode unlabelled file names
                and comments in archive files (such as non-UTF-8-flagged
                ZIP file names).  Defaulted to auto-detection.

  --insecure    Allow fetches from an insecure source (such as plain HTTP).

  --name=<package>
                The key of the data package to be used, as a UTF-8
                text.  If not specified, determined by the data
                package's content or URL.

  --single-file Add the URL as a single file (as oppose to as a package
                manifest).

}, # XXX exit code
  ls => qq{%%DDSD%% [<options>] ls [<package>] [--jsonl] [--with-source-meta] [--with-item-meta]

Show the list of data packages in the local data repository or files
in the package <package>.

Arguments

  <options>     Zero or more common options.  See |ddsd help|.

  <package>     The key of a data package, as a UTF-8 text.

                If <package> is omitted, the list of the data packages
                available in the current working directory is shown.

                If <package> is specified, the list of files in the
                data package is shown.

  --jsonl       Output the list in JSON Lines format.

  --with-item-meta
                Output the computed metadata for items.  Only applicable
                when <package> is specified.

  --with-source-meta
                Output the metadata from the package source file (e.g.
                CKAN package file), if any.  Only applicable when
                <package> is specified.

Output

  The list is printed to the standard output.

  When <package> is omitted:

    If |--jsonl| is specified, a JSON object with the following
    name/value pairs representing a data package in the current
    working directory is printed as a line:

      data_package_key
                The key of the data package.
      path      The path to the directory for the data package, if any.

    Otherwise, a line represents the key of a data package and the
    path to the directory for the data package, if any.

  When <package> is specified:

    If |--jsonl| is specified, a JSON object representing an item in
    the specified data package is printed as a line.

    Otherwise, a set of lines represents an item in the specified data
    package.

},
  export => qq{%%DDSD%% [<options>] export <type> <package> <out-path>

Export files of the package <package>.

Options

  <options>     Zero or more common options.  See |ddsd help|.

  <type>        The format of the output.

                  mirrorzip      A mirrorzip file.

  <package>     The key of a data package, as a UTF-8 text.

  <out-path>    The path to the output file, as a UTF-8 text.  Any
                existing file is overridden.  The directory for the
                file is created, if necessary.

If <type> is |mirrorzip|, a ZIP archive file that is a snapshot copy
of the current version of the package <package> and can be used in the
mirror data package repository is created.

},
#XXX  help    Show usage
  freeze => qq{%%DDSD%% [<options>] freeze <package>

Freeze the version of the files of the package <package>.

Options

  <options>     Zero or more common options.  See |ddsd help|.

  <package>     The key of a data package, as a UTF-8 text.

The files in the package <package> is fixed to the current snapshot
copies of the files by specifying the SHA-256 hashes of the files to
the package list for the local data repository set,
i.e. |config/ddsd/packages.json|.  Any subsequent |ddsd pull| or
similar command invocations will not change the fixed files.

},
#XXX  pull    Update files to the latest version
  use => qq{%%DDSD%% [<options>] use <package> {<id>|--all} [--name=<filename>] [--insecure]

Activate a file of ID <id> in the package <package>.  If the file is
not available in the local data repository set, it is fetched from the
remote server.

Options

  <options>     Zero or more common options.  See |ddsd help|.

  <package>     The key of a data package, as a UTF-8 text.

  <id>          The ID of a file in the data package, as a UTF-8 text.
                The ID of the files in the data package can be listed
                by |ddsd ls| command.

  --all         All the files in the data package is selected.  Either <id>
                or |--all| is required.

  --name=<filename>
                Specify the name for the specified file, used in the
                files directory for the package, as a UTF-8 text.

  --insecure    Allow fetches from an insecure source (such as plain HTTP).

}, # XXX exit code
  unuse => qq{%%DDSD%% [<options>] unuse <package> <id>

Deactivate a file of ID <id> in the package <package>.

Options

  <options>     Zero or more common options.  See |ddsd help|.

  <package>     The key of a data package, as a UTF-8 text.

  <id>          The ID of a file in the data package, as a UTF-8 text.
                The ID of the files in the data package can be listed
                by |ddsd ls| command.

},
#XXX  version Describe about ddsd
};

sub run ($$$) {
  my ($self, $out, $sub) = @_;
  my $outer = ListWriter->new_from_filehandle ($out);

  my $ddsd = $self->app->logger->ddsd_path_string;

  # XXXX locale
  if (defined $sub and defined $HelpText->{$sub}) {
    my $text = $HelpText->{$sub};
    $text =~ s/%%DDSD%%/$ddsd/g;
    $outer->formatted ($text);
  } else {
    $outer->formatted ("Usage: $ddsd <command> <args>\n\n");
    $outer->formatted ("Arguments

  <command>     The subcommands to run.  One of the followings:

    add         Add a data package
    export      Export files of a data package
    help        Show usage of ddsd
    freeze      Freeze the version of the files of a data package
    legal       Show legal information of a data package
    ls          Show list of data packages or files
    pull        Update files to the latest version
    unuse       Deactivate a file in data package
    use         Activate a file in data package
    version     Describe about ddsd

  --log-file=<path>
                The path to the log file.  If specified, log file is
                generated.  Specify |-| for the standard output,
                |/dev/stderr| for the standard error output.

  Run:

    \$ $ddsd help <command>

  ... to show about a specific command.

  For command-specific arguments, see command's help.

Environment variables

  http_proxy, https_proxy, no_proxy
                The proxy configuration.

Exit statuses

  0             The command has been successfully completed.
  12            The command has been done, but some of files or metadata
                are not available.
  Otherwise     There are something wrong.

");
  }
  
  return $outer->close;
} # run

sub run_version ($$;%) {
  my ($self, $out, %args) = @_;
  my $outer = ListWriter->new_from_filehandle ($out);
  if ($args{json}) {
    $outer->item ({
      name => 'ddsd',
      path => $self->app->logger->ddsd_path_string,
      perl_script_path => $0,
      perl_version => (sprintf '%vd', $^V),
    });
  } else {
    $outer->formatted ("ddsd\n");
  }
  return $outer->close;
} # run

1;

=head1 LICENSE

Copyright 2024-2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
