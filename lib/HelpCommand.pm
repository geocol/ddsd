package HelpCommand;
use strict;
use warnings;

use Command;
push our @ISA, qw(Command);

use ListWriter;

my $HelpText = {
  add => qq{%%DDSD%% add <url> [--name=<package>] [--insecure]

Add a package specified by a URL <url>.

Arguments

  <url>         The absolute URL of the package.

  --name=<package>
                The key of the data package to be used.  If not
                specified, determined by the data package's content or
                URL.

  --insecure    Allow fetches from an insecure source (such as plain HTTP).

}, # XXX exit code
  ls => qq{%%DDSD%% ls [<package>] [--jsonl] [--with-source-meta] [--with-item-meta]

Show list of data packages or files.

Arguments

  <package>     The key of a data package.

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
#XXX  export  Export files of a package
#XXX  help    Show usage
#XXX  freeze  Freeze the version of the files of a package
#XXX  pull    Update files to the latest version
  use => qq{%%DDSD%% use <package> {<id>|--all} [--name=<filename>] [--insecure]

Activate a file of ID <id> in package <package>.  If the file is not
available, it is fetched from the server.

Options

  <package>     The key of a data package.

  <id>          The ID of a file in the data package.  The file is selected.

                  file:id:{id}   A CKAN resource whose |id| is {id}.
                  file:n:{name}  A file defined in a packref file.

  --all         All the files in the data package is selected.  Either <id>
                or |--all| is required.

  --name=<filename>
                Specify the name for the specified file, used in the
                files directory for the package.

  --insecure    Allow fetches from an insecure source (such as plain HTTP).

}, # XXX exit code
  unuse => qq{%%DDSD%% unuse <package> <id>

Deactivate a file of ID <id> in package <package>.

Options

  <package>     The key of a data package.

  <id>          The ID of a file in the data package.  The file is selected.

                  file:id:{id}   A CKAN resource whose |id| is {id}.
                  file:n:{name}  A file defined in a packref file.

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

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
