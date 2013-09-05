#!perl

use strict;
use warnings;

use lib 't/lib';
use indirect::TestThreads;

use Test::Leaner tests => 1;

sub run_perl {
 my $code = shift;

 my ($SystemRoot, $PATH) = @ENV{qw<SystemRoot PATH>};
 local %ENV;
 $ENV{SystemRoot} = $SystemRoot if $^O eq 'MSWin32' and defined $SystemRoot;
 $ENV{PATH}       = $PATH       if $^O eq 'cygwin'  and defined $PATH;

 system { $^X } $^X, '-T', map("-I$_", @INC), '-e', $code;
}

SKIP:
{
 skip 'Fails on 5.8.2 and lower' => 1 if "$]" <= 5.008_002;

 my $status = run_perl <<' RUN';
  my ($code, @expected);
  BEGIN {
   $code = 2;
   @expected = qw<X Z>;
  }
  sub cb { --$code if $_[0] eq shift(@expected) || q{DUMMY} }
  use threads;
  $code = threads->create(sub {
   eval q{return; no indirect hook => \&cb; new X;};
   return $code;
  })->join;
  eval q{new Y;};
  eval q{return; no indirect hook => \&cb; new Z;};
  exit $code;
 RUN
 is $status, 0, 'loading the pragma in a thread and using it outside doesn\'t segfault';
}
