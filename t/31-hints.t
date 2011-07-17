#!perl -T

use strict;
use warnings;

use Test::More tests => 1;

SKIP: {
 skip 'This would require extensive work to be okay with perl 5.8' => 1
                                                                if "$]" < 5.010;

 local %^H = (a => 1);

 require indirect;

 # Force %^H repopulation with an Unicode match
 my $x = "foo";
 utf8::upgrade($x);
 $x =~ /foo/i;

 my $hints = join ',',
              map { $_, defined $^H{$_} ? $^H{$_} : '(undef)' }
               sort keys(%^H);
 is $hints, 'a,1', 'indirect does not vivify entries in %^H';
}
