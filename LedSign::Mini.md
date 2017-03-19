# NAME

LedSign::Mini - send text and graphics to small LED badges and signs

# VERSION

Version 1.04

# SYNOPSIS

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

# DESCRIPTION

LedSign::Mini is used to send text and graphics via RS232 to our smaller set of LED Signs and badges.  It is part of the larger LedSign module, which provides similar interfaces for other LED signs that use different protocols.

This sub-module of the larger LEDSign module is the replacement for [Device::MiniLED](http://search.cpan.org/perldoc?Device%3A%3AMiniLED), which is now deprecated. 

# CONSTRUCTOR

## new

The constructor has one optional argument...**devicetype**. If not specified, defaults to "sign".  The **devicetype** argument drives a few internal options, like rendering of images (16 pixels vs 12 pixels), support for the internal clock (signs have this, badges do not).  Plain text messages will work if this setting is wrong, but you may have issues with images and clock functionality. 

    my $buffer=LedSign::Mini->new(
           devicetype => $devicetype
    );
    # $devicetype can be either:
    #   sign  - denoting a device with a 16 pixel high display
    #   badge - denoting a device with a 12 pixel high display

# METHODS

## queueMsg

This family of devices support a maximum of 8 messages that can be sent to the sign.  These messages can consist of three different types of content, which can be mixed together in the same message..plain text, pixmap images, and 2-frame anmiated icons.

The $buffer->queueMsg method has three required arguments...effect, speed, and data:

- **effect**

    One of "hold", "scroll", "snow", "flash" or "hold+flash"

- **speed**

    An integer from 1 to 5, where 1 is the slowest and 5 is the fastest 

- **data**

    The data to be sent to the sign. Plain text, optionally with $variables that reference pixmap images or animated icons. Tags are also supported to display flashing, dates/times, and countdown functionality:

    - **Flashing Tags**

        To have a portion of the message flash on and off, you can insert the following tags. This works with no issues on badges.  For signs, the flash and normal tags are actually the same tag...they just toggle the flashing state.

            $buffer->queueMsg(
                data => "Some <f:flash>flashing text<f:normal> in a message"
            );

    - **Date and Time Tags**

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

## queuePix

The queuePix method allow you to create simple, single color pixmaps that can be inserted into a message. There are two ways to create a picture.

**Using the built-in clipart**

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

**Rolling your own pictures**

To supply your own pictures, you need to supply 3 arguments:

**height**: height of the picture in pixels 

**width**: width of the picture in pixels (max is 256)

**data** : a string of 1's and 0's, where the 1 will light up the pixel and 
a 0 won't.  You might find Image::Pbm and it's $image->as\_bitstring method
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

## queueIcon

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

## sendQueue

The sendQueue method connects to the sign over RS232 and sends all the data accumulated from prior use of the $buffer->queueMsg/Pix/Icon methods.  The only mandatory argument is 'device', denoting which serial device to send to.

It supports three optional arguments: runslots, baudrate, and packetdelay:

- **runslots**
: One of either "auto" or "none".  If the runslots parameter is not supplied, it defaults to "auto".
    - **auto** 
    : With runslots set to auto, a command is sent to the sign to display the message slots that were created by the queued messages sent to the sign.
    - **none** 
    : With runslots set to none, the messages are still sent to the sign, but no command to display them is sent. The sign will continue to run whatever numbered slots it was showing before the new messages were sent.  Using this in combination with the $buffer->sendCmd(runslots,@slots) command allows you full control over which messages are displayed, and when.
- **baudrate**
: defaults to 38400, no real reason to use something other than the default, but it's there if you feel the need.  Must be a value that [Device::SerialPort](http://search.cpan.org/perldoc?Device%3A%3ASerialPort) or [Win32::Serialport](http://search.cpan.org/perldoc?Win32%3A%3ASerialPort) thinks is valid
- **packetdelay**
: An amount of time, in seconds, to wait, between sending packets to the sign.  The default is 0.25, and seems to work well.  If you see "XX" on your sign while sending data, increasing this value may help. Must be greater than zero.  For reference, each text message generates 3 packets, and each 16x32 portion of an image sends one packet.  There's also an additional, short, packet sent after all message and image packets are delivered. So, if you make packetdelay a large number...and have lots of text and/or images, you may be waiting a while to send all the data.

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

## sendCmd

Sends a messsage, typically to change some setting on the sign.  Since it's sending to the sign immediately, it has a mandatory **device** argument which works the same as in the ["sendQueue"](#sendqueue) method.  It also supports the **baudrate** and **packetdelay** arguments. See the ["sendQueue"](#sendqueue) method for detail on these arguments.

The argument which specifies the command to send, **cmd**, is mandatory in all cases.   The next argument, **value**, is optional sometimes, and required in other cases.  

Settings you can change, with examples:

- **runslots**

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

- **settime**

    Setting the sign's time is helpful if you plan on using the ["Date and Time Tags"](#date-and-time-tags) in a message.

    The settime command sets the current time and date on the internal clock on the sign.  Supported only for signs...badges don't have an internal clock.  Accepts the time as a unix epoch value, like you would get from time() or the epoch method from [Time::Piece](http://perldoc.perl.org/Time/Piece.html).  If you supply the string "now" as the value, the API will internally substitute the current value of time().

        #
        $buffer->sendCmd(
            device => '/dev/ttyUSB0',
            cmd => "settime",
            value => time()
        );

- **setcountdown**

    Setting the sign's countdown target time is helpful if you plan on using the ["Date and Time Tags"](#date-and-time-tags) in a message.

    The setcountdown command sets the target time and date for the countdown timer that's within the the internal clock on the sign.  Supported only for signs...badges don't have an internal clock.  Accepts the target time as a unix epoch value, like you would get from time() or the epoch method from [Time::Piece](http://perldoc.perl.org/Time/Piece.html).

        # set the countdown timer to 10 days from now
        my $countdownto=time() + (10*60*60*24);
        $buffer->sendCmd(
            device => '/dev/ttyUSB0',
            cmd => "setcountdown",
            value => time
        );

    **Note**: Make sure you use the ["settime"](#settime) command to set the internal time...the countdown functionality depends on the current time being set correctly on the sign.

# AUTHOR

Kerry Schwab, `<sales at brightledsigns.com>`

# SUPPORT

You can find documentation for this module with the perldoc command.  `perldoc LedSign::Mini`

You can also look for information at:

- Our Website:
[http://www.brightledsigns.com/developers](http://www.brightledsigns.com/developers)
- Github:
[https://github.com/BrightLedSigns/LedSign/blob/master/LedSign%3A%3AMini.md](https://github.com/BrightLedSigns/LedSign/blob/master/LedSign%3A%3AMini.md)
- Meta CPAN
[https://metacpan.org/release/LedSign](https://metacpan.org/release/LedSign)

# BUGS

Please report any bugs or feature requests to
`bug-device-miniled at rt.cpan.org`, or through the web interface at
[http://rt.cpan.org](http://rt.cpan.org).  I will be notified, and then you'll automatically be
notified of progress on your bug as I make changes.

# ACKNOWLEDGEMENTS

Inspiration from similar work:

- [http://zunkworks.com/ProgrammableLEDNameBadges](http://zunkworks.com/ProgrammableLEDNameBadges) - Some code samples for different types of LED badges
- [https://github.com/ajesler/ledbadge-rb](https://github.com/ajesler/ledbadge-rb) - Python library that appears to be targeting signs with a very similar protocol. 
- [http://search.cpan.org/~mspencer/ProLite-0.01/ProLite.pm](http://search.cpan.org/~mspencer/ProLite-0.01/ProLite.pm) - The only other CPAN perl module I could find that does something similar, albeit for a different type of sign.

# LICENSE AND COPYRIGHT

Copyright (c) 2013 Kerry Schwab & Bright Signs
All rights reserved.

This program is free software; you can redistribute it and/or modify it under the terms of the the FreeBSD License . You may obtain a copy of the full license at:

[http://www.freebsd.org/copyright/freebsd-license.html](http://www.freebsd.org/copyright/freebsd-license.html)

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
- Neither the name of the organization nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
