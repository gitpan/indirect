#!perl

use strict;
use warnings;

use Test::More tests => 1;

BEGIN { delete $ENV{PERL_INDIRECT_PM_DISABLE} }

sub run_perl {
 my $code = shift;

 my $SystemRoot   = $ENV{SystemRoot};
 local %ENV;
 $ENV{SystemRoot} = $SystemRoot if $^O eq 'MSWin32' and defined $SystemRoot;

 system { $^X } $^X, '-T', map("-I$_", @INC), '-e', $code;
}

{
 my $status = run_perl 'no indirect; qq{a\x{100}b} =~ /\A[\x00-\x7f]*\z/;';
 is $status, 0, 'RT #47866';
}
