package ListWriter;
use strict;
use warnings;
use ArrayBuffer;
use DataView;
use Web::Encoding;
use Streams::Filehandle;
use JSON::PS;

sub new_from_filehandle ($$$) {
  my $self = bless {}, $_[0];

  $self->{ws} = Streams::Filehandle->create_writable ($_[1]);
  $self->{writer} = $self->{ws}->get_writer;
  $self->{formatter} = sub { perl2json_chars ($_[0]) . "\x0A" };
  
  return $self;
} # new_from_filehandle

sub formatter ($;$) {
  if (@_) { $_[0]->{formatter} = $_[1] }
  return $_[0]->{formatter};
} # formatter

sub _write ($$) {
  my $self = $_[0];
  my $dv = DataView->new (ArrayBuffer->new_from_scalarref (\($_[1])));
  return $self->{writer}->write ($dv);
} # _write

sub item ($$) {
  my ($self, $item) = @_;
  return $self->_write (encode_web_utf8 $self->{formatter}->($item))
} # item

sub formatted ($$) {
  my ($self, $text) = @_;
  return $self->_write (encode_web_utf8 $text)
} # formatted

sub close ($) {
  my $self = $_[0];
  return $self->{writer}->close;
} # close

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
