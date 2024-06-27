use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('version', stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      like $r->{stdout}, qr{ddsd};
      like $r->{stdout}, qr{\x0A\z};
      unlike $r->{stdout}, qr<\{>;
    } $current->c;
  });
} n => 4, name => 'version';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('ls', additional => ['--version'], stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      like $r->{stdout}, qr{ddsd};
      like $r->{stdout}, qr{\x0A\z};
      unlike $r->{stdout}, qr<\{>;
    } $current->c;
  });
} n => 4, name => '--version';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('ls', additional => ['-v'], stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      like $r->{stdout}, qr{ddsd};
      like $r->{stdout}, qr{\x0A\z};
      unlike $r->{stdout}, qr<\{>;
    } $current->c;
  });
} n => 4, name => '--version';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('version', additional => ['--json'], json => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is $r->{json}->{name}, 'ddsd';
      like $r->{json}->{path}, qr{/ddsd\z};
      like $r->{json}->{perl_script_path}, qr{/bin/ddsd\.pl\z};
      like $r->{json}->{perl_version}, qr{^5\.};
    } $current->c;
  });
} n => 5, name => '--json';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
