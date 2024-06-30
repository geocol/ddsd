package HelpCommand;
use strict;
use warnings;
use Path::Tiny;

use Command;
push our @ISA, qw(Command);

use ListWriter;

sub _ddsd_path () {
  my $path1 = path ($0)->parent->parent->child ('ddsd');
  my $path2 = $path1->relative (".");
  my $path = (length $path1) > (length $path2) ? $path2 : $path1;
  $path = './' . $path if $path eq 'ddsd';
  return '' . $path;
} # _ddsd_path

my $HelpText = {
  add => qq{%%DDSD%% add <url> [--name=<package>]

Add a package specified by a URL <url>.

Options
  --name=<package>  The package name to be used.  If not specified,
                    determined by the package's content or URL.

}, # XXX exit code
  ls => qq{%%DDSD%% ls [<package>] [--jsonl]

Show list of data packages or files.

Arguments

  <package>  The key of a data package.

             If <package> is omitted, the list of the data packages
             available in the current working directory is shown.

             If <package> is specified, the list of files in the data
             package is shown.

  --jsonl    Output the list in JSON Lines format.

Output

  The list is printed to the standard output.

  When <package> is omitted:

    If |--jsonl| is specified, a JSON object with the following
    name/value pairs representing a data package in the current
    working directory is printed as a line:

      data_package_key    The key of the data package.
      path                The path to the directory for the data package,
                          if any.

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
#XXX  unuse   Deactivate a file in package
#XXX  use     Activate a file in package
#XXX  version Describe about ddsd
};

sub run ($$$) {
  my ($self, $out, $sub) = @_;
  my $outer = ListWriter->new_from_filehandle ($out);

  # XXXX locale
  my $ddsd = _ddsd_path;

  if (defined $sub and defined $HelpText->{$sub}) {
    my $text = $HelpText->{$sub};
    $text =~ s/%%DDSD%%/$ddsd/g;
    $outer->formatted ($text);
  } else {
    $outer->formatted ("Usage: $ddsd <command> <args>\n\n");
    $outer->formatted ("Commands:
  add     Add a package
  export  Export files of a package
  help    Show usage
  freeze  Freeze the version of the files of a package
  legal   Show legal information of a package
  ls      Show list of data packages or files
  pull    Update files to the latest version
  unuse   Deactivate a file in package
  use     Activate a file in package
  version Describe about ddsd

Run:
  \$ $ddsd help <command>
... to show about a specific command.
");
  }
  # XXX http_proxy
  
  return $outer->close;
} # run

sub run_version ($$;%) {
  my ($self, $out, %args) = @_;
  my $outer = ListWriter->new_from_filehandle ($out);
  if ($args{json}) {
    $outer->item ({
      name => 'ddsd',
      path => _ddsd_path,
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
