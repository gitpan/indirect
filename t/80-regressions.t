#!perl

use strict;
use warnings;

use Test::More tests => 1;

sub run_perl {
 my $code = shift;

 local %ENV;
 system { $^X } $^X, '-T', map("-I$_", @INC), '-e', $code;
}

{
 my $status = run_perl 'no indirect; print "a\x{100}b" =~ /\A[\x00-\x7f]*\z/;';
 is $status, 0, 'RT #47866';
}
