#!perl -T
use 5.008001;
use strict;
use warnings FATAL => 'all';
use Test::More;
use LedSign::Mini;
use LedSign::M500;
use LedSign::BB;
use Digest::MD5 qw(md5_hex);

plan tests => 3;

sub minisign {
    my $buf=LedSign::Mini->new();
    my $pix=$buf->queuePix(clipart =>'cross16'); 
    my $icon=$buf->queueIcon(clipart => 'smile16');
    $buf->queueMsg( data => "Plain Text", effect => 'scroll', speed => 2);
    $buf->queueMsg( data => $pix, effect => 'hold', speed => "3");
    my $check=$buf->queueMsg( data => $icon, effect => 'snow', speed => 5);
    ok($check eq "2", "LedSign::Mini queueMsg iter 3 should return 2, got [$check]");
    # use the special device name DEBUG
    my $result=$buf->sendQueue(device => 'DEBUG');
    my $length=length($result);
    my $md5=md5_hex($result); 
    my $exp="e6af1c78fad24d1e50823645c2142a53";
    ok ($md5 eq $exp,"LedSign::Mini: Data MD5 check: want [$exp] got[$md5]");
}
sub minisignclipart {
    my $clipart=LedSign::Mini::Clipart->new(type => 'pix');
    $clipart->set(name => 'heart16');
    my $data=$clipart->data; 
    my $md5=md5_hex($data);
    my $exp="0889d1561a56868a8cc4c1c52a2b1ce6";
    ok ($md5 eq $exp,
        "LedSign::Mini::Clipart Data MD5 check: want[$exp] got[$md5]");
}

minisign();
minisignclipart();
