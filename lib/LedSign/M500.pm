package LedSign::M500;
use base qw(LedSign);
use Carp;
use strict;
use warnings;
use 5.008001;
use POSIX qw(strftime);
$LedSign::M500::VERSION="1.02";
#
# Shared Constants / Globals
#
use constant SLOTRANGE => map { sprintf( '%02d', $_ ) } ( 1 .. 99 );

#
# Selectively use Win32::Serial port if Windows OS detected,
# otherwise, use Device::SerialPort
#
BEGIN {
    my $IS_WINDOWS = ( $^O eq "MSWin32" or $^O eq "cygwin" ) ? 1 : 0;

    #
    if ($IS_WINDOWS) {
        eval "use Win32::SerialPort 0.14";
        die "$@\n" if ($@);
    }
    else {
        eval "use Device::SerialPort";
        die "$@\n" if ($@);
    }
}

#
# Shared Constants / Globals
#
use constant  EFFECTMAP => {
    'DEFAULT'         => 'A', 'AUTO'            => 'A',
    'CYCLIC'          => 'A', 'IMMEDIATE'       => 'B',
    'OPENFROMRIGHT'   => 'C', 'OPENFROMLEFT'    => 'D',
    'OPENFROMCENTER'  => 'E', 'OPENTOCENTER'    => 'F',
    'COVERFROMCENTER' => 'G', 'COVERFROMRIGHT'  => 'H',
    'COVERFROMLEFT'   => 'I', 'COVERTOCENTER'   => 'J',
    'SCROLLUP'        => 'K', 'SCROLLDOWN'      => 'L',
    'INTERLACE1'      => 'M', 'INTERLACE2'      => 'N',
    'COVERUP'         => 'O', 'COVERDOWN'       => 'P',
    'SCANLINE'        => 'Q', 'EXPLODE'         => 'R',
    'PACMAN'          => 'S', 'STACK'           => 'T',
    'SHOOT'           => 'U', 'FLASH'           => 'V',
    'RANDOM'          => 'W', 'SLIDEIN'         => 'X',
};

use constant FONTMAP => {
    'DEFAULT'   => '\s', '7X6'       => '\s',
    'SHORT'     => '\q', 'SHORTWIDE' => '\r',
    'WIDE'      => '\t', '7X9'       => '\u',
    'EXTRAWIDE' => '\v', 'SMALL'     => '\w'
};

use constant COLORMAP => {
    'DEFAULT'        => '\b', 'RED'            => '\a',
    'BRIGHTRED'      => '\b', 'ORANGE'         => '\c',
    'BRIGHTORANGE'   => '\d', 'YELLOW'         => '\e',
    'BRIGHTYELLOW'   => '\f', 'GREEN'          => '\g',
    'BRIGHTGREEN'    => '\h', 'LAYERMIX'       => '\i',
    'BRIGHTLAYERMIX' => '\j', 'VERTICALMIX'    => '\k',
    'SAWTOOTHMIX'    => '\l', 'GREENONRED'     => '\m',
    'REDONGREEN'     => '\n', 'ORANGEONRED'    => '\o',
    'YELLOWONGREEN'  => '\p'
};

use constant SPMAP => {
    'DEFAULT' => '\Y5', '0'       => '\Y1',
    '1'       => '\Y2', '2'       => '\Y3',
    '3'       => '\Y4', '4'       => '\Y5',
    '5'       => '\Y6', '6'       => '\Y7',
    '7'       => '\Y8'
};

use constant PAUSEMAP => {
    '1' => '\Z1', '2' => '\Z2',
    '3' => '\Z3', '4' => '\Z4',
    '4' => '\Z5', '5' => '\Z6',
    '6' => '\Z7', '7' => '\Z8'
};

use constant TDMAP => {
    'DATE1' => '^A', 'DATE2' => '^B',
    'DATE3' => '^C', 'DATE4' => '^a',
    'TIME1' => '^D', 'TIME2' => '^E',
    'TIME3' => '^F'
};

