package LedSign::Mini;
use base qw(LedSign);
use strict;
use warnings;
use Carp;
use 5.008001;
$LedSign::Mini::VERSION="1.03";
#
# Shared Constants / Globals
#
use constant DEFAULTSERIAL =>  {
    "baudrate"   => 38400,
    "packetdelay"=> 0.25
};
use constant EFFECTMAP => {
    "hold"       => 0x41,
    "scroll"     => 0x42,
    "snow"       => 0x43,
    "flash"      => 0x44,
    "hold+flash" => 0x45
};
use constant SPEEDMAP => {
        1 => 0x31,
        2 => 0x32,
        3 => 0x33,
        4 => 0x34,
        5 => 0x35
};
use constant SLOTRANGE => ( 1 .. 8 );

sub _init {
    my $this = shift;
    my (%params) = @_;
    if ( !defined( $params{devicetype} ) ) {
        $params{devicetype}="sign";
    }
    if ( $params{devicetype} ne "sign" and $params{devicetype} ne "badge" ) {
        croak("Invalue value for [devicetype]: \"$params{devicetype}\"");
    }
    $this->{can_image}  = 1;
    $this->{device}     = $params{device};
    $this->{devicetype} = $params{devicetype};
    $this->{msgcount} = 0;
    $this->{factory}    = LedSign::Mini::Factory->new();
    return $this;
}

sub _flush {
    my $this = shift;
    $this->{msgcount} = 0;
    $this->initslots();
    $this->{factory}    = LedSign::Mini::Factory->new();
}

sub _factory {
    my $this = shift;
    return $this->{factory};
}

sub queuePix {
    my $this = shift;
    my (%params) = @_;
    if ( defined( $params{clipart} ) ) {
        my $ca = LedSign::Mini::Clipart->new(
            name => $params{clipart},
            type => "pix"
        );
        $params{data}   = $ca->data();
        $params{width}  = $ca->width();
        $params{height} = $ca->height();
    }
    if ( !defined( $params{data} ) ) {
        croak("Parameter [data] must be present");
    }
    my $pixobj = $this->_factory->pixmap(
        type       => "pixmap",
        data       => $params{data},
        height     => $params{height},
        width      => $params{width},
        devicetype => $this->{devicetype}
    );
    my $imagetag = $this->setkey($pixobj);

    # get imagetag
    return $imagetag;
}

sub queueIcon {
    my $this = shift;
    my (%params) = @_;
    if ( defined( $params{clipart} ) ) {
        my $ca = LedSign::Mini::Clipart->new(
            name => $params{clipart},
            type => "icon"
        );
        my $data = $ca->data();
        $params{data} = $ca->data();
    }
    if ( !exists( $params{data} ) ) {
        croak("Parameter [data] must be present");
    }
    my $iconobj = $this->_factory->icon(
        devicetype => $this->{devicetype},
        data       => $params{data},
    );
    my $imagetag = $this->setkey($iconobj);
    return $imagetag;
}

sub queueMsg {
    my $this = shift;
    my (%params) = @_;
    # validate parameters
    my $maxmsgs = scalar(SLOTRANGE());
    if ( $this->{msgcount} >= $maxmsgs ) {
        carp(   "Maximum message count of $maxmsgs is already"
              . " reached, discarding new message" );
        return undef;
    }
    if ( !defined( $params{data} ) ) {
        croak("Parameter [data] must be present");
    }
    if ( !defined( $params{speed} ) ) {
        $params{speed} = 4;
    }
    if ( $params{speed} !~ /^[1-5]$/ ) {
        croak("Parameter [speed] must be between 1 (slowest) and 5 (fastest)");
    }

    # effect
    if ( !defined( $params{effect} ) ) {
        $params{effect} = "scroll";
    }
    else {
        my @effects = keys(%{EFFECTMAP()});
        if ( !grep( /^$params{effect}$/, @effects ) ) {
            croak("Invalid effect value [$params{effect}]");
        }
    }
    if ( exists( $params{slot} ) ) {
        if ( $params{slot} !~ /^[1-8]$/ ) {
            croak("Parameter [slot] must be a value from 1 to 8");
        }
        else {
            $this->setslot( $params{slot} );
        }
    }
    else {
        if ( !defined( $params{slot} = $this->setslot ) ) {
            carp("Can't create message, out of slots");
            return undef;
        }

    }
    my $mobj = $this->_factory->msg(
        devicetype => $this->{devicetype},
        %params
    );
    return $mobj->{number};
}

