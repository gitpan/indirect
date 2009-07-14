#!perl

use strict;
use warnings;

use Test::More tests => 1;

{
 my @warns;
 {
  no indirect hook => sub { push @warns, \@_ };
  eval { meh { } };
 }
 is_deeply \@warns, [ [ '{', 'meh', $0, __LINE__-2 ] ], 'covering OP_CONST';
}
