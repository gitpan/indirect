#!perl -T

package Dongs;

sub new;

package main;

use strict;
use warnings;

use Test::More tests => 109 * 8 + 10;

BEGIN { delete $ENV{PERL_INDIRECT_PM_DISABLE} }

my ($obj, $pkg, $cb, $x, @a);
our ($y, $meth);
sub meh;
sub zap (&);

my @warns;

sub try {
 my ($code) = @_;

 @warns = ();
 {
  local $SIG{__WARN__} = sub { push @warns, @_ };
  eval $code;
 }
}

{
 local $/ = "####";
 while (<DATA>) {
  chomp;
  s/\s*$//;
  s/(.*?)$//m;
  my ($skip, $prefix) = split /#+/, $1;
  $skip   = 0  unless defined $skip;
  $prefix = '' unless defined $prefix;
  s/\s*//;

SKIP:
  {
   skip "$_: $skip" => 8 if eval $skip;

   {
    try "return; $prefix; use indirect; $_";
    is $@,     '', "use indirect: $_";
    is @warns, 0,  'no reports';

    try "return; $prefix; no indirect; $_";
    is $@,     '', "no indirect: $_";
    is @warns, 0,  'no reports';
   }

   {
    local $_ = $_;
    s/Hlagh/Dongs/g;

    try "return; $prefix; use indirect; $_";
    is $@,     '', "use indirect, defined: $_";
    is @warns, 0,  'no reports';

    try "return; $prefix; no indirect; $_";
    is $@,     '', "no indirect, defined: $_";
    is @warns, 0,  'no reports';
   }
  }
 }
}

# These tests must be run outside of eval to be meaningful.
{
 sub Zlott::Owww::new { }

 my (@warns, $hook, $desc, $id);
 BEGIN {
  $hook = sub { push @warns, indirect::msg(@_) };
  $desc = "test sort and line endings %d: no indirect construct";
  $id   = 1;
 }

 BEGIN { @warns = () }
 {
  no indirect hook => $hook;
  my @stuff = sort Zlott::Owww
          ->new;
 }
 BEGIN { is_deeply \@warns, [ ], sprintf $desc, $id++ }

 BEGIN { @warns = () }
 {
  no indirect hook => $hook;
  my @stuff = sort Zlott::Owww
               ->new;
 };
 BEGIN { is_deeply \@warns, [ ], sprintf $desc, $id++ }

 BEGIN { @warns = () }
 {
  no indirect hook => $hook;
  my @stuff = sort Zlott::Owww
                 ->new;
 }
 BEGIN { is_deeply \@warns, [ ], sprintf $desc, $id++ }

 BEGIN { @warns = () }
 {
  no indirect hook => $hook;
  my @stuff = sort Zlott::Owww
                  ->new;
 }
 BEGIN { is_deeply \@warns, [ ], sprintf $desc, $id++ }

 BEGIN { @warns = () }
 {
  no indirect hook => $hook;
  my @stuff = sort Zlott::Owww
                   ->new;
 }
 BEGIN { is_deeply \@warns, [ ], sprintf $desc, $id++ }

 BEGIN { @warns = () }
 {
  no indirect hook => $hook;
  my @stuff = sort Zlott::Owww
                     ->new;
 }
 BEGIN { is_deeply \@warns, [ ], sprintf $desc, $id++ }

 BEGIN { @warns = () }
 {
  no indirect hook => $hook;
  my @stuff = sort Zlott::Owww
                       ->new;
 }
 BEGIN { is_deeply \@warns, [ ], sprintf $desc, $id++ }

 BEGIN { @warns = () }
 {
  no indirect hook => $hook;
  my @stuff = sort Zlott::Owww
                          ->new;
 }
 BEGIN { is_deeply \@warns, [ ], sprintf $desc, $id++ }

 BEGIN { @warns = () }
 {
  no indirect hook => $hook;
  my @stuff = sort Zlott::Owww
                            ->new;
 }
 BEGIN { is_deeply \@warns, [ ], sprintf $desc, $id++ }

 BEGIN { @warns = () }
 {
  no indirect hook => $hook;
  my @stuff = sort Zlott::Owww
                             ->new;
 }
 BEGIN { is_deeply \@warns, [ ], sprintf $desc, $id++ }
}

__DATA__

$obj = Hlagh->new;
####
$obj = Hlagh->new();
####
$obj = Hlagh->new(1);
####
$obj = Hlagh->new(q{foo}, bar => $obj);
####
$obj = Hlagh   ->   new   ;
####
$obj = Hlagh   ->   new   (   )   ;
####
$obj = Hlagh   ->   new   (   1   )   ;
####
$obj = Hlagh   ->   new   (   'foo'   ,   bar =>   $obj   );
####
$obj = Hlagh
            ->
                          new   ;
####
$obj = Hlagh  

      ->   
new   ( 
 )   ;
####
$obj = Hlagh
                                       ->   new   ( 
               1   )   ;
####
$obj = Hlagh   ->
                              new   (   "foo"
  ,    bar     
               =>        $obj       );