sub _init {
    my $this = shift;
    my (%params) = @_;
    $this->{device}   = $params{device};
    $this->{factory}  = LedSign::M500::Factory->new();
    return $this;
}

sub _flush {
    my $this = shift;
    $this->initslots();
    $this->{factory}    = LedSign::Mini::Factory->new();
}


sub _factory {
    my ($this) = shift;
    return $this->{factory};
}

sub sendCmd {
    my ($this)   = shift;
    my (%params) = @_;
    if ( !defined( $params{setting} ) ) {
        croak("Parameter [setting] must be present");
    }
    my @validcmds = qw(test settime alarm setslots);
    my $setting=$params{setting};
    my $value=$params{value};
    my $msg = "~128";
    if ( !grep( /^$setting$/, @validcmds ) ) {
        croak("Invalid value [$setting] for parameter setting");
    }
    if ( $setting eq "settime" ) {
        if ( !exists( $params{value} ) ) {
            croak("No value parameter specified for settime setting");
        }
        if ( $params{value} ne "now" and $params{value} !~ /^\d+$/ ) {
            croak("Invalid value [$params{value}] specified for settime");
        }
        $msg .= '~E';
        if ( $value eq "now" ) {
            $msg .= POSIX::strftime( "%u1%y%m%d%H%M%S", localtime(time) );
        }
        else {
            $msg .= POSIX::strftime( "%u1%y%m%d%H%M%S", localtime($value) );
        }
    } elsif ( $setting eq "alarm" ) {
        if ( !exists( $params{value} ) ) {
            croak("No value parameter specified for alarm setting");
        }
        if ( $params{value} ne "on" and $params{value} ne "off" ) {
            croak("Invalid value [$params{value}] specified for alarm");
        }
        if ( $value eq "on" ) {
            $msg .= '~B';
        }
        else {
            $msg .= '~b';
        }
    } elsif ( $setting eq "test" ) {
        $msg .= '~t';
    }
    $msg .= "\r\r\r";
    $this->sendData(
        baudrate => $params{baudrate},
        packetdelay => $params{packetdelay},
        device => $params{device},
        data => $msg
    );
}

sub queueMsg {
    my ($this)   = shift;
    my (%params) = @_;
    if ( !defined( $params{data} ) ) {
        croak("Parameter [data] must be present");
        return undef;
    }

    # effect
    if ( !$params{effect} ) {
        $params{effect} = "AUTO";
    }
    else {
        my @effects = keys(LedSign::M500::EFFECTMAP());
        if ( !grep( /^$params{effect}$/, @effects ) ) {
            croak("Invalid effect value [$params{effect}]");
            return undef;
        }
    }

    # speed
    if ( exists( $params{speed} ) && $params{speed} !~ /^[1-8]$/ ) {
        croak("Parameter [speed] must be between 1 (fastest) and 8 (slowest)");
        return undef;
    }

    # pause
    if ( !exists( $params{pause} ) ) {
        $params{pause} = 2;
    }

    if ( $params{pause} !~ /^[0-8]$/ ) {
        croak("Parameter [pause] must be between 0 and 8 (seconds)");
        return undef;
    }

    if ( exists( $params{slot} ) ) {
        if ( $params{slot} !~ /^[0-9][0-9]$/ ) {
            croak("Parameter [slot] must be a value from 00-99");
        }
        else {
            $this->setslot( $params{slot} );
        }
    }
    else {
        $params{slot} = $this->setslot;
    }

    # Color
    if ( exists( $params{color} ) ) {
        my @colors = keys(LedSign::M500::COLORMAP());
        if ( !grep( /^$params{color}$/, @colors ) ) {
            croak("Invalid color value [$params{color}]");
            return undef;
        }
    }

    # Font
    if ( exists( $params{font} ) ) {
        my @fonts = keys(LedSign::M500::FONTMAP());
        if ( !grep( /^$params{font}$/, @fonts ) ) {
            croak("Invalid font value [$params{font}]");
            return undef;
        }
    }

    # Start and Stop Time
    if ( !exists( $params{start} ) ) {
        $params{start} = "0000";
    }
    else {
        if (   $params{start} !~ /^\d{4}$/
            or $params{start} < 0
            or $params{start} > 2359 )
        {
            croak("Invalid start time value [$params{start}]");
        }
    }
    if ( !exists( $params{stop} ) ) {
        $params{stop} = "2359";
    }
    else {
        if (   $params{stop} !~ /^\d{4}$/
            or $params{stop} < 0
            or $params{stop} > 2359 )
        {
            croak("Invalid stop time value [$params{stop}]");
        }
    }
    # note: krs: rundays is broken for the moment
    # rundays is a 7 digit binary string (all digits must be 1 or 0)
    # the first digit is sunday, the next monday, and so on
    # so, to run only on sundays -> 1000000
    #            every day       -> 1111111
    #         monday and tuesday -> 0110000
    if ( !exists( $params{rundays} ) ) {
        $params{rundays} = "1111111";
    }
    if ( $params{rundays} !~ /^[01]{7}$/ ) {
        croak("Invalid rundays value [$params{rundays}].");
    }
    my $mobj = $this->_factory->msg( %params, );
    return $this->_factory->count;

}

