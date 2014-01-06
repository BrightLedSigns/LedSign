#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 3;

BEGIN {
    use_ok( 'LedSign::Mini' ) || print "Bail out!\n";
    use_ok( 'LedSign::M500' ) || print "Bail out!\n";
    use_ok( 'LedSign::BB' ) || print "Bail out!\n";
}
diag( "\nTesting LedSign::Mini $LedSign::Mini::VERSION, Perl $], $^X" );
diag( "Testing LedSign::M500 $LedSign::M500::VERSION, Perl $], $^X" );
diag( "Testing LedSign::BB $LedSign::BB::VERSION, Perl $], $^X" );