####
$obj = new->new;
####
$obj = new->new; # new new
####
$obj = new->newnew;
####
$obj = newnew->new;
####
$obj = Hlagh->$cb;
####
$obj = Hlagh->$cb();
####
$obj = Hlagh->$cb($pkg);
####
$obj = Hlagh->$cb(sub { 'foo' },  bar => $obj);
####
$obj = Hlagh->$meth;
####
$obj =   Hlagh
   -> 
          $meth   ( 1,   2   );
####
$obj = $pkg->new   ;
####
$obj = $pkg  ->   new  (   );
####
$obj = $pkg       
           -> 
        new ( $pkg );
####
$obj = 
         $pkg
->
new        (     qr/foo/,
      foo => qr/bar/   );
####
$obj 
  =  
$pkg
->
$cb
;
####
$obj = $pkg    ->   ($cb)   ();
####
$obj = $pkg->$cb( $obj  );
####
$obj = $pkg->$cb(qw<foo bar baz>);
####
$obj = $pkg->$meth;
####
$obj 
 =
    $pkg
          ->
              $meth
  ( 1 .. 10 );
####
$obj = $y->$cb;
####
$obj =  $y
  ->          $cb   (
  'foo', 1, 2, 'bar'
);
####
$obj = $y->$meth;
####
$obj =
  $y->
      $meth   (
 qr(hello),
);
####
meh;
####
meh $_;
####
meh $x;
####
meh $x, 1, 2;
####
meh $y;
####
meh $y, 1, 2;
#### "$]" < 5.010 # use feature 'state'; state $z
meh $z;
#### "$]" < 5.010 # use feature 'state'; state $z
meh $z, 1, 2;
####
print;
####
print $_;
####
print $x;
####
print $x "oh hai\n";
####
print $y;
####
print $y "dongs\n";
#### "$]" < 5.010 # use feature 'state'; state $z
print $z;
#### "$]" < 5.010 # use feature 'state'; state $z
print $z "hlagh\n";
####
print STDOUT "bananananananana\n";
####
$x->foo($pkg->$cb)
####
$obj = "apple ${\($x->new)} pear"
####
$obj = "apple @{[$x->new]} pear"
####
$obj = "apple ${\($y->new)} pear"
####
$obj = "apple @{[$y->new]} pear"
####
$obj = "apple ${\($x->$cb)} pear"
####
$obj = "apple @{[$x->$cb]} pear"
####
$obj = "apple ${\($y->$cb)} pear"
####
$obj = "apple @{[$y->$cb]} pear"
####
$obj = "apple ${\($x->$meth)} pear"
####
$obj = "apple @{[$x->$meth]} pear"
####
$obj = "apple ${\($y->$meth)} pear"
####
$obj = "apple @{[$y->$meth]} pear"
#### # local $_ = "foo";
s/foo/return; Hlagh->new/e;
#### # local $_ = "bar";
s/foo/return; Hlagh->new/e;
#### # local $_ = "foo";
s/foo/return; Hlagh->$cb/e;
#### # local $_ = "bar";
s/foo/return; Hlagh->$cb/e;
#### # local $_ = "foo";
s/foo/return; Hlagh->$meth/e;
#### # local $_ = "bar";
s/foo/return; Hlagh->$meth/e;
#### # local $_ = "foo";
s/foo/return; $x->new/e;
#### # local $_ = "bar";
s/foo/return; $x->new/e;
#### # local $_ = "foo";
s/foo/return; $x->$cb/e;
#### # local $_ = "bar";
s/foo/return; $x->$cb/e;
#### # local $_ = "foo";
s/foo/return; $x->$meth/e;
#### # local $_ = "bar";
s/foo/return; $x->$meth/e;
#### # local $_ = "foo";
s/foo/return; $y->new/e;
#### # local $_ = "bar";
s/foo/return; $y->new/e;
#### # local $_ = "foo";
s/foo/return; $y->$cb/e;
#### # local $_ = "bar";
s/foo/return; $y->$cb/e;
#### # local $_ = "foo";
s/foo/return; $y->$meth/e;
#### # local $_ = "bar";
s/foo/return; $y->$meth/e;
####
"foo" =~ /(?{Hlagh->new})/;
####
"foo" =~ /(?{Hlagh->$cb})/;
####
"foo" =~ /(?{Hlagh->$meth})/;
####
"foo" =~ /(?{$x->new})/;
####
"foo" =~ /(?{$x->$cb})/;
####
"foo" =~ /(?{$x->$meth})/;
####
"foo" =~ /(?{$y->new})/;
####
"foo" =~ /(?{$y->$cb})/;
####
"foo" =~ /(?{$y->$meth})/;
####
exec $x $x, @a;
####
exec { $a[0] } @a;
####
system $x $x, @a;
####
system { $a[0] } @a;
####
zap { };
####
zap { 1; };
####
zap { 1; 1; };
####
zap { zap { }; 1; };
####
my @stuff = sort Hlagh
     ->new;
####
my @stuff = sort Hlagh
              ->new;
####
my @stuff = sort Hlagh
               ->new;
####
my @stuff = sort Hlagh
                ->new;
####
my @stuff = sort Hlagh
                 ->new;
####
my @stuff = sort Hlagh
                   ->new;
####
my @stuff = sort Hlagh
                     ->new;
####
my @stuff = sort Hlagh
                        ->new;