sub _connect {
    my $this = shift;
    my (%params) = @_;
    my $serial;
    my $port       = $params{device};
    my $baudrate   = $params{baudrate};
    my $IS_WINDOWS = ( $^O eq "MSWin32" or $^O eq "cygwin" ) ? 1 : 0;
    if ($IS_WINDOWS) {
        $serial = new Win32::SerialPort( $port, 1 );
    }
    else {
        $serial = new Device::SerialPort( $port, 1 );
    }
    croak("Can't open serial port $port: $^E\n") unless ($serial);

    # set serial parameters
    $serial->baudrate($baudrate);
    $serial->parity('none');
    $serial->datatype('raw');
    $serial->databits(8);
    $serial->stopbits(1);
    $serial->buffers( 4096, 4096 );

    # if not windows,
    # attempt to make the serial port "raw", with no character
    # translation
    if ( $^O ne "MSWin32" ) {
        $serial->stty_echo(0);
        $serial->stty_echoe(0);
        $serial->stty_echonl(0);
        $serial->stty_ignbrk(0);
        $serial->stty_ignpar(0);
        $serial->stty_inpck(0);
        $serial->stty_istrip(0);
        $serial->stty_inlcr(0);
        $serial->stty_igncr(0);
        $serial->stty_icrnl(0);
        $serial->stty_opost(0);
        $serial->stty_isig(0);
        $serial->stty_icanon(0);
    }
    $serial->handshake('xoff');
    $serial->write_settings();

    # clear the line
    return $serial;
}
sub sendData {
    my $this = shift;
    my %params=@_;
    my $data=$params{data};
    if ( !defined( $params{device} ) ) {
        croak("Must supply the device name.");
        return undef;
    }
    my $baudrate=$this->checkbaudrate($params{baudrate});
    my $packetdelay=$this->checkpacketdelay($params{packetdelay});
    my $serial;
    if ( defined $params{debug} ) {
        $serial = LedSign::M500::SerialTest->new();
    } else {
        $serial = $this->_connect(
            device   => $params{device},
            baudrate => $baudrate
        );
    }
    $serial->write($data);
    select(undef,undef,undef,$packetdelay);
}
sub checkbaudrate {
    my $this=shift;
    my $baudrate=shift;
    my @validrates = qw( 0 50 75 110 134 150 200 300 600
      1200 1800 2400 4800 9600 19200 38400 57600
      115200 230400 460800 500000 576000 921600 1000000
      1152000 2000000 2500000 3000000 3500000 4000000
    );
    if (defined($baudrate)) {
        if ( !grep { $_ eq $baudrate } @validrates ) {
            croak( 'Invalid baudrate [' . $baudrate . ']' );
        }
        return $baudrate;
    } else {
        return 9600;
    }
}
sub checkpacketdelay {
    my $this=shift;
    my $packetdelay=shift;
    if (defined($packetdelay)) {
        if ( $packetdelay =~ m#^\d*\.{0,1}\d*$# ) {
            return $packetdelay;
        } else {
            croak(  'Invalid value ['
                  . $packetdelay
                  . '] for parameter packetdelay' );
        }
    } else {
        return 0.20;
    }
}

