use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('help', stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      like $r->{stdout}, qr{/ddsd};
      like $r->{stdout}, qr{\x0A\z};
      unlike $r->{stdout}, qr<\{>;
    } $current->c;
  });
} n => 4, name => 'help';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run (undef, additional => ['--help'], stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      like $r->{stdout}, qr{/ddsd};
      like $r->{stdout}, qr{\x0A\z};
      unlike $r->{stdout}, qr<\{>;
    } $current->c;
  });
} n => 4, name => '--help';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run (undef, additional => ['-h'], stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      like $r->{stdout}, qr{/ddsd};
      like $r->{stdout}, qr{\x0A\z};
      unlike $r->{stdout}, qr<\{>;
    } $current->c;
  });
} n => 4, name => '-h';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('hoge', stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 1;
      like $r->{stdout}, qr{/ddsd};
      like $r->{stdout}, qr{\x0A\z};
      unlike $r->{stdout}, qr<\{>;
    } $current->c;
  });
} n => 4, name => 'unknown command';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('help', additional => ['help'], stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      like $r->{stdout}, qr{/ddsd};
      like $r->{stdout}, qr{\x0A\z};
      unlike $r->{stdout}, qr<\{>;
    } $current->c;
  });
} n => 4, name => 'help help';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('help', additional => ['ls'], stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      like $r->{stdout}, qr{/ddsd};
      like $r->{stdout}, qr{ls <package>};
      like $r->{stdout}, qr{\x0A\z};
      unlike $r->{stdout}, qr<\{>;
    } $current->c;
  });
} n => 5, name => 'help ls';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('ls', additional => ['--help'], stdout => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      like $r->{stdout}, qr{/ddsd};
      like $r->{stdout}, qr{ls <package>};
      like $r->{stdout}, qr{\x0A\z};
      unlike $r->{stdout}, qr<\{>;
    } $current->c;
  });
} n => 5, name => 'ls --help';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
