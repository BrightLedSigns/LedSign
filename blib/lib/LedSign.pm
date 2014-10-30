package LedSign;
use Carp;
use strict;
use warnings;
use 5.008001;
$LedSign::VERSION="0.01";
#
# Use Win32::Serial port on Windows otherwise, use Device::SerialPort
#;
BEGIN 
{
   my $IS_WINDOWS = ($^O eq "MSWin32" or $^O eq "cygwin") ? 1 : 0;
   #
   if ($IS_WINDOWS) {
      eval "use Win32::SerialPort 0.14";
      die "$@\n" if ($@);
   } else {
      eval "use Device::SerialPort";
      die "$@\n" if ($@);
   }
}

sub new {
    my $that  = shift;
    my $class = ref($that) || $that;
    my(%params) = @_;
    my $this = {};
    bless $this, $class;
    $this->_init(%params);
    $this->{tags}=();
    $this->initslots();
    return $this;
}
sub flush {
    my $this=shift; 
    $this->{tags}=();
    $this->_flush();
}
sub connect {
    my $this=shift;
    my(%params)=@_;
    my $serial;
    my $port=$params{device};
    my $baudrate=$params{baudrate};
    if ( defined( $params{baudrate} ) ) {
        $baudrate=$this->checkbaudrate( $params{baudrate} );
    } else {
        $baudrate = $this->DEFAULTSERIAL()->{baudrate};
    }
    my $packetdelay;
    if ( defined( $params{packetdelay} ) ) {
        if ( $params{packetdelay} =~ m#^\d*\.{0,1}\d*$# ) {
            $packetdelay = $params{packetdelay};
        }
        else {
            croak(  'Invalid value ['
                  . $params{packetdelay}
                  . '] for parameter packetdelay' );
        }
    } else {
        $packetdelay = $this->DEFAULTSERIAL()->{packetdelay};
    }

    my $IS_WINDOWS = ($^O eq "MSWin32" or $^O eq "cygwin") ? 1 : 0;
    if ($IS_WINDOWS) {
      $serial = new Win32::SerialPort ($port, 1);
    } else {
      $serial = new Device::SerialPort ($port, 1);
    }
    croak("Can't open serial port $port: $^E\n") unless ($serial);
    # set serial parameters
    $serial->baudrate($baudrate);
    $serial->parity('none');
    $serial->databits(8);
    $serial->stopbits(1);
    $serial->handshake('none');
    $serial->write_settings();
    return $serial;
}
sub initslots {
    my $this=shift;
    my @slotrange=$this->SLOTRANGE();
    @{$this->{slotrange}}=@slotrange;
    @{$this->{freeslots}}=@slotrange;
    $this->{usedslots}=[];
}
sub setslot {
    my $this=shift;
    my $slot=shift;
    if (defined($slot)) {
        if (grep {$_ eq $slot}  @{$this->{freeslots}}) {
            push(@{$this->{usedslots}},$slot);
            @{$this->{freeslots}}=grep {$_ ne $slot} @{$this->{freeslots}};
            return $slot
        } else {
           croak("Slot [$slot] not available\n");
        }
    } else {
          if (@{$this->{freeslots}} > 0) {
              my $newslot=shift(@{$this->{freeslots}});
              push(@{$this->{usedslots}},$newslot);
              return $newslot
          } else {
              croak("Out of slots\n");
          }
    }
}
#
# setkey and getkey to store and retrieve
# data using a key 
#
sub setkey {
    my $this=shift;
    my $object=shift;
    my $number=0;
    my $tag=sprintf("<i:%d>",$number);
    while (exists($this->{tags}{$tag})) {
        $tag=sprintf("<i:%d>",$number);
        $number++;
    }
    my $msgref=$object->{msgref};
    $this->{tags}{$tag}=$object->{msgref};
    return $tag;
}
sub getkey {
    my $this=shift;
    my $tag=shift;
    if (exists($this->{tags}{$tag})) {
        return $this->{tags}{$tag};
    } else {
        return "<error>";
    }
}
1;
package LedSign::Factory;
sub new {
    my $that  = shift;
    my $class = ref($that) || $that;
    my(%params) = @_;
    my @objtypes=$params{objtypes};
    my $this = {};
    bless $this, $class;
    $this->{tags}=();
    $this->_init(%params);
    return $this;
}
sub _init {
    my( $package, $filename, $line ) = caller;
    die("Subclass must implement _init method for package [$package]");
}
sub add_object {
    my $this=shift;
    my $object=shift;
    my $objtype=$object->{objtype};
    my( $package, $filename, $line ) = caller;
    if (!defined($object->{objtype})) {
       croak("add_object: No object type supplied");
    }
    push(@{$this->{objects}{$object->{objtype}}},$object);
    my $count=$this->{$objtype."count"}++;
    $object->{number}=$count;
    return $count;
}
sub objects {
    my $this=shift;
    my $objtype=shift;
    if (!defined($objtype)) {
        croak("objects: No object type supplied");
    }
    if (!exists ($this->{objects}{$objtype})) {
        return ();
    }
    return(@{$this->{objects}{$objtype}});
}
1;


