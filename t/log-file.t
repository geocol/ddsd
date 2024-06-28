use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('pull', additional => ['--log-file', '-'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      {
        my $item = $r->{jsonl}->[0];
        is $item->{level}, 'info';
        ok $item->{time};
        ok $item->{error}->{type}, 'initialized';
      }
      {
        my $item = $r->{jsonl}->[-2];
        is $item->{level}, 'info';
        is $item->{error}->{type}, 'completed';
        is $item->{error}->{value}, 0;
      }
    } $current->c;
  });
} n => 7, name => 'stdout';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('pull', additional => ['--log-file', 'hoge'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "hoge", jsonl => sub {
         my $jsonl = shift;
         {
           my $item = $jsonl->[0];
           is $item->{level}, 'info';
           ok $item->{time};
           ok $item->{error}->{type}, 'initialized';
         }
         {
           my $item = $jsonl->[-2];
           is $item->{level}, 'info';
           is $item->{error}->{type}, 'completed';
           is $item->{error}->{value}, 0;
         }
       }},
    ]);
  });
} n => 9, name => 'file';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('pull', additional => ['--log-file', 'hoge/fuga/abc'], jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 0;
    } $current->c;
    return $current->check_files ([
      {path => "hoge/fuga/abc", jsonl => sub {
         my $jsonl = shift;
         {
           my $item = $jsonl->[0];
           is $item->{level}, 'info';
           ok $item->{time};
           ok $item->{error}->{type}, 'initialized';
         }
         {
           my $item = $jsonl->[-2];
           is $item->{level}, 'info';
           is $item->{error}->{type}, 'completed';
           is $item->{error}->{value}, 0;
         }
       }},
    ]);
  });
} n => 9, name => 'file in new directory';

Test {
  my $current = shift;
  return $current->prepare ({}, {})->then (sub {
    return $current->run ('pull', additional => ['--log-file', 'config'], jsonl => 1, stderr => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      isnt $r->{exit_code}, 0;
      isnt $r->{exit_code}, 12;
      is 0+@{$r->{jsonl}}, 0;
      like $r->{stderr}, qr{config};
      like $r->{stderr}, qr{Bad log file: Is a directory};
    } $current->c;
    return $current->check_files ([
      {path => "local", is_none => 1},
    ]);
  });
} n => 6, name => 'log file error';

Test {
  my $current = shift;
  return $current->prepare (undef, {})->then (sub {
    return $current->run ('pull', jsonl => 1);
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->{exit_code}, 0;
      is 0+@{$r->{jsonl}}, 0;
    } $current->c;
  });
} n => 2, name => 'no --log-file';

Run;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
