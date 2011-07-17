#!perl -T

use strict;
use warnings;

sub skipall {
 my ($msg) = @_;
 require Test::More;
 Test::More::plan(skip_all => $msg);
}

use Config qw<%Config>;

BEGIN {
 my $force = $ENV{PERL_INDIRECT_TEST_THREADS} ? 1 : !1;
 skipall 'This perl wasn\'t built to support threads'
                                                    unless $Config{useithreads};
 skipall 'perl 5.13.4 required to test thread safety'
                                              unless $force or "$]" >= 5.013004;
}

use threads;

use Test::More;

BEGIN {
 delete $ENV{PERL_INDIRECT_PM_DISABLE};
 require indirect;
 skipall 'This indirect isn\'t thread safe' unless indirect::I_THREADSAFE();
 plan tests => 10 * 2 * (2 + 3);
 defined and diag "Using threads $_" for $threads::VERSION;
}

sub expect {
 my ($pkg) = @_;
 qr/^Indirect call of method "new" on object "$pkg" at \(eval \d+\) line \d+/;
}

{
 no indirect;

 sub try {
  my $tid = threads->tid();

  for (1 .. 2) {
   {
    my $class = "Coconut$tid";
    my @warns;
    {
     local $SIG{__WARN__} = sub { push @warns, @_ };
     eval 'die "the code compiled but it shouldn\'t have\n";
           no indirect ":fatal"; my $x = new ' . $class . ' 1, 2;';
    }
    like         $@ || '', expect($class),
                      "\"no indirect\" in eval in thread $tid died as expected";
    is_deeply \@warns, [ ],
                      "\"no indirect\" in eval in thread $tid didn't warn";
   }

SKIP:
   {
    skip 'Hints aren\'t propagated into eval STRING below perl 5.10' => 3
                                                           unless "$]" >= 5.010;
    my $class = "Pineapple$tid";
    my @warns;
    {
     local $SIG{__WARN__} = sub { push @warns, @_ };
     eval 'return; my $y = new ' . $class . ' 1, 2;';
    }
    is $@, '',
             "\"no indirect\" propagated into eval in thread $tid didn't croak";
    my $first = shift @warns;
    like $first || '', expect($class),
              "\"no indirect\" propagated into eval in thread $tid warned once";
    is_deeply \@warns, [ ],
         "\"no indirect\" propagated into eval in thread $tid warned just once";
   }
  }
 }
}

my @t = map threads->create(\&try), 1 .. 10;
$_->join for @t;
