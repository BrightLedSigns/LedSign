#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'LedSign::Mini' ) || print "Bail out!\n";
}

diag( "Testing LedSign::Mini $LedSign::Mini::VERSION, Perl $], $^X" );
