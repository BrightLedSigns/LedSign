# NAME

LedSign::Mini - send text and graphics to small LED badges and signs
 

# VERSION

Version 1.00

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

# CONSTRUCTOR

## new

    my $buffer=LedSign::Mini->new(
           devicetype => $devicetype
    );
    # $devicetype can be either:
    #   sign  - denoting a device with a 16 pixel high display
    #   badge - denoting a device with a 12 pixel high display

# METHODS

## $buffer->queueMsg

This family of devices support a maximum of 8 messages that can be sent to the sign.  These messages can consist of three different types of content, which can be mixed together in the same message..plain text, pixmap images, and 2-frame anmiated icons.

The $buffer->queueMsg method has three required arguments...data, effect, and speed:

- __data__:   The data to be sent to the sign. Plain text, optionally with $variables that reference pixmap images or animated icons
- __effect__: One of "hold", "scroll", "snow", "flash" or "hold+flash"
- __speed__:  An integer from 1 to 5, where 1 is the slowest and 5 is the fastest 

The queueMsg method returns a number that indicates how many messages have been created.  This may be helpful to ensure you don't try to add a 9th message, which will fail:

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

## $buffer->queuePix

The queuePix method allow you to create simple, single color pixmaps that can be inserted into a message. There are two ways to create a picture.

__Using the built-in clipart__

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

__Rolling your own pictures__

To supply your own pictures, you need to supply 3 arguments:

__height__: height of the picture in pixels 

__width__: width of the picture in pixels (max is 256)

__data__ : a string of 1's and 0's, where the 1 will light up the pixel and 
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



## $buffer->queueIcon

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

## $buffer->sendQueue

The sendQueue method connects to the sign over RS232 and sends all the data accumulated from prior use of the $buffer->queueMsg/Pix/Icon methods.  The only mandatory argument is 'device', denoting which serial device to send to.

It supports three optional arguments: runslots, baudrate, and packetdelay:

- __runslots__: One of either "auto" or "none".  If the runslots parameter is not supplied, it defaults to "auto".
    - auto - with runslots set to auto, a command is sent to the sign to display the message slots that were created by the queued messages sent to the sign.
    - none - with runslots set to none, the messages are still sent to the sign, but no command to display them is sent. The sign will continue to run whatever numbered slots it was showing before the new messages were sent.  Using this in combination with the $buffer->sendCmd(runslots,@slots) command allows you full control over which messages are displayed, and when.
- __baudrate__: defaults to 38400, no real reason to use something other than the default, but it's there if you feel the need.  Must be a value that Device::Serialport or Win32::Serialport thinks is valid
- __packetdelay__: An amount of time, in seconds, to wait, between sending packets to the sign.  The default is 0.25, and seems to work well.  If you see "XX" on your sign while sending data, increasing this value may help. Must be greater than zero.  For reference, each text message generates 3 packets, and each 16x32 portion of an image sends one packet.  There's also an additional, short, packet sent after all message and image packets are delivered. So, if you make packetdelay a large number...and have lots of text and/or images, you may be waiting a while to send all the data.



    # typical use on a windows machine
    $buffer->sendQueue(
        device => "COM4"
    );
    # typical use on a unix/linux machine
    $buffer->sendQueue(
        device => "/dev/ttyUSB0"
    );
    # using optional arguments, set baudrate to 9600, and sleep 1/2 a second
    # between sending packets.  
    $buffer->sendQueue(
        device => "COM8",
        baudrate => "9600",
        packetdelay => 0.5
    );

Note that if you have multiple connected signs, you can send to them without creating a new object:

    # send to the first sign
    $buffer->sendQueue(device => "COM4");
    # send to another sign
    $buffer->sendQueue(device => "COM6");
    # send to a badge connected on COM7
    #   this works fine for plain text, but won't work well for
    #   pictures and icons...you'll have to create a new
    #   sign object with devicetype "badge" for them to render correctly
    $buffer->sendQueue(device => "COM7"); 

# AUTHOR

Kerry Schwab, `<sales at brightledsigns.com>`

# SUPPORT

    You can find documentation for this module with the perldoc command.
     
     perldoc LedSign::Mini
    
    You can also look for information at:

- Our Website:
[http://www.brightledsigns.com/developers](http://www.brightledsigns.com/developers)

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

Copyright 2013 Kerry Schwab.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

[http://www.perlfoundation.org/artistic_license_2_0](http://www.perlfoundation.org/artistic_license_2_0)

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


