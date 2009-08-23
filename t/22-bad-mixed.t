#!perl -T

package Dongs;

sub new;

package main;

use strict;
use warnings;

use Test::More tests => 3 * 9;

BEGIN { delete $ENV{PERL_INDIRECT_PM_DISABLE} }

sub meh;

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
   skip "$_: $skip" => 9 if eval $skip;

   {
    try "return; $prefix; use indirect; $_";
    is $@,     '', "use indirect: $_";
    is @warns, 0,  'correct number of reports';

    try "return; $prefix; no indirect; $_";
    is $@,     '', "no indirect: $_";
    is @warns, 0,  'correct number of reports';
   }

   {
    local $_ = $_;
    s/Hlagh/Dongs/g;

    try "return; $prefix; use indirect; $_";
    is $@,     '', "use indirect, defined: $_";
    is @warns, 0,  'correct number of reports';

    try "return; $prefix; no indirect; $_";
    is $@,          '', "use indirect, defined: $_";
    is @warns,      1,  'correct number of reports';
    like $warns[0], qr/^Indirect call of method "meh" on object "Dongs" at \(eval \d+\) line \d+/, 'report 0 is correct';
   }
  }
 }
}

__DATA__

meh Hlagh->new;
####
meh Hlagh->new();
####
meh Hlagh->new, "Wut";
