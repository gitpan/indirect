#!perl -T

package Dongs;

sub new;

package main;

use strict;
use warnings;

my ($tests, $reports);
BEGIN {
 $tests   = 61;
 $reports = 69;
}

use Test::More tests => 3 * (4 * $tests + $reports) + 4;

BEGIN { delete $ENV{PERL_INDIRECT_PM_DISABLE} }

my ($obj, $x);
our ($y, $bloop);

sub expect {
 my ($expected) = @_;

 die unless $expected;

 map {
  my ($meth, $obj, $file, $line) = @$_;
  $meth = quotemeta $meth;
  $obj  = ($obj =~ /^\s*\{/) ? "a block" : "object \"\Q$obj\E\"";
  $file = '\(eval \d+\)' unless defined $file;
  $line = '\d+'          unless defined $line;
  qr/^Indirect call of method "$meth" on $obj at $file line $line/
 } eval $expected;
}

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
   my ($code, $expected) = split /^-{4,}$/m, $_, 2;
   my @expected = expect($expected);

   skip "$_: $skip" => 3 * (4 + @expected) if eval $skip;

   {
    try "return; $prefix; use indirect; $code";
    is $@,     '', "use indirect: $code";
    is @warns, 0,  'correct number of reports';

    try "return; $prefix; no indirect; $code";
    is $@,     '',        "no indirect: $code";
    is @warns, @expected, 'correct number of reports';
    for my $i (0 .. $#expected) {
     like $warns[$i], $expected[$i], "report $i is correct";
    }
   }

   {
    local $_ = $_;
    s/Hlagh/Dongs/g;
    my ($code, $expected) = split /^-{4,}$/m, $_, 2;
    my @expected = expect($expected);

    try "return; $prefix; use indirect; $code";
    is $@,     '', "use indirect, defined: $code";
    is @warns, 0,  'correct number of reports';

    try "return; $prefix; no indirect; $code";
    is $@,     '',        "no indirect, defined: $code";
    is @warns, @expected, 'correct number of reports';
    for my $i (0 .. $#expected) {
     like $warns[$i], $expected[$i], "report $i is correct";
    }
   }

   {
    my $code = $code;
    $code =~ s/\$/\$ \n\t /g;

    try "return; $prefix; use indirect; $code";
    is $@,     '', "use indirect, spaces: $code";
    is @warns, 0,  'correct number of reports';

    try "return; $prefix; no indirect; $code";
    is $@,     '',        "no indirect, spaces: $code";
    is @warns, @expected, 'correct number of reports';
    for my $i (0 .. $#expected) {
     like $warns[$i], $expected[$i], "report $i is correct";
    }
   }
  }
 }
}

eval {
 my @warns;
 {
  local $SIG{__WARN__} = sub { push @warns, @_ };
  eval "return; no indirect 'hlagh'; \$obj = new Hlagh1;";
 }
 is        $@,      '',  'no indirect "hlagh" didn\'t croak';
 is        @warns,  1,   'only one warning';
 my $warn = shift @warns;
 like      $warn,   qr/^Indirect call of method "new" on object "Hlagh1"/,
                         'no indirect "hlagh" enables the pragma';
 is_deeply \@warns, [ ], 'nothing more';
}

__DATA__

$obj = new Hlagh;
----
[ 'new', 'Hlagh' ]
####
$obj = new Hlagh if 0;
----
[ 'new', 'Hlagh' ]
####
$obj = new Hlagh();
----
[ 'new', 'Hlagh' ]
####
$obj = new Hlagh(1);
----
[ 'new', 'Hlagh' ]
####
$obj = new Hlagh(1, 2);
----
[ 'new', 'Hlagh' ]
####
$obj = new        Hlagh            ;
----
[ 'new', 'Hlagh' ]
####
$obj = new        Hlagh     (      )      ;
----
[ 'new', 'Hlagh' ]
####
$obj = new        Hlagh     (      1        )     ;
----
[ 'new', 'Hlagh' ]
####
$obj = new        Hlagh     (      1        ,       2        )     ;
----
[ 'new', 'Hlagh' ]
####
$obj = new    
                      Hlagh		
        ;
----
[ 'new', 'Hlagh' ]
####
$obj = new   
                                       Hlagh     (    
                  )      ;
----
[ 'new', 'Hlagh' ]
####
$obj =
              new    
    Hlagh     (      1   
            )     ;
----
[ 'new', 'Hlagh' ]
####
$obj =
new      
Hlagh    
                   (      1        ,  
                2        )     ;
