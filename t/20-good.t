#!perl -T

package Dongs;

sub new;

package main;

use strict;
use warnings;

use Test::More tests => 56 * 8;

BEGIN { delete $ENV{PERL_INDIRECT_PM_DISABLE} }

my ($obj, $pkg, $cb, $x, @a);
our $y;
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
$obj = $pkg->$cb(qw/foo bar baz/);
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
#### $] < 5.010 # use feature 'state'; state $z
meh $z;
#### $] < 5.010 # use feature 'state'; state $z
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
#### $] < 5.010 # use feature 'state'; state $z
print $z;
#### $] < 5.010 # use feature 'state'; state $z
print $z "hlagh\n";
####
print STDOUT "bananananananana\n";
####
$x->foo($pkg->$cb)
####
$obj = "apple ${\(new Hlagh)} pear"
####
$obj = "apple @{[new Hlagh]} pear"
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