sub sendQueue {
    my $this = shift;
    my (%params) = @_;
    if ( !defined( $params{device} ) ) {
        croak("Must supply the device name.");
        return undef;
    }
    my $baudrate=$this->checkbaudrate($params{baudrate});
    my $packetdelay=$this->checkpacketdelay($params{packetdelay});
    my $serial;
    if ( defined $params{debug} ) {
        $serial = LedSign::M500::SerialTest->new();
    } else {
        $serial = $this->_connect(
            device   => $params{device},
            baudrate => $baudrate
        );
    }

    foreach my $obj ( @{ $this->_factory->objects() } ) {
        my $objtype = $obj->{'objtype'};
        my @packets = $obj->encode();
        $serial->read_const_time(1000);
        $serial->read_char_time(100);
        $serial->write_settings();
        foreach my $data (@packets) {
            my $count=0;
            $count=$serial->write($data);
            if ($count eq "") {
                $count=0;
            }
            if ( $^O eq "MSWin32" ) {
                $serial->write_done;
            }
            else {
                $serial->write_drain;
            }
            if ( $count != length($data) ) {
                carp("Serial write error, [$count] bytes written, error [$^E]");
            }
            select( undef, undef, undef, $packetdelay );
        }
    }
    my @slots;
    if ( exists( $params{showslots} ) ) {
        # strip spaces
        $params{showslots} =~ s#\s##g;
        foreach my $one ( split( /\,/, $params{showslots} ) ) {
            if ( !grep( /^$one$/, @LedSign::M500::SLOTRANGE ) ) {
                croak("Invalid value [$one] in parameter [showslots]");
            }
            else {
                push( @slots, $one );
            }
        }
    } else {
        @slots = @{$this->{'usedslots'}};
    }
    if (scalar(@slots) > 0 ) {
        my $slotlist = join('', @slots );
        my $start='0000';
        if (exists($params{start}) && $params{start} =~ /^\d\d\d\d$/) {
            $start=$params{start}; 
        }
        my $stop='2359';
        if (exists($params{stop}) && $params{stop} =~ /^\d\d\d\d$/) {
            $stop=$params{stop}; 
        }
        my $rundays='1111111';
        if (exists($params{rundays}) && $params{rundays} =~ /^[01]{7}$/) {
            my $rundays=$params{rundays};
        }
        my $runit = "~128~S0${rundays}${start}${stop}${slotlist}";
        $runit .= "\r\r\r";
        select( undef, undef, undef, $packetdelay );
        $serial->write($runit);
    }
    if ( defined $params{debug} ) {
        return $serial->dump();
    }
}

package LedSign::M500::Factory;
use base qw (LedSign::Factory);
our @CARP_NOT = qw(LedSign::M500);

sub _init {
    my $this = shift;
    my (%params) = @_;
    foreach my $key ( keys(%params) ) {
        $this->{$key} = $params{$key};
    }
    $this->{count}    = 0;
    $this->{msgslots} = ();
    $this->{objects}  = ();
    return $this;
}

