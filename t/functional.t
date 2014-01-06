#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use LedSign::Mini;

plan tests => 17;

sub endtoend {
    my $sign=LedSign::Mini->new(devicetype => 'sign');
    my $pix=$sign->queuePix(
        clipart => 'cross16'
    ); 
    my $icon=$sign->queueIcon(
        clipart => 'smile16'
    );
    $sign->queueMsg( data => "Plain Text", effect => 'scroll', speed => 2);
    $sign->queueMsg( data => $pix, effect => 'hold', speed => "3");
    my $check=$sign->queueMsg( data => $icon, effect => 'snow', speed => 5);
    ok($check eq "2", "Third message created should return 2, got [$check]");
    # use the special device name DEBUG
    my $result=$sign->sendQueue(device => 'DEBUG');
    my $length=length($result);
    ok ($length == 967, "Expected 967 bytes, Got $length Bytes");
    my @checksums = qw (9f 77 b7 f7 5f 78 b8 f8 a5 79 b9 f9 db fa);
    for (my $i =0; $i <= 13; $i++) {
        my $checksum=$checksums[$i];
        my $offset=($i+1)*69;
        my $byte=sprintf("%x",ord(substr($result,$offset,1)));
        ok( $checksum eq $byte, "Checksum number:${i} $byte == $checksum");
    } 
  
}
sub clipart {
    my $clipart=LedSign::Mini::Clipart->new(type => 'pix');
    $clipart->set(name => 'heart16');
    my $data=$clipart->data; 
    my $compare="000000000000000000000000000000000000000000000000000".
                "000000000000000001100011000000001001010010000001000".
                "010000100000100000001010000010000000001000000100000".
                "001000000010000000100000000100000100000000001000100".
                "0000000000101000000000000001000000000000000000000000";
    ok ($data eq $compare, "Clipart Data Matched Reference Data");
}

endtoend();
clipart();