----
[ 'new', 'Hlagh' ]
####
$obj = new $x;
----
[ 'new', '$x' ]
####
$obj = new $x();
----
[ 'new', '$x' ]
####
$obj = new $x('foo');
----
[ 'new', '$x' ]
####
$obj = new $x qq{foo}, 1;
----
[ 'new', '$x' ]
####
$obj = new $x qr{foo\s+bar}, 1 .. 1;
----
[ 'new', '$x' ]
####
$obj = new $x(qw/bar baz/);
----
[ 'new', '$x' ]
####
$obj = new
          $_;
----
[ 'new', '$_' ]
####
$obj = new
             $_     (        );
----
[ 'new', '$_' ]
####
$obj = new $_      qr/foo/  ;
----
[ 'new', '$_' ]
####
$obj = new $_     qq(bar baz);
----
[ 'new', '$_' ]
####
meh $_;
----
[ 'meh', '$_' ]
####
meh $_ 1, 2;
----
[ 'meh', '$_' ]
####
meh $$;
----
[ 'meh', '$$' ]
####
meh $$ 1, 2;
----
[ 'meh', '$$' ]
####
meh $x;
----
[ 'meh', '$x' ]
####
meh $x 1, 2;
----
[ 'meh', '$x' ]
####
meh $x, 1, 2;
----
[ 'meh', '$x' ]
####
meh $y;
----
[ 'meh', '$y' ]
####
meh $y 1, 2;
----
[ 'meh', '$y' ]
####
meh $y, 1, 2;
----
[ 'meh', '$y' ]
#### $] < 5.010 # use feature 'state'; state $z
meh $z;
----
[ 'meh', '$z' ]
#### $] < 5.010 # use feature 'state'; state $z
meh $z 1, 2;
----
[ 'meh', '$z' ]
#### $] < 5.010 # use feature 'state'; state $z
meh $z, 1, 2;
----
[ 'meh', '$z' ]
####
package sploosh;
our $sploosh;
meh $sploosh::sploosh;
----
[ 'meh', '$sploosh::sploosh' ]
####
package sploosh;
our $sploosh;
meh $sploosh;
----
[ 'meh', '$sploosh' ]
####
package sploosh;
meh $main::bloop;
----
[ 'meh', '$main::bloop' ]
####
package sploosh;
meh $bloop;
----
[ 'meh', '$bloop' ]
####
package ma;
meh $bloop;
----
[ 'meh', '$bloop' ]
####
package sploosh;
our $sploosh;
package main;
meh $sploosh::sploosh;
----
[ 'meh', '$sploosh::sploosh' ]
####
new Hlagh->wut;
----
[ 'new', 'Hlagh' ]
####
new Hlagh->wut();
----
[ 'new', 'Hlagh' ]
####
new Hlagh->wut, "Wut";
----
[ 'new', 'Hlagh' ]
####
$obj = HlaghHlagh Hlagh;
----
[ 'HlaghHlagh', 'Hlagh' ]
####
$obj = HlaghHlagh Hlagh; # HlaghHlagh Hlagh
----
[ 'HlaghHlagh', 'Hlagh' ]
####
$obj = new newnew;
----
[ 'new', 'newnew' ]
####
$obj = new newnew; # new newnew
----
[ 'new', 'newnew' ]
####
$obj = feh feh;
----
[ 'feh', 'feh' ]
####
$obj = feh feh; # feh feh
----
[ 'feh', 'feh' ]
####
new Hlagh (meh $x)
----
[ 'meh', '$x' ], [ 'new', 'Hlagh' ]
####
Hlagh->new(meh $x)
----
[ 'meh', '$x' ]
####
meh { };
----
[ 'meh', '{' ]
####
meh {
 1;
};
----
[ 'meh', '{' ]
####
meh {
 1;
 1;
};
----
[ 'meh', '{' ]
####
meh { new Hlagh; 1; };
----
[ 'new', 'Hlagh' ], [ 'meh', '{' ]
####
meh { feh $x; 1; };
----
[ 'feh', '$x' ], [ 'meh', '{' ]
####
meh { feh $x; use indirect; new Hlagh; 1; };
----
[ 'feh', '$x' ], [ 'meh', '{' ]
####
meh { feh $y; 1; };
----
[ 'feh', '$y' ], [ 'meh', '{' ]
####
meh { feh $x; 1; } new Hlagh, feh $y;
----
[ 'feh', '$x' ], [ 'new', 'Hlagh' ], [ 'feh', '$y' ], [ 'meh', '{' ]