sub getshowbits {
    my $this     = shift;
    my (@slots) = @_;
    my %BITVAL   = (
        0 => 0,
        1 => 1,
        2 => 2,
        3 => 4,
        4 => 8,
        5 => 16,
        6 => 32,
        7 => 64,
        8 => 128
    );
    if (scalar(@slots) == 0) {
        @slots = @{ $this->{'usedslots'} };
    }
    my $total = 0;
    foreach my $num (@slots) {
        $total += $BITVAL{$num};
    }
    if ($total > 0) {
        return pack( "C*", ( 0x02, 0x33, $total ) );
    } else {
        return undef;
    }
}
sub checkbaudrate {
    my $this=shift;
    my $baudrate=shift;
    if (defined($baudrate)) {
        return $baudrate;
    } else {
        return 38400
    }
}
sub checkpacketdelay {
    my $this=shift;
    my $packetdelay=shift;
    if (defined($packetdelay)) {
        return $packetdelay;
    } else {
        return 0.25;
    }
}
sub sendQueue {
    my $this = shift;
    my (%params) = @_;
    if ( !defined( $params{device} ) ) {
        croak("Must supply the device name.");
    }
    my $baudrate=$this->checkbaudrate($params{baudrate});
    my $packetdelay=$this->checkpacketdelay($params{packetdelay});

    my $serial;
    if ( $params{device} eq "DEBUG" ) {
        $serial = LedSign::Mini::SerialTest->new();
    } else {
        $serial = $this->connect(
            device   => $params{device},
            baudrate => $params{baudrate}
        );
    }
    my $runslots;
    if ( defined( $params{runslots} ) ) {
        if ( $params{runslots} eq "auto" or $params{runslots} eq "none" ) {
            $runslots = $params{runslots};
        } elsif (ref($params{runslots}) eq "ARRAY") {
            $runslots = $params{runslots};
        } else {
            croak('Parameter [runslots] must be either "auto", "none", or an array reference');
        }
    } else {
        $runslots = "auto";
    }

    # send an initial null, wakes up the sign
    $serial->write( pack( "C", 0x00 ) );

    # sleep a short while to avoid overrunning sign
    #select( undef, undef, undef, $packetdelay );
    my $count = 0;
    foreach my $msgobj ( $this->_factory->objects('msg') ) {
        # get the data
        $count++;
        # process font and image tags first
        $msgobj->{data} = $this->processTags( $msgobj->{data} );
        my @packets = $msgobj->encode( devicetype => $params{devicetype} );
        foreach my $data (@packets) {
            $serial->write($data);
            # sleep a short while to avoid overrunning sign
            select( undef, undef, undef, $packetdelay );
        }
    }
    foreach my $data ( $this->packets() ) {
        $serial->write($data);
        select( undef, undef, undef, $packetdelay );
    }
    if ( $runslots eq "auto" ) {
        $this->sendRunSlots(
            baudrate => $params{baudrate}, 
            packetdelay => $params{packetdelay},
            device => $params{device}
        );
    } elsif (ref($runslots) eq "ARRAY") {
        my @slots=$this->validateSlots(@{$runslots});
        $this->sendRunSlots(
            baudrate => $params{baudrate}, 
            packetdelay => $params{packetdelay},
            device => $params{device},
            slots  => \@slots
        );
    } elsif ($runslots eq "none") {
        $this->sendRunSlots(
            baudrate => $params{baudrate}, 
            packetdelay => $params{packetdelay},
            device => $params{device},
            slots  => [0]
        );
    } else {
        croak("Invalid value [$runslots] for parameter [runslots]");
    }

    if ($params{device} eq "DEBUG") {
        return $serial->dump();
    }
}
sub validateSlots {
    my $this=shift;
    my @slots=@_;
    my(@valid,%SEEN);
    foreach my $slot (@slots) {
        if ( !grep $slot eq $_, SLOTRANGE() ) {
            croak("Invalid slot [$slot] supplied.");
        }
        if (!$SEEN{$slot}++) {
            push(@valid,$slot);
        }
    }
    return(@valid);
}
sub sendCmd {
    my $this=shift;
    my %params=@_;
    my @validcmds=qw(runslots settime setcountdown);
    if (!exists $params{cmd}) {
        croak("Parameter cmd must be supplied to sendCmd");
    } else {
        my $cmd=$params{cmd};
    }
    my $cmd;
    if ( !grep $params{cmd} eq $_, @validcmds ) {
        croak("Invalid cmd [$params{cmd}] for sendCmd");
    } else {
        $cmd=$params{cmd};
    }
    if ($cmd eq "runslots") {
        my @runslots;
        if (ref($params{slots}) eq "ARRAY") {
           @runslots=$this->validateSlots(@{$params{slots}});
        } else {
           die("Parameter [slots] must be an array reference"); 
        }
        $this->sendRunSlots(
            baudrate => $params{baudrate}, 
            packetdelay => $params{packetdelay},
            device => $params{device},
            slots => \@runslots
        );
    } 
    if ( $cmd eq "settime" ) {
        if ( !exists( $params{value} ) ) {
            croak("No value parameter specified for settime cmd");
        }
        if ( $params{value} ne "now" and $params{value} !~ /^\d+$/ ) {
            croak("Invalid value [$params{value}] specified for settime");
        }
        if ($params{value} eq "now") {
             $params{value}=time();
        }
        my $data;
        $data=pack("C*",(0x02,0x34));
        use Time::Piece;
        my $t;
        my $value=$params{value};
        $t=Time::Piece->new($value);
        $data.=pack("C*",
          map(hex,$t->yy,$t->mon,$t->mday,$t->hour,$t->min,$t->sec,$t->_wday));
        $this->sendData(
            baudrate => $params{baudrate}, 
            packetdelay => $params{packetdelay},
            device => $params{device},
            checksum => 1,
            data => $data
        );
    }

    if ( $cmd eq "setcountdown" ) {
        if ( !exists( $params{value} ) ) {
            croak("No value parameter specified for setcountdown cmd");
        }

        if ( $params{value} !~ /^\d+$/ ) {
            croak("Invalid value [$params{value}] specified for setcountdown");
        }
        use Time::Piece;
        my $tp=Time::Piece->new();
        my $start=$tp->strptime("01/01/2000","%m/%d/%Y");
        my $then=Time::Piece->new($params{value});
        my $diff=$then-$start;
        $diff=int($diff/(60*60*24));
        # diff is now the number of days since 1/1/2000
        # send to the sign
        # a) 0x02 0x36
        # b) diff as 2 hex  0x13 0xFC = 5112
        # c) The hour, 1am = 0x01, 1pm = 0x0d
        # d) minute, hex encoded
        # e) seconds
        # f) one null byte
        # g) checksum
        my $data;
        $data=pack("C*",(0x02,0x36));
        print "diff is [$diff]\n";
        $data.=pack("n",$diff);
        $data.=pack("C*",$then->hour,$then->min,$then->sec,0x00,0x00);
        $this->sendData(
            baudrate => $params{baudrate}, 
            packetdelay => $params{packetdelay},
            device => $params{device},
            checksum => 1,
            data => $data 
        );
    }
}
sub sendData {
    my $this=shift;
    my %params=@_;
    my $data=$params{data};
    my $i;
    my $csum;
    if ( defined $params{checksum} && $params{checksum} ) {
        for (unpack("C*",$data)) {
            $i++;
            next if ($i == 1); # skip the 0x02 
            $csum+=$_;
        }
        $csum %= 256;
        $data.=pack("C",$csum);
    }
    my $baudrate=$this->checkbaudrate($params{baudrate});
    my $packetdelay=$this->checkpacketdelay($params{packetdelay});
    my $serial;
    if ( $params{device} eq "DEBUG" ) {
        $serial = LedSign::Mini::SerialTest->new();
    } else {
        $serial = $this->connect(
            device   => $params{device},
            baudrate => $params{baudrate}
        );
    }
    $serial->write($data);
    select(undef,undef,undef,$packetdelay);
}
sub sendRunSlots {
    my $this=shift;
    my %params=@_;
    my $bits = $this->getshowbits(@{$params{slots}});
    if ( $bits ) {
        $this->sendData(
            data => $bits,
            %params
        );
    } 
}
sub packets {
    my $this   = shift;
    my $blob   = join( '', @{ $this->_factory()->{chunks} } );
    my $length = length($blob);

    # pad out to an even multiple of 64 bytes
    if ( $length % 64 ) {
        my $paddedsize = $length + 64 - ( $length % 64 );
        $blob = pack( "a$paddedsize", $blob );
    }
    my $new = length($blob);

    # now split into 64 byte pieces, each one it's own packet
    my $i;
    my @packets;
    my $count = 0x0E00;
    foreach my $chunk ( unpack( "(a64)*", $blob ) ) {
        my $len = length($chunk);
        my @tosend;
        push( @tosend, 0x02, 0x31 );
        my $hcount = sprintf( "%04x", $count );
        my ( $start, $end ) = ( unpack( "(a2)*", sprintf( "%04x", $count ) ) );
        $start = hex($start);
        $end   = hex($end);
        push( @tosend, $start, $end );

        foreach my $char ( split( //, $chunk ) ) {
            push( @tosend, ord($char) );
        }
        my @slice = @tosend[ 1 .. $#tosend ];
        my $total;
        foreach my $one (@slice) {
            $total += $one;

            # my $hextotal = sprintf("0x%x",$total);
        }
        my $mod = $total % 256;
        push( @tosend, $mod );
        my $packed = pack( "C*", @tosend );
        push( @packets, $packed );
        $count += 64;
    }
    return @packets;
}

sub processTags {
    my $this    = shift;
    my $msgdata = shift;
    my $type    = $this->{devicetype};

    # font tags
    my ( $normal, $flash );
    if ( $type eq "badge" ) {
        $normal = pack( "C*", 0xff, 0x80 );
        $flash  = pack( "C*", 0xff, 0x81 );
    } else {
        $normal = pack( "C*", 0xff, 0x8f );
        $flash  = pack( "C*", 0xff, 0x8f );
    }
    $msgdata =~ s/<f:normal>/$normal/g;
    $msgdata =~ s/<f:flash>/$flash/g;

    # image tags
    #
    #
    while ( $msgdata =~ /(<i:\d+>)/g ) {
        my $imagetag   = $1;
        my $substitute = $this->getkey($imagetag);
        $msgdata =~ s/$imagetag/$substitute/g;
    }
    #
    # date/time tags
    #
    if ($type eq "badge") {
        #badge doesn't support date time tags
        $msgdata =~ s/<d:[^>]*>//g;
    } elsif ($type eq "sign") {
        my %sub = (
         '%y' => '\DY', '%d' => '\DD',
         '%m' => '\DL', '%H' => '\DH',
         '%M' => '\DM', '%S' => '\DS',
         '%1' => '\D1', '%2' => '\D2',
         '%3' => '\D3', '%4' => '\D4',
        );
        while ( $msgdata =~ /(<d:([^>]*)>)/g ) {
            my $tag=$1;
            my $origtag=$tag;
            my $contents=$2;
            while ($contents =~ s/%([^%])//) {
                my $spec=$1;
                if (exists($sub{"%$spec"})) {
                  $tag=~s/%$spec/$sub{"%$spec"}/g;
                } 
            }
            $tag=~s/^<d://g;
            $tag=~s/>$//g;
            $msgdata=~s#$origtag#$tag#g;
        }
    }
    return $msgdata;
}

package LedSign::Mini::Factory;
use base qw (LedSign::Factory);

sub _init {
    my $this = shift;
    my (%params) = @_;
    foreach my $key ( keys(%params) ) {
        $this->{$key} = $params{$key};
    }
    $this->{chunkcount}=0;
    $this->{chunkcache}={};
    $this->{chunks}= [];
    return $this;
}

sub msg {
    my $this     = shift;
    my (%params) = @_;
    my $mobj     = LedSign::Mini::Msg->new(
        %params,
        devicetype => $params{devicetype},
        factory    => $this
    );
    $this->add_object($mobj);
    return $mobj;
}

sub pixmap {
    my $this     = shift;
    my (%params) = @_;
    my $pixmap   = LedSign::Mini::Pixmap->new(
        %params,
        devicetype => $params{devicetype},
        factory    => $this
    );
    $this->add_object($pixmap);
    return $pixmap;
}

sub icon {
    my $this     = shift;
    my (%params) = @_;
    my $icon     = LedSign::Mini::Icon->new(
        %params,
        devicetype => $params{devicetype},
        factory    => $this
    );
    $this->add_object($icon);
    return $icon;
}

sub add_chunk {
    my $this    = shift;
    my %params  = @_;
    my $chunk   = $params{chunk};
    my $objtype = $params{objtype};
    my $return;

    # if we've seen a chunk like this before, pass back the existing
    # reference instead of storing a new image
    if ( exists( $this->{chunkcache}{$chunk} ) ) {
        $return = $this->{chunkcache}{$chunk};
    }
    else {
        my $sequence = 0;
        foreach my $thing ( @{ $this->{chunks} } ) {
            my $len = length($thing);
            if ( $len > 32 ) {
                $sequence += 2;
            }
            else {
                $sequence += 1;
            }
        }
        push( @{ $this->{chunks} }, $chunk );
        my $msgref;
        if ( $objtype eq "pixmap" ) {
            $msgref = 0x8000 + $sequence;
        } elsif ( $objtype eq "icon" ) {
            $msgref = 0xc000 + $sequence;
        } else {
            die("argh! objtype is [$objtype]\n");
        }
        $return = pack( "n", $msgref );
        $this->{chunkcache}{$chunk} = $return;
    }
    return ($return);
}

#
# object to hold a message and it's associated data and parameters
#
package LedSign::Mini::Msg;
use strict;
use warnings;

#our @CARP_NOT = qw(LedSign::Mini);
sub new {
    my $that     = shift;
    my $class    = ref($that) || $that;
    my (%params) = @_;
    $params{objtype} = 'msg';
    my $this = {};
    bless $this, $class;
    foreach my $key ( keys(%params) ) {
        $this->{$key} = $params{$key};
    }
    return $this;
}

sub encode {
    my $this     = shift;
    my (%params) = @_;
    my $number   = $this->{number};
    my $msgdata  = $this->{data};
    my $effect = LedSign::Mini::EFFECTMAP()->{$this->{effect}};

    if ( !$effect ) {
        $effect = 0x35;
    }
    my $speed = LedSign::Mini::SPEEDMAP()->{$this->{speed}};
    if ( !$speed ) {
        $speed = 0x35;
    }
    my $alength = length($msgdata);
    $msgdata = pack( "Z255", $msgdata );
    my @encoded;
    my $end;
    my @endmem = ( 0x00, 0x40, 0x80, 0xc0 );
    my $slot = $this->{slot};
    foreach my $i ( 0 .. 3 ) {
        my $start = 0x06 + ( $slot - 1 );

        #my $start=0x06+($number-1);
        my $chunk;
        if ( $i == 0 ) {
            $chunk = substr( $msgdata, 0, 60 );
        }
        else {
            my $offset = 60 + ( 64 * ( $i - 1 ) );
            $chunk = substr( $msgdata, $offset, 64 );
        }
        $end = $endmem[$i];
        my $csize = length($chunk) + 2;
        my (@tosend) = ( 0x02, 0x31, $start, $end );
        if ( $i == 0 ) {
            push( @tosend, ( $speed, 0x31, $effect, $alength ) );
        }
        foreach my $char ( split( //, $chunk ) ) {
            push( @tosend, ord($char) );
        }
        my $aend  = $#tosend;
        my @slice = @tosend[ 1 .. $#tosend ];
        my $total;
        foreach my $one (@slice) {
            $total += $one;
            my $hextotal = sprintf( "0x%x", $total );
        }
        my $mod = $total % 256;
        my $hmod = sprintf( "0x%x", $mod );

        push( @tosend, $mod );
        my $packed = pack( "C*", @tosend );
        push( @encoded, $packed );
    }
    return @encoded;
}

package LedSign::Mini::Image;
use strict;
use warnings;
use POSIX qw (ceil);

sub new {
    my $that     = shift;
    my $class    = ref($that) || $that;
    my (%params) = @_;
    my $this     = {};
    bless $this, $class;
    foreach my $key ( keys(%params) ) {
        $this->{$key} = $params{$key};
    }
    $this->_init;
    my $msgref = $this->load;
    $this->{msgref} = $msgref;
    return $this;
}

sub _factory {
    my $this = shift;
    return $this->{factory};
}

sub load {
    my $this       = shift;
    my $devicetype = $this->{devicetype};
    my $data       = $this->{data};
    $data =~ s/[^01]//g;
    my $tilesize = $this->{tilesize};
    my $width    = $this->{width};
    my $height   = $this->{height};
    my $length   = length($data);
    my $expected = $width * $height;
    if ( $length < $width * $height ) {
        carp(   "Expected [$expected] bits, got [$length] bits...padding "
              . "data with zeros" );
        $data .= "0" x ( $expected - $length );
    }
    my $padding = $width % $tilesize ? $tilesize - ( $width % $tilesize ) : 0;

    # pad the image width to an equal multiple of the tilesize
    my $tiles = ceil( $width / $tilesize );
    my $final;
    foreach my $tile ( 1 .. $tiles ) {
        foreach my $row ( 1 .. $tilesize ) {
            my $rowstart = ( $row - 1 ) * ($width);
            my $offset = $rowstart + ( ( $tile - 1 ) * $tilesize );
            my $chunk;
            my $chunkstart = ( ( $tile - 1 ) * $tilesize );
            my $chunkend = $chunkstart + ($tilesize);
            if ( $row <= $height ) {
                if ( $chunkend <= $width ) {
                    $chunk = substr( $data, $offset, $tilesize );
                }
                else {
                    $chunk = substr( $data, $offset, $width - $chunkstart );
                    $chunk .= "0" x ( $tilesize - length($chunk) );
                }
            }
            else {
                $chunk = "0" x ($tilesize);
            }
            $final .= pack( "B16", $chunk );
        }
    }
    my $format = $this->{packformat};
    my $msgref;
    foreach my $chunk ( unpack( "($format)*", $final ) ) {
        $msgref .= $this->_factory->add_chunk(
            chunk   => $chunk,
            objtype => $this->{objtype}
        );
    }
    return $msgref;
}

#
# object to hold a pixmap and it's associated data and parameters
#
package LedSign::Mini::Pixmap;
use strict;
use warnings;
use base qw (LedSign::Mini::Image);

#our @CARP_NOT = qw(LedSign::Mini);
use Carp;

sub _init {
    my $this   = shift;
    my %params = @_;
    $this->{objtype} = "pixmap";
    if ( !defined( $this->{height} ) ) {
        croak("Height must exist,and be 1 or greater");
    }
    if ( defined( $this->{height} ) && $this->{height} < 1 ) {
        croak("Height must be greater than 1");
    }
    if ( !defined( $this->{width} ) ) {
        croak("Width must exist,and be between 1 and 256");
    }
    if ( defined( $this->{width} )
        && ( $this->{width} < 1 or $this->{width} > 256 ) )
    {
        croak("Width must be between 1 and 256");
    }
    if ( !defined( $this->{data} ) ) {
        croak("Parameter [data] must be present");
    }
    if ( !defined( $this->{devicetype} ) ) {
        croak("Parameter [devicetype] must be present");
    }
    if ( $this->{devicetype} eq "sign" ) {
        $this->{tilesize}   = 16;
        $this->{packformat} = "a32";
    }
    elsif ( $this->{devicetype} eq "badge" ) {
        $this->{tilesize}   = 12;
        $this->{packformat} = "a24";
    }
    else {
        die("no devicetype");
    }
    return $this;
}

#
# object to hold a icon and it's associated data and parameters
#
package LedSign::Mini::Icon;
use strict;
use warnings;
use base qw (LedSign::Mini::Image);

#our @CARP_NOT = qw(LedSign::Mini);
use Carp;

sub _init {
    my $this = shift;
    $this->{objtype} = "icon";
    if ( !defined( $this->{data} ) ) {
        croak("Parameter [data] must be present");
    }
    if ( !defined( $this->{devicetype} ) ) {
        croak("Parameter [devicetype] must be present");
    }
    if ( $this->{devicetype} eq "sign" ) {
        $this->{tilesize}   = "16";
        $this->{height}     = "16";
        $this->{width}      = "32";
        $this->{packformat} = "a64";
    }
    elsif ( $this->{devicetype} eq "badge" ) {
        $this->{tilesize}   = "12";
        $this->{width}      = "24";
        $this->{height}     = "12";
        $this->{packformat} = "a48";
    }
    else {
        die("bad devicetype");
    }
    return $this;
}

package LedSign::Mini::Clipart;
use strict;
use warnings;

#our @CARP_NOT = qw(LedSign::Mini);
use Carp;

sub new {
    my $that     = shift;
    my $class    = ref($that) || $that;
    my (%params) = @_;
    my $this     = {};
    bless $this, $class;
    if ( !defined( $params{type} ) ) {
        croak(
"Parameter [type] must be supplied, valid values are [pix] or [icon]"
        );
    }
    if ( $params{type} ne "pix" and $params{type} ne "icon" ) {
        croak("Parameter [type] invalid, valid values are [pix] or [icon]");
    }
    $this->{type} = $params{type};
    if ( defined( $params{name} ) ) {
        $this->{name} = $params{name};
        if ( $this->{hashref} = $this->set( name => $params{name} ) ) {
            return $this;
        }
        else {
            croak("No clipart named [$params{name}] exists");
        }
    }
    else {
        return $this;
    }
}

sub data {
    my $this    = shift;
    my $hashref = $this->{hashref};
    my $data    = $$hashref{'data'};
    my $bits;
    foreach my $one ( unpack( "(A2)*", $data ) ) {
        $bits .= unpack( "B8", pack( "C", hex($one) ) );
    }
    my $len = length($bits);
    return $bits;
}

sub width {
    my $this    = shift;
    my $hashref = $this->{hashref};
    return $$hashref{'width'};
}

sub height {
    my $this    = shift;
    my $hashref = $this->{hashref};
    return $$hashref{'height'};
}

sub hash {
    my $this        = shift;
    my %params      = @_;
    my $name        = $params{name};
    my %CLIPART_PIX = (
        zen16 => {
            width  => 16,
            height => 16,
            data =>
              '07e00830100820045c067e02733273327f027f863ffc1ff80ff007e000000000'
        },
        zen12 => {
            width  => 12,
            height => 12,
            data   => '0e00318040404040f120f860dfe07fc07fc03f800e000000'
        },
        cross16 => {
            width  => 16,
            height => 16,
            data =>
              '0100010001000100010002800440f83e04400280010001000100010001000100'
        },
        circle16 => {
            width  => 16,
            height => 16,
            data =>
              '07e00ff01ff83ffc7ffe7ffe7ffe7ffe7ffe7ffe3ffc1ff80ff007e000000000'
        },
        questionmark12 => {
            width  => 12,
            height => 12,
            data   => '1f003f8060c060c061800300060006000600000006000600'
        },
        smile12 => {
            width  => 12,
            height => 12,
            data   => '0e003180404051408020802091204e40404031800e000000'
        },
        phone16 => {
            width  => 16,
            height => 16,
            data =>
              '000000003ff8fffee00ee44ee44e0fe0183017d017d037d8600c7ffc00000000'
        },
        rightarrow12 => {
            width  => 12,
            height => 12,
            data   => '000000000000010001807fc07fe07fc00180010000000000'
        },
        heart12 => {
            width  => 12,
            height => 12,
            data   => '000071c08a208420802080204040208011000a0004000000'
        },
        heart16 => {
            width  => 16,
            height => 16,
            data =>
              '00000000000000000c6012902108202820081010101008200440028001000000'
        },
        square12 => {
            width  => 12,
            height => 12,
            data   => 'fff0fff0fff0fff0fff0fff0fff0fff0fff0fff0fff0fff0'
        },
        handset16 => {
            width  => 16,
            height => 16,
            data =>
              '00003c003c003e0006000600060c065006a0075006503e603c003c0000000000'
        },
        leftarrow16 => {
            width  => 16,
            height => 16,
            data =>
              '00000000000004000c001c003ff87ff83ff81c000c0004000000000000000000'
        },
        circle12 => {
            width  => 12,
            height => 12,
            data   => '0e003f807fc07fc0ffe0ffe0ffe07fc07fc03f800e000000'
        },
        questionmark16 => {
            width  => 16,
            height => 16,
            data =>
              '000000000fc01fe0303030303030006000c00180030003000000030003000000'
        },
        smile16 => {
            width  => 16,
            height => 16,
            data =>
              '07c01830200840044c648c62800280028002882247c440042008183007c00000'
        },
        leftarrow12 => {
            width  => 12,
            height => 12,
            data   => '000000000000080018003fe07fe03fe01800080000000000'
        },
        rightarrow16 => {
            width  => 16,
            height => 16,
            data =>
              '000000000000008000c000e07ff07ff87ff000e000c000800000000000000000'
        },
        music16 => {
            width  => 16,
            height => 16,
            data =>
              '000001000180014001200110011001200100010007000f000f000e0000000000'
        },
        phone12 => {
            width  => 12,
            height => 12,
            data   => '00007fc0ffe0c060c060ca601f0031802e806ec0c060ffe0'
        },
        music12 => {
            width  => 12,
            height => 12,
            data   => '000008000c000a0009000880088039007800780070000000'
        },
        cross12 => {
            width  => 12,
            height => 12,
            data   => '04000400040004000a00f1e00a0004000400040004000000'
        },
        handset12 => {
            width  => 12,
            height => 12,
            data   => 'f000f80018001800180018201b401c801940f880f0000000'
        },
        square16 => {
            width  => 16,
            height => 16,
            data =>
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
        },
    );
    my %CLIPART_ICONS = (
        cross16 => {
            width  => 32,
            height => 16,
            data =>
              '01000100010001000100010001000100010002800280044004400820F83EF01E'
              . '0440082002800440010002800100010001000100010001000100010001000100'
        },
        heart16 => {
            width  => 32,
            height => 16,
            data =>
              '000000000000000000001C70000022880C604104129040242108402420284004'
              . '2008200810102008101010100820082004400440028002800100010000000000'
        },
        leftarrow16 => {
            width  => 32,
            height => 16,
            data =>
              '000000000000000000000000040000000C0004001C000C003FF81C007FF83FF8'
              . '3FF87FF81C003FF80C001C0004000C0000000400000000000000000000000000'
        },
        rightarrow16 => {
            width  => 32,
            height => 16,
            data =>
              '0000000000000000000000000080000000C0008000E000C07FF000E07FF87FF0'
              . '7FF07FF800E07FF000C000E0008000C000000080000000000000000000000000'
        },
        handset16 => {
            width  => 32,
            height => 16,
            data =>
              '000000003C003C003C003C003E003E000600060006000600060C06000650064C'
              . '06A006B007500748065006503E603E203C003C003C003C000000000000000000'
        },
        phone16 => {
            width  => 32,
            height => 16,
            data =>
              '0000000000003FF83FF8FFFEFFFEE00EE00EE00EE44EE44EE44E04400FE00FE0'
              . '1830183017D017D017D017D037D837D8600C600C7FFC7FFC0000000000000000'
        },
        smile16 => {
            width  => 32,
            height => 16,
            data =>
              '07C007C01830183020082008400440044C644C648C628C628002800280028002'
              . '800290128822983247C44C64400447C4200820081830183007C007C000000000'
        },
        circle16 => {
            width  => 32,
            height => 16,
            data =>
              '07E000000FF007E01FF80FF03FFC1FF87FFE3FFC7FFE3FFC7FFE3FFC7FFE3FFC'
              . '7FFE3FFC7FFE3FFC3FFC1FF81FF80FF00FF007E007E000000000000000000000'
        },
        zen16 => {
            width  => 32,
            height => 16,
            data =>
              '07E00000083007E010080830200410085C0620047E025C0673327E0273327332'
              . '7F0273327F867F023FFC7F861FF83FFC0FF01FF807E00FF0000007E000000000'
        },
        music16 => {
            width  => 32,
            height => 16,
            data =>
              '0000000001000000018001000140018001200140011001200110011001200110'
              . '0100012001000100070007000F000F000F000F000E000E000000000000000000'
        },
        questionmark16 => {
            width  => 32,
            height => 16,
            data =>
              '00000000000000000FC000001FE00FC030301FE0303030303030303000600060'
              . '00C000C001800180030003000300030000000000030003000300030000000000'
        },
        square16 => {
            width  => 32,
            height => 16,
            data =>
              'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
              . 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
        },
        cross12 => {
            width  => 24,
            height => 12,
            data   => '0400400400400400400400a00a0110f1ee0e'
              . '0a01100400a0040040040040040040000000'
        },
        heart12 => {
            width  => 24,
            height => 12,
            data   => '00000071c0008a200084271c8028a2802842'
              . '4044042082081101100a00a0040040000000'
        },
        leftarrow12 => {
            width  => 24,
            height => 12,
            data   => '0000000000000001000803001807fc3feffc'
              . '7fe7fc3fe300180100080000000000000000'
        },
        rightarrow12 => {
            width  => 24,
            height => 12,
            data   => '000000000000000020010030018ff87fcffc'
              . '7feff87fc030018020010000000000000000'
        },
        handset12 => {
            width  => 24,
            height => 12,
            data   => 'f00f00f80f80180180180180180182182194'
              . '1b41a81c81d4194188f88f80f00f00000000'
        },
        phone12 => {
            width  => 24,
            height => 12,
            data   => '0000007fc000ffe7fcc06ffec06c06ca6ca6'
              . '1f01f03183182e82e86ec6ecc06c06ffeffe'
        },
        smile12 => {
            width  => 24,
            height => 12,
            data   => '0e00e0318318404404514514802802802802'
              . '9129b24e44444044043183180e00e0000000'
        },
        circle12 => {
            width  => 24,
            height => 12,
            data   => '0e00003f80e07fc3f87fc3f8ffe7fcffe7fc'
              . 'ffe7fc7fc3f87fc3f83f80e00e0000000000'
        },
        zen12 => {
            width  => 24,
            height => 12,
            data   => '0e00003180e0404318404404f12404f86f12'
              . 'dfef867fcdfe7fc7fc3f87fc0e03f80000e0'
        },
        music12 => {
            width  => 24,
            height => 12,
            data   => '0000000801000c01800a0140090120088120'
              . '088120390740780f00780f00700e00000000'
        },
        questionmark12 => {
            width  => 24,
            height => 12,
            data   => '1f00003f81e060c3f060c618618618030630'
              . '0600600600c00600c00000000600c00600c0'
        },
        square12 => {
            width  => 24,
            height => 12,
            data   => 'ffffffffffffffffffffffffffffffffffff'
              . 'ffffffffffffffffffffffffffffffffffff'
          }

    );
    if ( $this->{type} eq "icon" ) {
        return %CLIPART_ICONS;
    }
    elsif ( $this->{type} eq "pix" ) {
        return %CLIPART_PIX;
    }
}

sub list {
    my $this = shift;
    my %HASH = $this->hash;
    return keys(%HASH);
}

sub set {
    my $this   = shift;
    my %params = @_;
    my $name   = $params{name};
    my $type   = $this->{type};
    my %HASH   = $this->hash;
    if ( exists( $HASH{$name} ) ) {
        $this->{hashref} = $HASH{$name};
    }
}

package LedSign::Mini::SerialTest;
use strict;
use warnings;

sub new {
    my $that     = shift;
    my $class    = ref($that) || $that;
    my (%params) = @_;
    my $this     = {};
    bless $this, $class;
    $this->{data} = '';
    return $this;
}

sub connect {
    my $this = shift;
    $this->{data} = '';
}

sub write {
    my $this = shift;
    for (@_) {
        $this->{data} .= $_;
    }
}

sub dump {
    my $this = shift;
    return $this->{data};
}

1;

=head1 NAME

LedSign::Mini - send text and graphics to small LED badges and signs
 
=head1 VERSION

Version 1.03

=head1 SYNOPSIS

  use LedSign::Mini;
  my $buffer=LedSign::Mini->new(devicetype => "sign");
  #
  # add a text only message
  #
  $buffer->queueMsg(
      data => "Just a normal test message",
      effect => "scroll",
      speed => 4
  );
  #
  # create a picture and an icon from built-in clipart
  #
  my $pic=$buffer->queuePix(clipart => "zen16");
  my $icon=$buffer->queueIcon(clipart => "heart16");
  #
  # add a message with the picture and animated icon we just created
  #
  $buffer->queueMsg(
          data => "Message 2 with a picture: $pic and an icon: $icon",
          effect => "scroll",
          speed => 3
  );
  $buffer->sendQueue(device => "COM3");
  # 
  # note that the sendQueue() method does not empty the buffer, so if we
  # have a second sign, on a different serial port, we can send everything
  # to it as well...
  $buffer->sendQueue(device => "COM4");

=head1 DESCRIPTION

LedSign::Mini is used to send text and graphics via RS232 to our smaller set of LED Signs and badges.  It is part of the larger LedSign module, which provides similar interfaces for other LED signs that use different protocols.

This sub-module of the larger LEDSign module is the replacement for L<Device::MiniLED|http://search.cpan.org/perldoc?Device%3A%3AMiniLED>, which is now deprecated. 

=head1 CONSTRUCTOR

=head2 new

The constructor has one optional argument...B<devicetype>. If not specified, defaults to "sign".  The B<devicetype> argument drives a few internal options, like rendering of images (16 pixels vs 12 pixels), support for the internal clock (signs have this, badges do not).  Plain text messages will work if this setting is wrong, but you may have issues with images and clock functionality. 

  my $buffer=LedSign::Mini->new(
         devicetype => $devicetype
  );
  # $devicetype can be either:
  #   sign  - denoting a device with a 16 pixel high display
  #   badge - denoting a device with a 12 pixel high display

=head1 METHODS

=head2 queueMsg

This family of devices support a maximum of 8 messages that can be sent to the sign.  These messages can consist of three different types of content, which can be mixed together in the same message..plain text, pixmap images, and 2-frame anmiated icons.

The $buffer->queueMsg method has three required arguments...effect, speed, and data:

=over 

=item B<effect>

One of "hold", "scroll", "snow", "flash" or "hold+flash"

=item B<speed>

An integer from 1 to 5, where 1 is the slowest and 5 is the fastest 

=item B<data>

The data to be sent to the sign. Plain text, optionally with $variables that reference pixmap images or animated icons. Tags are also supported to display flashing, dates/times, and countdown functionality:

=over

=item B<Flashing Tags>

To have a portion of the message flash on and off, you can insert the following tags. This works with no issues on badges.  For signs, the flash and normal tags are actually the same tag...they just toggle the flashing state.

  $buffer->queueMsg(
      data => "Some <f:flash>flashing text<f:normal> in a message"
  );

=item B<Date and Time Tags>

Badges do not support date/time tags at all.  For signs, you can insert the following items within a date/time tag:

Dates and Times

  # %y - two digit year 
  # %d - two digit day of month
  # %m - two digit month (01 = January, etc) 
  # %H - two digit hour
  # %M - two digit minute
  # %S - two digit seconds
  #
  # display a clock
  $buffer->queueMsg( data => '<d:%H:%M:%S>', effect => 'hold');
  # display the current date in mm/dd/yy format
  $buffer->queueMsg( data => '<d:%m/%d/%y>');
  
Countdown functionality. Each tag represents the time until the currently set countdown date.

  # %1 - Days until the current countdown date (DDD)
  # %2 - Hours/Minutes until the current countdown date (HHHH:MM)
  # %3 - Hours/Minutes/Seconds  (HHHH:MM:SS)
  # %4 - Seconds (SSSSS).  If higher than 10000, will display ">10K"
  #
  use LedSign::Mini;
  my $buffer=LedSign::Mini->new(devicetype => "sign");
  use Time::Piece;
  $now=Time::Piece->new();
  $nextyear=$now->year+1;
  $then=$now->strptime("01/01/$nextyear","%m/%d/%Y");
  $buffer->sendCmd(
      device => '/dev/ttyUSB0',
      cmd => 'setcountdown',
      value => $then->epoch
  );
  $buffer->queueMsg(data => '<d:%1> days until the next new year');  
  $buffer->sendQueue(device => '/dev/ttyUSB0');

=back


=back

The queueMsg method returns a number that indicates how many messages have been created.  This may be helpful to ensure you don't try to add a 9th message, which will fail, as the signs only have 8 message slots:

  my $buffer=LedSign::Mini->new(devicetype => "sign");
  for (1..9) {
       my $number=$buffer->queueMsg(
           data => "Message number $_",
           effect => "scroll",
           speed => 5
       )
       # on the ninth loop, $number will be undef, and a warning will be
       # generated
  }



=head2 queuePix

The queuePix method allow you to create simple, single color pixmaps that can be inserted into a message. There are two ways to create a picture.

B<Using the built-in clipart>

  #
  # load the built-in piece of clipart named phone16
  #   the "16" is hinting that it's 16 pixels high, and thus better suited to
  #   a 16 pixel high device, and not a 12 pixel high device
  #
  my $pic=$buffer->queuePix(
        clipart   => "phone16"
  );
  # now use that in a message
  $buffer->queueMsg(
      data => "here is a phone: $pic",
  );

B<Rolling your own pictures>

To supply your own pictures, you need to supply 3 arguments:

B<height>: height of the picture in pixels 

B<width>: width of the picture in pixels (max is 256)

B<data> : a string of 1's and 0's, where the 1 will light up the pixel and 
a 0 won't.  You might find Image::Pbm and it's $image->as_bitstring method
helpful in generating these strings.

  # make a 5x5 pixel outlined box 
  my $pic=$buffer->queuePix(
        height => 5,
        width  => 5,
        data   => 
          "11111".
          "10001".
          "10001".
          "10001".
          "11111".
  );
  # now use that in a message
  $buffer->queueMsg(
      data => "here is a 5 pixel box outline: $pic",
  );


=head2 queueIcon

The $buffer->queueIcon method is almost identical to the $buffer->queuePix method. 
The queueIcon method accepts either a 16x32 pixel image (for signs), or a 
12x24 pixel image (for badges).  It internally splits the image down the middle
into a left and right halves, each one being 16x16 (or 12x12) pixels.

Then, when displayed on the sign, it alternates between the two, in place, 
creating a simple animation.

  # make an icon using the built-in heart16 clipart
  my $icon=$buffer->queueIcon(
      clipart => "heart16"
  );
  # now use that in a message
  $buffer->queueMsg(
      data => "Animated heart icon: $icon",
  );

You can "roll your own" icons as well.  

  # make an animated icon that alternates between a big box and a small box
  my $buffer=LedSign::Mini->new(devicetype => "sign");
  my $icon16x32=
       "XXXXXXXXXXXXXXXX" . "----------------" .
       "X--------------X" . "----------------" .
       "X--------------X" . "--XXXXXXXXXXX---" .
       "X--------------X" . "--X---------X---" .
       "X--------------X" . "--X---------X---" .
       "X--------------X" . "--X---------X---" .
       "X--------------X" . "--X---------X---" .
       "X--------------X" . "--X---------X---" .
       "X--------------X" . "--X---------X---" .
       "X--------------X" . "--X---------X---" .
       "X--------------X" . "--X---------X---" .
       "X--------------X" . "--X---------X---" .
       "X--------------X" . "--X---------X---" .
       "X--------------X" . "--XXXXXXXXXXX---" .
       "X--------------X" . "----------------" .
       "XXXXXXXXXXXXXXXX" . "----------------";
  # translate X to 1, and - to 0
  $icon16x32=~tr/X-/10/;
  # no need to specify width or height, as
  # it assumes 16x32 if $buffer is devicetype "sign", 
  # and assumes 12x24 if $buffer
  my $icon=$buffer->queueIcon(
      data => $icon16x32
  );
  $buffer->queueMsg(
      data => "Flashing Icon: [$icon]"
  );


=head2 sendQueue

The sendQueue method connects to the sign over RS232 and sends all the data accumulated from prior use of the $buffer->queueMsg/Pix/Icon methods.  The only mandatory argument is 'device', denoting which serial device to send to.

It supports three optional arguments: runslots, baudrate, and packetdelay:

=over 

=item B<runslots>
: One of either "auto" or "none".  If the runslots parameter is not supplied, it defaults to "auto".

=over 

=item B<auto> 
: With runslots set to auto, a command is sent to the sign to display the message slots that were created by the queued messages sent to the sign.

=item B<none> 
: With runslots set to none, the messages are still sent to the sign, but no command to display them is sent. The sign will continue to run whatever numbered slots it was showing before the new messages were sent.  Using this in combination with the $buffer->sendCmd(runslots,@slots) command allows you full control over which messages are displayed, and when.

=back

=item B<baudrate>
: defaults to 38400, no real reason to use something other than the default, but it's there if you feel the need.  Must be a value that L<Device::SerialPort|http://search.cpan.org/perldoc?Device%3A%3ASerialPort> or L<Win32::Serialport|http://search.cpan.org/perldoc?Win32%3A%3ASerialPort> thinks is valid

=item B<packetdelay>
: An amount of time, in seconds, to wait, between sending packets to the sign.  The default is 0.25, and seems to work well.  If you see "XX" on your sign while sending data, increasing this value may help. Must be greater than zero.  For reference, each text message generates 3 packets, and each 16x32 portion of an image sends one packet.  There's also an additional, short, packet sent after all message and image packets are delivered. So, if you make packetdelay a large number...and have lots of text and/or images, you may be waiting a while to send all the data.

=back

  # typical use on a windows machine
  $buffer->sendQueue(
      device => "COM4"
  )
  # typical use on a unix/linux machine
  $buffer->sendQueue(
      device => "/dev/ttyUSB0"
  ); # typical use on a unix/linux machine
  #
  # using optional arguments, set baudrate to 9600, and sleep 1/2 a second
  # between sending packets.  
  #
  $buffer->sendQueue(
      device => "COM8",
      baudrate => "9600",
      packetdelay => 0.5
  );

Note that if you have multiple connected signs, you can send to them without creating a new object:

  # send to the first sign
  $buffer->sendQueue(device => "COM4");
  #
  # send to another sign
  $buffer->sendQueue(device => "COM6");
  #  
  # send to a badge connected on COM7
  #   this works fine for plain text, but won't work well for
  #   pictures and icons...you'll have to create a new
  #   sign object with devicetype "badge" for them to render correctly
  $buffer->sendQueue(device => "COM7"); 


=head2 sendCmd

Sends a messsage, typically to change some setting on the sign.  Since it's sending to the sign immediately, it has a mandatory B<device> argument which works the same as in the L</sendQueue> method.  It also supports the B<baudrate> and B<packetdelay> arguments. See the L</sendQueue> method for detail on these arguments.

The argument which specifies the command to send, B<cmd>, is mandatory in all cases.   The next argument, B<value>, is optional sometimes, and required in other cases.  

Settings you can change, with examples:

=over

=item B<runslots>

The "runslots" setting allows you to select which of the preprogrammed message slots (1-8) are shown on the sign.

  use LedSign::Mini;
  select STDOUT;$|=1; # unbuffer STDOUT
  my $buffer=LedSign::Mini->new(devicetype => "sign");
  #
  # add 7 messages
  # 
  for (1..7) {
       $buffer->queueMsg(data=>"Msg $_");
  }    
  # add an 8th message, that's just a space
  $buffer->queueMsg(data=>" ");
  # send the messages, and display the blank one
  $buffer->sendQueue(device=> '/dev/ttyUSB0',runslots => [8]); 
  # sleep for 10 seconds, then show the 1st and 2nd message
  print STDOUT "sleeping for 10 seconds...\n";
  sleep 10;
  $buffer->sendCmd(
      device => '/dev/ttyUSB0',
      cmd => "runslots",
      slots => [1,2]
  );

You can send an empty list, but the sign will then typically flash the word "EMPTY!".  If you want the sign to appear off, insert a message consisting of a space character into a numbered slot, and run just that slot.

=item B<settime>

Setting the sign's time is helpful if you plan on using the L</"Date and Time Tags"> in a message.

The settime command sets the current time and date on the internal clock on the sign.  Supported only for signs...badges don't have an internal clock.  Accepts the time as a unix epoch value, like you would get from time() or the epoch method from L<Time::Piece|http://perldoc.perl.org/Time/Piece.html>.  If you supply the string "now" as the value, the API will internally substitute the current value of time().

  #
  $buffer->sendCmd(
      device => '/dev/ttyUSB0',
      cmd => "settime",
      value => time()
  );

=item B<setcountdown>

Setting the sign's countdown target time is helpful if you plan on using the L</"Date and Time Tags"> in a message.

The setcountdown command sets the target time and date for the countdown timer that's within the the internal clock on the sign.  Supported only for signs...badges don't have an internal clock.  Accepts the target time as a unix epoch value, like you would get from time() or the epoch method from L<Time::Piece|http://perldoc.perl.org/Time/Piece.html>.

  # set the countdown timer to 10 days from now
  my $countdownto=time() + (10*60*60*24);
  $buffer->sendCmd(
      device => '/dev/ttyUSB0',
      cmd => "setcountdown",
      value => time
  );

B<Note>: Make sure you use the L</"settime"> command to set the internal time...the countdown functionality depends on the current time being set correctly on the sign.

=back

=head1 AUTHOR

Kerry Schwab, C<< <sales at brightledsigns.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.  C<perldoc LedSign::Mini>
  
You can also look for information at:

=over 

=item * Our Website:
L<http://www.brightledsigns.com/developers>

=item * Github:
L<https://github.com/BrightLedSigns/LedSign/blob/master/LedSign%3A%3AMini.md>

=item * Meta CPAN
L<https://metacpan.org/release/LedSign>

=back
 
=head1 BUGS

Please report any bugs or feature requests to
C<bug-device-miniled at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically be
notified of progress on your bug as I make changes.

=head1 ACKNOWLEDGEMENTS

Inspiration from similar work:

=over 4

=item L<http://zunkworks.com/ProgrammableLEDNameBadges> - Some code samples for different types of LED badges

=item L<https://github.com/ajesler/ledbadge-rb> - Python library that appears to be targeting signs with a very similar protocol. 

=item L<http://search.cpan.org/~mspencer/ProLite-0.01/ProLite.pm> - The only other CPAN perl module I could find that does something similar, albeit for a different type of sign.

=back

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2013 Kerry Schwab & Bright Signs
All rights reserved.

This program is free software; you can redistribute it and/or modify it under the terms of the the FreeBSD License . You may obtain a copy of the full license at:

L<http://www.freebsd.org/copyright/freebsd-license.html|http://www.freebsd.org/copyright/freebsd-license.html>


Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

=over

=item *

Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

=item *

Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

=item *

Neither the name of the organization nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

=back

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut
