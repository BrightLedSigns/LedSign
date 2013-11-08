package LedSign::BB;
use base qw(LedSign);
use Carp;
use strict;
use warnings;
use 5.005;
use POSIX qw(strftime);

#
# Shared Constants / Globals
#
use constant SLOTRANGE => ( 0 .. 9, 'A' .. 'Y' );

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
use constant EFFECTMAP => {
    AUTO       => 'A', FLASH      => 'B', HOLD       => 'C',
    INTERLOCK  => 'D', ROLLDOWN   => 'E', ROLLUP     => 'F',
    ROLLIN     => 'G', ROLLOUT    => 'H', ROLLLEFT   => 'I',
    ROLLRIGHT  => 'J', ROTATE     => 'K', SLIDE      => 'L',
    SNOW       => 'M', SPARKLE    => 'N', SPRAY      => 'O',
    STARBURST  => 'P', SWITCH     => 'Q', TWINKLE    => 'R',
    WIPEDOWN   => 'S', WIPEUP     => 'T', WIPEIN     => 'U',
    WIPEOUT    => 'V', WIPELEFT   => 'W', WIPERIGHT  => 'X',
    CYCLECOLOR => 'Y', CLOCK      => 'Z'
};
use constant FONTMAP => {
    SS5   => 'A', ST5   => 'B', WD5   => 'C', WS5   => 'D',
    SS7   => 'E', ST7   => 'F', WD7   => 'G', WS7   => 'H',
    SDS   => 'I', SRF   => 'J', STF   => 'K', WDF   => 'L',
    WSF   => 'M', SDF   => 'N', SS10  => 'O', ST10  => 'P',
    WD10  => 'Q', WS10  => 'R', SS15  => 'S', ST15  => 'T',
    WD15  => 'U', WS15  => 'V', SS24  => 'W', ST31  => 'X',
    SMALL => '@'
};
use constant COLORMAP => {
    AUTO      => 'A', RED       => 'B', GREEN     => 'C',
    YELLOW    => 'F', DIM_RED   => 'D', DIM_GREEN => 'E',
    BROWN     => 'G', AMBER     => 'H', ORANGE    => 'I',
    MIX1      => 'J', MIX2      => 'K', MIX3      => 'L',
    BLACK     => 'M'
};
use constant ALIGNMAP => {
    LEFT   => 1, RIGHT  => 2, CENTER => 3
};