sub msg {
    my $this     = shift;
    my (%params) = @_;
    my $msg      = LedSign::M500::Msg->new( %params, factory => $this );
    push( @{ $this->{objects} }, $msg );
    $this->{count}++;
    my $count = $this->{count};
    return $msg;
}

sub count {
    my $this  = shift;
    my $count = $this->{count};
    return $this->{count};
}

sub objects {
    my $this = shift;
    if ( defined( $this->{objects} ) ) {
        return $this->{objects};
    }
    else {
        return [];
    }
}
#
# object to hold a message and it's associated data and parameters
#
package LedSign::M500::Msg;
our @CARP_NOT = qw(LedSign::M500);

sub new {
    my $that     = shift;
    my $class    = ref($that) || $that;
    my (%params) = @_;
    my $this     = {};
    bless $this, $class;
    foreach my $key ( keys(%params) ) {
        $this->{$key} = $params{$key};
    }
    $this->{'objtype'} = 'msg';
    $this->setwait(2000);
    return $this;
}

sub setwait {
    my $this = shift;
    my $wait = shift;
    $this->{wait} = $wait;
}

sub getwait {
    my $this = shift;
    return $this->{wait};
}

sub factory {
    my $this = shift;
    return $this->{factory};
}

sub checksum {
    my $this = shift;
    my $data = shift;
    my $checksum;
    foreach my $char ( split( //, $data ) ) {
        $checksum += ord($char);
    }
    $checksum = sprintf( "%04X", $checksum );
    return $checksum;
}

sub header {
    my $this = shift;

    # 5 null bytes for the header;
    my $header = pack( "C*", ( 0x00, 0x00, 0x00, 0x00, 0x00 ) );

    # start command
    $header .= pack( "C", 0x01 );

    # pc addr (first two bytes) + sign address (next two bytes)
    # hardcoding to FF00 for now
    $header .= 'FF00';
    return $header;
}

sub encode {
    my $this    = shift;
    my $objtype = $this->{'objtype'};
    my $header  = $this->header;
    my $msg;

    # STX
    my $msgdata = '';
    $msg = '~128';

    # message slot (valid slots are 0..9 and A..Z, 36 slots total);
    $msg .= '~f' . $this->{slot};

    # effect
    my $effect = LedSign::M500::EFFECTMAP->{ $this->{effect} };
    if ( !$effect ) {
        $effect = LedSign::M500::EFFECTMAP->{'AUTO'};
    }
    $msg .= $effect;
    my $color;
    if ( exists( $this->{color} ) ) {
        $color = LedSign::M500::COLORMAP->{ $this->{color} };
    }
    else {
        $color = LedSign::M500::COLORMAP->{'BRIGHTRED'};
    }
    $msg .= $color;
    my $font;
    if ( exists( $this->{font} ) ) {
        $font = LedSign::M500::FONTMAP->{ $this->{font} };
    }
    else {
        $font = LedSign::M500::FONTMAP->{'DEFAULT'};
    }
    $msg .= $font;
    if ( exists( $this->{speed} ) ) {
        my $speed = LedSign::M500::SPMAP->{ $this->{speed} };
        $msg .= $speed;
    }
    $msgdata = $this->processTags();
    if ( exists( $this->{pause} ) ) {
        my $pause = LedSign::M500::PAUSEMAP->{ $this->{pause} };
        $msg .= $pause;
    }
    $msgdata .= "\r\r\r";
    $msg = $header . $msg . $msgdata;
    # End of Text - ETX
    # Supposed to be a checksum - sign seems to ignore it though.
    # EOT - End of Transmission
    my @encoded;
    push( @encoded, $msg );
    return @encoded;
}


sub processTags {
    my $this    = shift;
    my $msgdata = $this->{data};

    # escape backslashes
    $msgdata =~ s#\\#\\\\#g;

    # escape carats
    $msgdata =~ s#\^#\\^#g;

    # change newlines and carriage returns to spaces
    $msgdata =~ s#\n# #g;
    $msgdata =~ s#\r# #g;

    # font tags
    # font
    while ( $msgdata =~ /(<f:([^>]+)>)/gi ) {
        my $fonttag = $1;
        my $font    = $2;
        my $substitute;
        if ( exists( $this->LedSign::M500::FONTMAP()->{$font} ) ) {
            $substitute = $this->LedSign::M500::FONTMAP()->{$font};
        }
        else {
            $substitute = '';
        }
        $msgdata =~ s/$fonttag/$substitute/;
    }

    # color
    while ( $msgdata =~ /(<c:([^>]+)>)/gi ) {
        my $colortag = $1;
        my $color    = $2;
        my $substitute;
        if ( exists( $this->LedSign::M500::COLORMAP()->{$color} ) ) {
            $substitute = $this->LedSign::M500::COLORMAP()->{$color};
        }
        else {
            $substitute = '';
        }
        $msgdata =~ s/$colortag/$substitute/;
    }

    # effect
    while ( $msgdata =~ /(<e:([^>]+)>)/gi ) {
        my $effecttag = $1;
        my $effect    = $2;
        my $substitute;
        if ( exists( $this->LedSign::M500::EFFECTMAP()->{$effect} ) ) {
            $substitute = "\r" . $this->LedSign::M500::EFFECTMAP()->{$effect} . '\\c';
        }
        else {
            $substitute = '';
        }
        $msgdata =~ s/$effecttag/$substitute/;
    }

    # speed
    while ( $msgdata =~ /(<s:([^>]+)>)/gi ) {
        my $speedtag = $1;
        my $speed    = $2;
        my $substitute;
        if ( exists( $this->SPMAP()->{$speed} ) ) {
            $substitute = $this->SPMAP()->{$speed};
        }
        else {
            $substitute = '';
        }
        $msgdata =~ s/$speedtag/$substitute/;
    }

    # pause
    while ( $msgdata =~ /(<p:([^>]+)>)/gi ) {
        my $pausetag = $1;
        my $pause    = $2;
        my $substitute;
        if ( exists( $this->LedSign::M500::PAUSEMAP()->{$pause} ) ) {
            $substitute = $this->LedSign::M500::PAUSEMAP()->{$pause};
        }
        else {
            $substitute = '';
        }
        $msgdata =~ s/$pausetag/$substitute/;
    }

    # time / date
    while ( $msgdata =~ /(<t:([^>]+)>)/gi ) {
        my $timetag = $1;
        my $time    = $2;
        my $substitute;
        if ( exists( $this->LedSign::M500::TDMAP()->{$time} ) ) {
            $substitute = $this->LedSign::M500::TDMAP()->{$time};
        }
        else {
            $substitute = '[INVALID TIME TAG]';
        }
        $msgdata =~ s/$timetag/$substitute/;
    }

    return $msgdata;
}

#
# For Internal Testing
#
package LedSign::M500::SerialTest;

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
    my $data = $this->{data};
    return $data;
}

