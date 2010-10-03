#!perl

use strict;
use warnings;

sub skipall {
 my ($msg) = @_;
 require Test::More;
 Test::More::plan(skip_all => $msg);
}

use Config qw/%Config/;

BEGIN {
 my $force = $ENV{PERL_INDIRECT_TEST_THREADS} ? 1 : !1;
 skipall 'This perl wasn\'t built to support threads'
                                                    unless $Config{useithreads};
 skipall 'perl 5.13.4 required to test thread safety'
                                                unless $force or $] >= 5.013004;
}

use threads;

use Test::More;

BEGIN {
 delete $ENV{PERL_INDIRECT_PM_DISABLE};
 require indirect;
 skipall 'This indirect isn\'t thread safe' unless indirect::I_THREADSAFE();
 plan tests => 1;
 defined and diag "Using threads $_" for $threads::VERSION;
}

sub run_perl {
 my $code = shift;

 my $SystemRoot   = $ENV{SystemRoot};
 local %ENV;
 $ENV{SystemRoot} = $SystemRoot if $^O eq 'MSWin32' and defined $SystemRoot;

 system { $^X } $^X, '-T', map("-I$_", @INC), '-e', $code;
}

SKIP:
{
 skip 'Fails on 5.8.2 and lower' => 1 if $] <= 5.008002;

 my $status = run_perl <<' RUN';
  my ($code, @expected);
  BEGIN {
   $code = 2;
   @expected = qw/X Z/;
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