sub _init {
    my $this = shift;
    my (%params) = @_;
    $this->{device}   = $params{device};
    $this->{refcount} = 0;
    $this->{factory} = LedSign::BB::Factory->new();
    return $this;
}
sub _flush {
    my $this = shift;
    $this->{msgcount} = 0;
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
        croak("Parameter [data] must be present");
    }
    my @validcmds = qw(brightness cleardata reset settime signmode
      displaymode);
    if ( !grep( /^$params{setting}$/, @validcmds ) ) {
        croak("Invalid value [$params{setting}] for parameter setting");
    }
    if ( $params{setting} eq "settime" ) {
        if ( !exists( $params{value} ) ) {
            croak("No value parameter specified for settime setting");
        }
        if ( $params{value} ne "now" and $params{value} !~ /^\d+$/ ) {
            croak("Invalid value [$params{value}] specified for settime");
        }
    }
    if ( $params{setting} eq "brightness" ) {
        if ( !exists( $params{value} ) ) {
            croak("No value parameter specified for brightness setting");
        }
        if ( $params{value} !~ /^[1-8AT]$/ ) {
            croak(
                "Brightness value must be either 'A' or a number from 1 to 8");
        }
    }
    if ( $params{setting} eq "signmode" ) {
        if ( !exists( $params{value} ) ) {
            croak("No value parameter specified for signmode setting");
        }
        if ( $params{value} !~ /^(basic|expand)$/ ) {
            croak("signmode  value must be either basic or expand");
        }
    }
    if ( $params{setting} eq "displaymode" ) {
        if ( !exists( $params{value} ) ) {
            croak("No value parameter specified for displaymode setting");
        }
        if ( $params{value} !~ /^(allslots|bytime|test)$/ ) {
            croak("Brightness value must be either allslots or bytime");
        }
    }
    my $cobj = $this->_factory->control( %params, );
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
        my @effects = keys(%LedSign::BB::EFFECTMAP);
        if ( !grep( /^$params{effect}$/, @effects ) ) {
            croak("Invalid effect value [$params{effect}]");
            return undef;
        }
    }

    # speed
    if ( !exists( $params{speed} ) ) {
        $params{speed} = 2;
    }
    if ( $params{speed} !~ /^[1-5]$/ ) {
        croak("Parameter [speed] must be between 1 (slowest) and 5 (fastest)");
        return undef;
    }

    # pause
    if ( !exists( $params{pause} ) ) {
        $params{pause} = 2;
    }

    if ( $params{pause} !~ /^[0-9]$/ ) {
        croak("Parameter [pause] must be between 0 and 9 (seconds)");
        return undef;
    }

    if ( exists( $params{slot} ) ) {
        if ( $params{slot} !~ /^[0-9A-Z]$/ ) {
            croak("Parameter [slot] must be a value from 0-9,A-Z");
        }
        else {
            $this->setslot( $params{slot} );
        }
    }
    else {
        $params{slot} = $this->setslot;
    }

    # Align
    if ( exists( $params{align} ) ) {
        if (   $params{align} ne "LEFT"
            && $params{align} ne "CENTER"
            && $params{align} ne "RIGHT" )
        {
            croak("Parameter [align] must be one of LEFT, RIGHT, or CENTER");
        }
    }
    else {
        $params{align} = "CENTER";
    }

    # Font
    if ( exists( $params{font} ) ) {
        my @fonts = keys(%LedSign::BB::FONTMAP);
        if ( !grep( /^$params{font}$/, @fonts ) ) {
            croak("Invalid font value [$params{font}]");
            return undef;
        }
    }

    # Color
    if ( exists( $params{color} ) ) {
        my @colors = keys(%LedSign::BB::COLORMAP);
        if ( !grep( /^$params{color}$/, @colors ) ) {
            croak("Invalid color value [$params{color}]");
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

sub sendQueue {
    my $this = shift;
    my (%params) = @_;
    if ( !defined( $params{device} ) ) {
        croak("Must supply the device name.");
        return undef;
    }
    my $baudrate;
    if ( defined( $params{baudrate} ) ) {
        my @validrates = qw( 0 50 75 110 134 150 200 300 600
          1200 1800 2400 4800 9600 19200 38400 57600
          115200 230400 460800 500000 576000 921600 1000000
          1152000 2000000 2500000 3000000 3500000 4000000
        );
        if ( !grep { $_ eq $params{baudrate} } @validrates ) {
            croak( 'Invalid baudrate [' . $params{baudrate} . ']' );
        }
        else {
            $baudrate = $params{baudrate};
        }
    }
    else {
        $baudrate = "9600";
    }
    my $serial;
    if ( defined $params{debug} ) {
        $serial = LedSign::BB::SerialTest->new();
    }
    else {
        $serial = $this->_connect(
            device   => $params{device},
            baudrate => $baudrate
        );
    }

    # send an initial null, wakes up the sign
    my $count = 0;
    foreach my $obj ( @{ $this->_factory->objects() } ) {
        $count++;
        my $objtype = $obj->{'objtype'};

        #
        # note that this could be a msg object, or a command object.
        # both have an encode method
        #
        my @packets = $obj->encode();
        $serial->read_const_time(1000);
        $serial->read_char_time(100);
        $serial->write_settings();
        my $count = 0;
        foreach my $data (@packets) {
            $count++;
            my $count = $serial->write($data);
            if ( $^O eq "MSWin32" ) {
                $serial->write_done;
            }
            else {
                $serial->write_drain;
            }
            if ( $count != length($data) ) {
                carp("Serial write error, [$count] bytes written, error [$^E]");
            }

            # wait up to 1 second for the initial ack
            $serial->read_const_time("1000");
            my $ack = $serial->read(1);
            if ( ord($ack) ne 0x04 ) {
                carp("Initial serial ACK from sign corrupted");
            }

            #
            #
            my $wait = $obj->getwait;
            $serial->read_const_time($wait);
            $serial->write_settings();
            my $eot = $serial->read(1);
            if ( ord($eot) ne 0x01 ) {
                carp("Final serial ACK from sign corrupted");
            }
            $serial->purge_all;

            # sleep for 8/10 of a second
            select( undef, undef, undef, 0.8 );
        }
    }
    if ( defined $params{debug} ) {
        return $serial->dump();
    }
}

package LedSign::BB::Factory;
use base qw (LedSign::Factory);
our @CARP_NOT = qw(LedSign::BB);

sub _init {
    my $this = shift;
    my (%params) = @_;
    foreach my $key ( keys(%params) ) {
        $this->{$key} = $params{$key};
    }
    $this->{count} = 0;
    $this->{objects}=();
    return $this;
}

sub msg {
    my $this     = shift;
    my (%params) = @_;
    my $msg      = LedSign::BB::Msg->new( %params, factory => $this );
    push( @{ $this->{objects} }, $msg );
    $this->{count}++;
    my $count = $this->{count};
    return $msg;
}

sub control {
    my $this     = shift;
    my (%params) = @_;
    my $obj      = LedSign::BB::Config->new( %params, factory => $this );
    push( @{ $this->{objects} }, $obj );
    $this->{count}++;
    my $count = $this->{count};
    return $count;
}

sub count {
    my $this  = shift;
    my $count = $this->{count};
    return $this->{count};
}

sub objects {
    my $this = shift;
    if (defined($this->{objects})) {
        return $this->{objects};
    } else {
        return ();
    }
}

#
# Superclass for Msg and Config, basically "things" that you send to the send
#
#   Msg is text messages that display on the sign
#   Control is things like adjusting the brightness or doing a soft reset
#
package LedSign::BB::Command;

sub new {
    my $that     = shift;
    my $class    = ref($that) || $that;
    my (%params) = @_;
    my $this     = {};
    bless $this, $class;
    foreach my $key ( keys(%params) ) {
        $this->{$key} = $params{$key};
    }
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
    $msg = pack( "C", 0x02 );
    my $msgdata = '';
    if ( $objtype eq "msg" ) {
        $msgdata = $this->processTags();

       # replace newlines or carriage return, or cr/lf with sign's linefeed char
        $msgdata =~ s#\r\n#\x7f#g;
        $msgdata =~ s#\r#\x7f#g;
        $msgdata =~ s#\n#\x7f#g;

        #
        # if they specified a default font for the message, prepend the font
        # tag to the message data
        #
        if ( exists( $this->{color} ) ) {
            my $colortag =
              pack( "C", 0xfd ) . $LedSign::BB::COLORMAP{ $this->{color} };
            $msgdata = $colortag . $msgdata;
        }
        if ( exists( $this->{font} ) ) {
            my $fonttag =
              pack( "C", 0xfe ) . $LedSign::BB::FONTMAP{ $this->{font} };
            $msgdata = $fonttag . $msgdata;
        }

        #
        # display mode
        # A= TEXT, C = VARIABLE, E = GRAPHIC, W = WRITE SPECIAL, R= READ SPECIAL
        $msg .= 'A';

        # message slot (valid slots are 0..9 and A..Z, 36 slots total);
        $msg .= $this->{slot};

        # effect
        my $effect = $LedSign::BB::EFFECTMAP{ $this->{effect} };
        if ( !$effect ) {
            $effect = $this->EFFECTMAP()->{AUTO};
        }
        $msg .= $effect;

        # speed, pause time
        $msg .= $this->{speed};
        $msg .= $this->{pause};

        # dates and times
        my $rundays = sprintf( '%02X', oct("0b$this->{rundays}") );
        $msg .= $rundays;
        $msg .= $this->{start};
        $msg .= $this->{stop};

        # placeholder
        $msg .= '000';

        # alignment (left,center,right);
        $msg .= $LedSign::BB::ALIGNMAP{ $this->{align} };
    }
    elsif ( $objtype eq "config" ) {
        $msg .= "W";
        my $setting = $this->{setting};
        my $value   = $this->{value};
        if ( $setting eq "reset" ) {
            $msg .= "B";
        }
        if ( $setting eq "cleardata" ) {

            #
            # the cleardata command takes 30 seconds to send back an ack
            # so, we'll set the wait time to a higher value
            #
            $this->setwait("35000");
            $msg .= "L";
        }
        if ( $setting eq "brightness" ) {
            $msg .= "P" . $value;
        }
        if ( $setting eq "settime" ) {
            if ( $value eq "now" ) {
                $msg .=
                  "A" . POSIX::strftime( "%Y%m%d%H%M%S%w", localtime(time) );
            }
            else {
                $msg .=
                  "A" . POSIX::strftime( "%Y%m%d%H%M%S%w", localtime($value) );
            }
        }
        if ( $setting eq "signmode" ) {
            if ( $value eq "basic" ) {
                $msg .= "Y" . "1";
            }
            elsif ( $value eq "expand" ) {
                $msg .= "Y" . "0";
            }
        }
        if ( $setting eq "displaymode" ) {
            if ( $value eq "allslots" ) {
                $msg .= "F" . "A";
            }
            elsif ( $value eq "bytime" ) {
                $msg .= "F" . "T";
            } elsif ($value eq "test") {
                $msg .= "F" . "F1";
                #$msg .= "F" . "A";
            }
        }
    }
    $msg .= $msgdata;

    # End of Text - ETX
    $msg .= pack( "C", 0x03 );

    # Supposed to be a checksum - sign seems to ignore it though.
    my $checksum = $this->checksum($msg);

    # EOT - End of Transmission
    my $trailer = pack( "C", 0x04 );
    my @encoded;
    push( @encoded, $header . $msg . $checksum . $trailer );
    return @encoded;
}

#
# object to hold a control command and it's associated data and parameters
#   control commands are things like "soft reset" or "adjust brightness"
#   that are sent to the sign
#
package LedSign::BB::Config;
our @CARP_NOT = qw(LedSign::BB);
our @ISA      = qw (LedSign::BB::Command);

sub new {
    my $that  = shift;
    my $class = ref($that) || $that;
    my $this  = LedSign::BB::Command->new(@_);
    $this->{'objtype'} = 'config';
    return ( bless( $this, $class ) );
}

#
# object to hold a message and it's associated data and parameters
#
package LedSign::BB::Msg;
our @CARP_NOT = qw(LedSign::BB);
our @ISA      = qw (LedSign::BB::Command);

sub new {
    my $that  = shift;
    my $class = ref($that) || $that;
    my $this  = LedSign::BB::Command->new(@_);
    $this->{'objtype'} = 'msg';
    return ( bless( $this, $class ) );
}

sub processTags {
    my $this    = shift;
    my $msgdata = $this->{data};

    # font tags
    # font
    my $fontctl = pack( "C", 0xfe );
    while ( $msgdata =~ /(<f:([^>]+)>)/gi ) {
        my $fonttag = $1;
        my $font    = $2;
        my $substitute;
        if ( exists( $this->FONTMAP()->{$font} ) ) {
            $substitute = $fontctl . $this->FONTMAP()->{$font};
        }
        else {
            $substitute = '';
        }
        $msgdata =~ s/$fonttag/$substitute/;
    }

    # color
    my $colorctl = pack( "C", 0xfd );
    while ( $msgdata =~ /(<c:([^>]+)>)/gi ) {
        my $colortag = $1;
        my $color    = $2;
        my $substitute;
        if ( exists( $this->COLORMAP()->{$color} ) ) {
            $substitute = $colorctl . $this->COLORMAP()->{$color};
        }
        else {
            $substitute = '';
        }
        $msgdata =~ s/$colortag/$substitute/;
    }
    my $timectl = pack( "C", 0xfa );
    while ( $msgdata =~ /(<t:([^>]+)>)/gi ) {
        my $timetag = $1;
        my $time    = $2;
        my $substitute;
        if ( $time =~ /^[A-J]$/ ) {
            $substitute = $timectl . $time;
        }
        else {
            $substitute = '[INVALID TIME TAG]';
        }
        $msgdata =~ s/$timetag/$substitute/;
    }

    # time / date
    $this->{data} = $msgdata;
    return $msgdata;
}

#
# For Internal Testing
#
package LedSign::BB::SerialTest;

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

LedSign::BB - send text and graphics to led signs 
 
=head1 VERSION

Version 0.92

=head1 SYNOPSIS

  #!/usr/bin/perl
  use LedSign::BB;
  #
  # add two messages then send them to a sign
  #   connected to COM3 (windows)
  #
  my $sign=LedSign::BB->new();
  $sign->queueMsg(
      data => "Message One"
  );
  $sign->queueMsg(
      data => "Message Two"
  );
  $sign->sendQueue(device => "COM3");

  #!/usr/bin/perl
  #
  # adjust the brightness on a sign 
  #  connected to /dev/ttyUSB0 (linux)
  #  value can be either: 
  #      A - Automatic Brightness 
  #      1 to 8  - Manual Brightness (1 being the brightest)
  #
  use LedSign::BB;
  my $sign=LedSign::BB->new();
  $sign->sendCmd(
      setting => "brightness",
      value => 1
  );
  $sign->sendQueue(device => "/dev/ttyUSB0");
 

=head1 DESCRIPTION

LedSign::BB is used to send text and graphics via RS232 to a specific set of programmable scrolling LED signs (BB* and SB* models from BrightLEDSigns.com) 

=head1 CONSTRUCTOR

=head2 new

  my $sign=LedSign::BB->new();

=head1 METHODS

=head2 $sign->queueMsg

Adds a text messsage to display on the sign.  The $sign->queueMsg method has only one required argument...data, which is the text to display on the sign. 

Note that this message isn't sent to the sign until you call the L<< /"$sign->send" >> method, which will then connect to the sign and send ALL messages and configuration commands (in first in, first out order) that you added with the L<< /"$sign->queueMsg" >> and L<< /"$sign->sendCmd" >> methods.

=over 4

=item B<data>

The message you want to display on the sign.  Can be either plain text, like "hello World!", or it can be marked up with font,color, and/or time tags. 
  
  # font, color, and time tag example
  $sign->queueMsg(
      data => "<f:SS7><c:YELLOW>7 pixel yellow text<f:SS10>10 pixel text<c:RED>The time is <t:A>"
  ) 
  # valid values for time tags
  # A - hh:mm:ss      B - hh:mm:ss AM/PM   C - hh:mm       D hh:mm AM/PM
  # E - mm/dd/yyyy    F - yyyy-mm-dd       G - dd.MM yyyy  H mm'dd'yyyy
  # I - short spelling of day (SUN, MON, TUE, etc)
  # I - long spelling of day (Sunday, Monday, Tuesday, etc)

Valid values for time tags are shown in the code example above. See L</"font"> for valid font values, and L</"color"> for valid color values.

Note that the message can contain a newline.  Depending on the pixel height of the font used, and the pixel height of the sign, you can display 2 or more lines of text on a sign by inserting a newline.  For example, a sign with a pixel height of 16 can display two lines of text if you use a 7 pixel high font.  These signs, however, do not support the idea of "regions", so you cannot, for example, hold the first line of text in place while the bottom line scrolls.  This is a limitation of the sign hardware, and not a limitation of this API.

  # two lines of text, assuming the sign is at least 16 pixels high
  $sign->queueMsg(
      data => "<f:SS7>This is line 1\nThis is line2",
      align => "LEFT"
  );

=item B<effect>

Optional. Valid values are: AUTO, FLASH, HOLD, INTERLOCK, ROLLDOWN, ROLLUP, ROLLIN, ROLLOUT, ROLLLEFT, ROLLRIGHT, ROTATE, SLIDE, SNOW, SPARKLE, SPRAY, STARBURST, SWITCH, TWINKLE, WIPEDOWN, WIPEUP, WIPEIN, WIPEOUT, WIPELEFT, WIPERIGHT, CYCLECOLOR, CLOCK 
 
Defaults to HOLD


=item B<speed>

Optional. An integer from 1 to 5, where 1 is the fastest 5 is the slowest

Defaults to 2.

=item B<pause>

Optional. An integer from 0 to 9, indicating how many seconds to hold the message on screen before moving to the next message

Defaults to 2.

=item B<font>

Allows you to specify the default font for the message.  Defaults to "SS7".   Note that you can use multiple fonts in a single message via the use of L<font tags in the data parameter|/"data">.

Valid values are: SS5, ST5, WD5, WS5, SS7, ST7, WD7, WS7, SDS, SRF, STF, WDF, WSF, SDF, SS10, ST10, WD10, WS10, SS15, ST15, WD15, WS15, SS24, SS31

The first two characters in the font name denote style: SS = Standard, ST = Bold, WD = Wide, WS= Wide with Shadow

The rest of the characters denote pixel height.  5 == 5 pixels high, 7 == 7 pixels high, etc.  The 'F' denotes a 7 pixel high "Fancy" font that has decorative serifs.


=item B<color>

Allows you to specify the default color for the message.  Defaults to "AUTO".   Note that you can use multiple colors in a single message via the use of L<color tags in the data parameter|/"data">.

Valid values are: AUTO, RED, GREEN, YELLOW, DIM_RED, DIM_GREEN, BROWN, AMBER, ORANGE, MIX1, MIX2, MIX3,BLACK 

=item B<align>

Allows you to specify the alignment for the message.  Defaults to "CENTER".  Unlike color and font, there are no tags.   The entire contents of the message slot will have the same alignment. 

Valid values are:  CENTER, LEFT, RIGHT

=item B<start>

Allows you to specify a start time for the message. It's a 4 digit number representing the start time in a 24 hour clock, such that 0800 would be 8am, and 1300 would be 1pm.      

Valid values: 0000 to 2359

Default value: 0000

=over

=item B<caveat>

The start, stop, and rundays parameters are only used if both of these conditions are met:

=over

=item Ensure that L</"signmode"> is set to expand

=item Ensure that L</"displaymode"> is set to bytime

=back

=back

=item B<stop>

Allows you to specify a stop time for the message. It's a 4 digit number repres
enting the stop time in a 24 hour clock, such that 0800 would be 8am, and 1300
would be 1pm.      

Valid values: 0000 to 2359

Default value: 2359

B<Note:> See the L</"caveat"> about start, stop and rundays.

=item B<rundays>

Allows you to specify which days the message should run.  It's a 7 digit binary string, meaning that the number can only have ones and zeros in it.  The first digit is Sunday, the second is Monday, and so forth.  So, for example, to run the sign only on Sunday, you would use 1000000.  To run it every day, 1111111.  Or, for example, to show it only on Monday, Wednesday, and Friday, 0101010.

Default value: 1111111

B<Note:> See the L</"caveat"> about start, stop and rundays.

=item B<slot>

Optional.  The sign has 36 message slots, numbered from 0 to 9 and A to Y.   It displays each message (a message can consist of multiple screens of text, btw), in order.  If you do not supply this argument, the API will assign the slots consecutively, starting with slot 0.  

This behavior may be useful to some people that want to, for example, keep a constant message in lower numbered slots...say 0, 1, and 2, but change a message periodicaly that sits in slot 3.  If you don't need this kind of functionality, however, just don't supply the slot argument. 
 
  #
  # example of using the slot parameter
  # 
  #
  my $sign=LedSign::BB->new();
  $sign->queueMsg(
      data => "Message Two",
      slot => 3
  );
  $sign->queueMsg(
      data => "Message One",
      slot => 4
  );
  #
  #
  $sign->sendQueue(device => "COM3");


=back



=head2 $sign->sendCmd

Adds a configuration messsage to change some setting on the sign.  The first argument, setting, is mandatory in all cases.   The second argument, value, is optional sometimes, and required in other cases.

=head3 Settings you can change, with examples

=over 4

=item B<brightness>

  #
  # adjust the brightness on a sign 
  #  value is mandatory can be 1 to 8, with 1 being the brightest,
  #    or, you can supply A as brightness, and it will adjust automatically
  #
  $sign->sendCmd(
      device => "/dev/ttyUSB0",
      setting => "brightness",
      value => 1
  );

=item B<reset>

  #
  # does a soft reset on the sign
  #   data is not erased
  #
  $sign->sendCmd(
      device => "COM4",
      setting => "reset",
  );
  $sign->sendQueue(device => "/dev/ttyUSB0");

=item B<cleardata>

  #
  # clears all data on the sign
  #  note: this command takes 30 seconds or so to process, during
  #        which time, the send method will block waiting on a response
  #  
  $sign->sendCmd(
      device => "/dev/ttyUSB1",
      setting => "cleardata",
  );
  $sign->sendQueue(device => "/dev/ttyUSB0");


=item B<setttime>

  #
  # sets the internal date and time clock on the sign. 
  # You can supply the string # "now", and it will sync the sign's clock  
  # to the time on the computer running  this api.
  #
  # You can supply an integer representing the time and date
  # as unix epoch seconds.  The perl "time" function, for example, returns
  # this type of value
  #
  $sign->sendCmd(
      device => "COM1",
      setting => "settime",
      value => "now"
  );
  $sign->sendQueue(device => "/dev/ttyUSB0");


=item B<signmode>

This sets the sign's mode to either "expand" or "basic".  

Basic Mode: All configured message slots are displayed, regardless of any programmed start and stop times.  Brightness is fixed in AUTO mode, and can't be adjusted manually.

Expand Mode: Once the sign is set to expand mode, you can manually select the display mode to either show all configured message slots, or to use the start and stop times (see L</"displaymode">).  Similarly, you can adjust the brightness manually (see L</"brightness">).

Valid values: basic, expand

  #
  # example of setting sign to expand mode
  #
  $sign->sendCmd(
      device => "/dev/ttyUSB0",
      setting => "signmode",
      value => "expand"
  );

=item B<displaymode>

This sets the sign's displaymode.  You must first set signmode to expand to use this feature (see L</"signmode">).

Setting displaymode to allslots will display all configured message slots, regardless of start and stop time settings.

Setting displaymode to bytime will dislplay configured message slots according to their defined start and stop times.  Note that the current version of this API doesn't allow you to define start and stop times for the message slots.

Valid values: allslots, bytime

  #
  # example of setting displaymode to allslots
  #
  $sign->sendCmd(
      device => "COM2",
      setting => "displaymode",
      value => "allslots"
  );

=back



=head2 $sign->send

The send method connects to the sign over RS232 and sends all the data accumulated from prior use of the $sign->queueMsg method.  The only mandatory argument is 'device', denoting which serial device to send to.

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

 You can find documentation for this module with the perldoc command.
  
   perldoc LedSign::BB
  
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



=head1 LICENSE AND COPYRIGHT

Copyright 2013 Kerry Schwab.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at: L<http://www.perlfoundation.org/artistic_license_2_0>

Aggregation of this Package with a commercial distribution is always
permitted provided that the use of this Package is embedded; that is,
when no overt attempt is made to make this Package's interfaces visible
to the end user of the commercial distribution. Such use shall not be
construed as a distribution of this Package.

The name of the Copyright Holder may not be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.


=cut