1;

=head1 NAME

LedSign::M500 - send text and graphics to led signs 
 
=head1 VERSION

Version 1.02

=head1 SYNOPSIS

  #!/usr/bin/perl
  use LedSign::M500;
  #
  # add two messages then send them to a sign
  #   connected to COM3 (windows)
  #
  my $sign=LedSign::M500->new();
  $sign->queueMsg(
      data => "Message One"
  );
  $sign->queueMsg(
      data => "Message Two"
  );
  $sign->sendQueue(device => "COM3");

  #!/usr/bin/perl
  #
  # set the time on the sign to the current time
  #  on this machine
  # 
  use LedSign::M500;
  my $sign=LedSign::M500->new();
  $sign->sendCmd(
      setting => "settime",
      value => "now"
  );
  $sign->sendQueue(device => "/dev/ttyUSB0");

=head1 DESCRIPTION

LedSign::M500 is used to send text and graphics via RS232 to a specific set of programmable scrolling LED signs (BB* and SB* models from BrightLEDSigns.com) 

=head1 CONSTRUCTOR

=head2 new

  my $sign=LedSign::M500->new();

=head1 METHODS

=head2 $sign->queueMsg

Adds a text messsage to display on the sign.  The $sign->queueMsg method has only one required argument...data, which is the text to display on the sign. 