=head1 NAME

LedSign - Perl library to communicate with various models of programmable LED signs

=head1 VERSION

Version 1.00

=head1 DESCRIPTION

The LedSign library is used to send text and graphics to different models of programmable LED signs. We tried to keep the interface consistent across models, and only introduced per-model variations where the underlying capabilities of the sign were different enough to warrant it.  

It has been tested on both Linux and Windows, and should theoretically run anywhere where the L<Device::SerialPort|http://search.cpan.org/perldoc?Device%3A%3ASerialPort> or L<Win32::SerialPort|http://search.cpan.org/perldoc?Win32%3A%3ASerialPort> modules can be  run.  

=head1 SYNOPSIS

  #
  # "M500" is one specific model
  # For a different model, like the Mini signs, you
  # would do:
  #   use LedSign::Mini;
  #
  use LedSign::M500;
  my $buffer=LedSign::Mini->new(devicetype => "sign");
  #
  # queueMsg queues a message to be sent with the sendQueue method
  #
  $buffer->queueMsg( data => "Hello World!");
  # queue up another message
  $buffer->queueMsg( data => "Another message");
  # send the messages to the sign.
  $buffer->sendQueue(
      device => '/dev/ttyUSB0'
  )
  # note that sending the queued messages does not flush them, so 
  # if you wanted to send this message to another sign, on a different
  # port, you could uncomment what's below
  # $buffer->sendQueue(
  #   device=>'/dev/ttyUSB1'
  # ); 

=head1 USAGE

Since each of the supported signs is a bit different in terms of capability, the usage docs are within the documentation for each type of sign:

=over 2

=item *

L<LedSign::Mini|http://search.cpan.org/perldoc?LedSign%3A%3AMini> - For our smaller, inexpensive LED badges and signs.  It probably works with most LED badges that are 12x36 or 12x48 pixels, as they come from the same manufacturer.  It probably also works with most 16 pixel high LED signs that are sold as "desktop" led signs.  

=item * 

L<LedSign::M500|http://search.cpan.org/perldoc?LedSign%3A%3AM500> - For signs on our website that have a model number starting with M500, M1000, or M1500.  It's a very popular, low-cost, single line series of signs available from many sellers.  If the original windows software is entited "single line", "taioping", or "messager (sic)", and the communications settings require 9600 baud, this library will likely work with the sign.  M500 signs that require 2400 baud use an older, incompatible protocol, and won't work with this software.
 
=item *

L<LedSign::BB|http://search.cpan.org/perldoc?LedSign%3A%3ABB> - For signs that we have labeled with product id's that start with BB or SB.  It should also work with signs where the original windows-based software is called "Wonderful LED 2006" or "Moving Sign 2007".  

=back

Depending on the model of sign, there may be support for various features

=over 2

=item * 

fonts and colors

=item *
effects (scrolling left, dropping in like snow, flashing, etc) 

=item *

current time and/or date

=item *

using specific message slots

=item *

clearing the message queue

=item *

simple bitmap or pixmap graphics

=back

=head1 RELATED SOFTWARE

=over

=item *

The L<LedSign::Mini|http://search.cpan.org/perldoc?LedSign%3A%3AMini> portion of this module supercedes the previous, standalone, L<Device::MiniLED|http://search.cpan.org/perldoc?Device%3A%3AMiniLED> module that supported the same type of sign.  Aside from supporting a wider variety of signs, this module includes bug fixes and features that will not be backported to the older module.

=item *

We also created and maintain a python library, called L<pyledsign|https://github.com/BrightLedSigns/pyledsign> that is mostly a straight port of this software to the L<Python|http://www.python.org/> language.  Because it is ported from this software, it typically lags a bit in feature and/or model support.

=back

=head1 AUTHOR

Kerry Schwab, L<sales@brightledsigns.com|mailto:sales@brightledsigns.com>

I am the owner of L<BrightLEDSigns.com|http://www.brightledsigns.com/>.  Our programmable LED signs, many of which work with this library, are located here: L<Programmable Signs|http://www.brightledsigns.com/scrolling-led-signs.html>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2013 Kerry Schwab & Bright Signs
All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of the the FreeBSD License . You may obtain a
copy of the full license at:

L<http://www.freebsd.org/copyright/freebsd-license.html|http://www.freebsd.org/copyright/freebsd-license.html>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
=over

=item *
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

=item *
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

=item *
Neither the name of the <organization> nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

=back

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
