use strict;
use warnings;
use Time::HiRes qw(time);
my $StartTime;
BEGIN { $StartTime = time }
use Path::Tiny;
use Promise;

use App;

my $app = App->new_from_path (path ("."));
my $e;
my $has_error;
my $r = Promise->resolve->then (sub {
  return $app->main (\@ARGV, \%ENV, \*STDOUT, \*STDERR, \*STDIN, $StartTime);
})->catch (sub {
  $e = $_[0];
  $has_error = 1;
})->finally (sub {
  if ($has_error) {
    return $app->cleanup->catch (sub { })->then (sub { die $e });
  } else {
    return $app->cleanup;
  }
})->finally (sub {
  undef $app;
})->to_cv->recv;
exit $r;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