Note that this message isn't sent to the sign until you call the L<< /"$sign->send" >> method, which will then connect to the sign and send ALL messages and configuration commands (in first in, first out order) that you added with the L<< /"$sign->queueMsg" >> and L<< /"$sign->sendCmd" >> methods.

=over 4

=item B<data>

The message you want to display on the sign.  Can be either plain text, like "hello World!", or it can be marked up with font,color, and/or time tags. 

Valid values for time tags are shown in the code example above. See L</"font"> for valid font values, and L</"color"> for valid color values.

  # font, color, and time tag example
  $sign->queueMsg(
      data => "<f:7X6><c:YELLOW>6 pixel yellow<f:7X9>9 pixel" .
              "<c:RED>The time is <t:A>"
  ) 
  # valid values for time tags
  # A - hh:mm:ss      B - hh:mm:ss AM/PM   C - hh:mm       D hh:mm AM/PM
  # E - mm/dd/yyyy    F - yyyy-mm-dd       G - dd.MM yyyy  H mm'dd'yyyy
  # I - short spelling of day (SUN, MON, TUE, etc)
  # I - long spelling of day (Sunday, Monday, Tuesday, etc)

=item B<effect>

Optional. Valid values are: AUTO, COVERDOWN, COVERFROMCENTER, COVERFROMLEFT, COVERFROMRIGHT, COVERTOCENTER, COVERUP, CYCLIC, EXPLODE, FLASH, IMMEDIATE, INTERLACE1, INTERLACE2, OPENFROMCENTER, OPENFROMLEFT, OPENFROMRIGHT, OPENTOCENTER, PACMAN, RANDOM, SCANLINE, SCROLLDOWN, SCROLLUP, SHOOT, SLIDEIN, STACK. Defaults to AUTO.

=item B<speed>

Optional. An integer from 1 to 5, where 1 is the fastest 5 is the slowest

Defaults to 2.

=item B<pause>

Optional. An integer from 0 to 9, indicating how many seconds to hold the message on screen before moving to the next message

Defaults to 2.

=item B<font>

Allows you to specify the default font for the message.  Defaults to "7X6".   Note that you can use multiple fonts in a single message via the use of L<font tags in the data parameter|/"data">.

Valid values are: SHORT, WIDE, EXTRAWIDE, 7X6, SHORTWIDE, 7X9, and SMALL.

=item B<color>

Allows you to specify the default color for the message.  Defaults to "RED".   Note that you can use multiple colors in a single message via the use of L<color tags in the data parameter|/"data">.

Valid values are: RED, BRIGHTRED, ORANGE,  BRIGHTORANGE, YELLOW, BRIGHTYELLOW, GREEN, BRIGHTGREEN, LAYERMIX, BRIGHTLAYERMIX, VERTICALMIX, SAWTOOTHMIX, REDONGREEN, YELLOWONGREEN

=item B<start>

Allows you to specify a start time for the message. It's a 4 digit number representing the start time in a 24 hour clock, such that 0800 would be 8am, and 1300 would be 1pm.      

Valid values: 0000 to 2359

Default value: 0000

=item B<stop>

Allows you to specify a stop time for the message. It's a 4 digit number repres
enting the stop time in a 24 hour clock, such that 0800 would be 8am, and 1300
would be 1pm.      

Valid values: 0000 to 2359

Default value: 2359

=item B<rundays>

Allows you to specify which days the message should run.  It's a 7 digit binary string, meaning that the number can only have ones and zeros in it.  The first digit is Sunday, the second is Monday, and so forth.  So, for example, to run the sign only on Sunday, you would use 1000000.  To run it every day, 1111111.  Or, for example, to show it only on Monday, Wednesday, and Friday, 0101010.

Default value: 1111111

=item B<slot>

The sign has 99 message slots, numbered from 01 to 99.   It displays each message (a message can consist of multiple screens of text, btw), in order.  If you do not supply this argument, the API will assign the slots consecutively, starting with slot 01.  

Specifying the slot explicitly may be useful if you want to, for example, keep a constant message in lower numbered slots...say 0, 1, and 2, but change a message periodicaly that sits in slot 3.  If you don't need this kind of functionality, however, just don't supply the slot argument. 

Example of using the slot parameter 

  #
  # EXAMPLE
  #
  my $sign=LedSign::M500->new();
  $sign->queueMsg(
      data => "A message",
      slot => 3
  );
  $sign->queueMsg(
      data => "Another message",
      slot => 4
  );
  #
  #
  $sign->sendQueue(device => "COM3");

=back

=head2 $sign->sendCmd

Adds a configuration messsage to change some setting on the sign.  The first argument, setting, is mandatory in all cases.   The second argument, value, is optional sometimes, and required in other cases.

Settings you can change, with examples:

=over 4

=item B<alarm>

  #
  # turn the alarm on or off
  #
  $sign->sendCmd(
      setting => "alarm",
      value => "on",
  );
  $sign->sendQueue(device => "/dev/ttyUSB0");

=item B<setttime>

  #
  # sets the internal date and time clock on the sign. 
  #
  # You can supply the string "now", and it will sync the sign's clock  
  # to the time on the computer running  this api.
  #
  # You can also supply an integer representing the time and date
  # as unix epoch seconds.  The perl "time" function, for example, returns
  # this type of value
  #
  $sign->sendCmd(
      setting => "settime",
      value => "now"
  );
  $sign->sendQueue(device => "/dev/ttyUSB0");

=item B<test>

  # display a test pattern on the sign, where every LED is lit
  $sign->sendCmd(
      setting => "test",
  );
  $sign->sendQueue(device => "/dev/ttyUSB0");

=back

=head2 $sign->sendQueue

The sendQueue method connects to the sign over RS232 and sends all the data accumulated from prior use of the $sign->queueMsg method.  The only mandatory argument is 'device', denoting which serial device to send to.

It supports one optional argument: baudrate

=over 4

=item

B<baudrate>: defaults to 9600, no real reason to use something other than the default, but it's there if you feel the need.  Must be a value that Device::Serialport or Win32::Serialport thinks is valid

=back

  # typical use on a windows machine
  $sign->sendQueue(
      device => "COM4"
  );
  # typical use on a unix/linux machine
  $sign->sendQueue(
      device => "/dev/ttyUSB0"
  );
  # using optional argument, set baudrate to 2400
  $sign->sendQueue(
      device => "COM8",
      baudrate => "2400"
  );

Note that if you have multiple connected signs, you can send to them without creating a new object:

  # send to the first sign
  $sign->sendQueue(device => "COM4");
  # send to another sign
  $sign->sendQueue(device => "COM6");

=head1 AUTHOR

Kerry Schwab, C<< <sales at brightledsigns.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.  C<perldoc LedSign::M500>
  
You can also look for information at:

=over 

=item * Our Website:
L<http://www.brightledsigns.com/developers>

=back
 
=head1 BUGS

Please report any bugs or feature requests to
C<bug-device-miniled at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org> .  I will be notified, and then you'll automatically be
notified of progress on your bug as I make changes.

=head1 ACKNOWLEDGEMENTS

Inspiration from similar work:

=over 4

=item L<ProLite Perl Module|ProLite> - The only other CPAN perl module I could find that does something similar, albeit for a different type of sign.

=back

=cut

