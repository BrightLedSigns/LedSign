# NAME

LedSign::M500 - send text and graphics to led signs 
 

# VERSION

Version 0.92

# SYNOPSIS

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
    

# DESCRIPTION

LedSign::M500 is used to send text and graphics via RS232 to a specific set of programmable scrolling LED signs (BB\* and SB\* models from BrightLEDSigns.com) 

# CONSTRUCTOR

## new

    my $sign=LedSign::M500->new();

# METHODS

## $sign->queueMsg

Adds a text messsage to display on the sign.  The $sign->queueMsg method has only one required argument...data, which is the text to display on the sign. 

Note that this message isn't sent to the sign until you call the ["$sign->send"](#sign-send) method, which will then connect to the sign and send ALL messages and configuration commands (in first in, first out order) that you added with the ["$sign->queueMsg"](#sign-queuemsg) and ["$sign->sendCmd"](#sign-sendcmd) methods.

- __data__

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

    Valid values for time tags are shown in the code example above. See ["font"](#font) for valid font values, and ["color"](#color) for valid color values.

    Note that the message can contain a newline.  Depending on the pixel height of the font used, and the pixel height of the sign, you can display 2 or more lines of text on a sign by inserting a newline.  For example, a sign with a pixel height of 16 can display two lines of text if you use a 7 pixel high font.  These signs, however, do not support the idea of "regions", so you cannot, for example, hold the first line of text in place while the bottom line scrolls.  This is a limitation of the sign hardware, and not a limitation of this API.

        # two lines of text, assuming the sign is at least 16 pixels high
        $sign->queueMsg(
            data => "<f:SS7>This is line 1\nThis is line2",
            align => "LEFT"
        );

- __effect__

    Optional. Valid values are: AUTO, FLASH, HOLD, INTERLOCK, ROLLDOWN, ROLLUP, ROLLIN, ROLLOUT, ROLLLEFT, ROLLRIGHT, ROTATE, SLIDE, SNOW, SPARKLE, SPRAY, STARBURST, SWITCH, TWINKLE, WIPEDOWN, WIPEUP, WIPEIN, WIPEOUT, WIPELEFT, WIPERIGHT, CYCLECOLOR, CLOCK 
     

    Defaults to HOLD



- __speed__

    Optional. An integer from 1 to 5, where 1 is the fastest 5 is the slowest

    Defaults to 2.

- __pause__

    Optional. An integer from 0 to 9, indicating how many seconds to hold the message on screen before moving to the next message

    Defaults to 2.

- __font__

    Allows you to specify the default font for the message.  Defaults to "SS7".   Note that you can use multiple fonts in a single message via the use of [font tags in the data parameter](#data).

    Valid values are: SS5, ST5, WD5, WS5, SS7, ST7, WD7, WS7, SDS, SRF, STF, WDF, WSF, SDF, SS10, ST10, WD10, WS10, SS15, ST15, WD15, WS15, SS24, SS31

    The first two characters in the font name denote style: SS = Standard, ST = Bold, WD = Wide, WS= Wide with Shadow

    The rest of the characters denote pixel height.  5 == 5 pixels high, 7 == 7 pixels high, etc.  The 'F' denotes a 7 pixel high "Fancy" font that has decorative serifs.



- __color__

    Allows you to specify the default color for the message.  Defaults to "AUTO".   Note that you can use multiple colors in a single message via the use of [color tags in the data parameter](#data).

    Valid values are: AUTO, RED, GREEN, YELLOW, DIM\_RED, DIM\_GREEN, BROWN, AMBER, ORANGE, MIX1, MIX2, MIX3,BLACK 

- __align__

    Allows you to specify the alignment for the message.  Defaults to "CENTER".  Unlike color and font, there are no tags.   The entire contents of the message slot will have the same alignment. 

    Valid values are:  CENTER, LEFT, RIGHT

- __start__

    Allows you to specify a start time for the message. It's a 4 digit number representing the start time in a 24 hour clock, such that 0800 would be 8am, and 1300 would be 1pm.      

    Valid values: 0000 to 2359

    Default value: 0000

    - __caveat__

        The start, stop, and rundays parameters are only used if both of these conditions are met:

        - Ensure that ["signmode"](#signmode) is set to expand
        - Ensure that ["displaymode"](#displaymode) is set to bytime

- __stop__

    Allows you to specify a stop time for the message. It's a 4 digit number repres
    enting the stop time in a 24 hour clock, such that 0800 would be 8am, and 1300
    would be 1pm.      

    Valid values: 0000 to 2359

    Default value: 2359

    __Note:__ See the ["caveat"](#caveat) about start, stop and rundays.

- __rundays__

    Allows you to specify which days the message should run.  It's a 7 digit binary string, meaning that the number can only have ones and zeros in it.  The first digit is Sunday, the second is Monday, and so forth.  So, for example, to run the sign only on Sunday, you would use 1000000.  To run it every day, 1111111.  Or, for example, to show it only on Monday, Wednesday, and Friday, 0101010.

    Default value: 1111111

    __Note:__ See the ["caveat"](#caveat) about start, stop and rundays.

- __slot__

    Optional, and NOT recommended, because it's somewhat confusing.  The sign has 36 message slots, numbered from 0 to 9 and A to Z.   It displays each message (a message can consist of multiple screens of text, btw), in order.  If you do not supply this argument, the API will assign the slots consecutively, starting with slot 0.  The reason we don't recommend using the slot parameter is that, because of how the sign works, specifying a slot erases all other slots that have a higher number.  For example, if you send something specifically to slot 8, the contents of slots 9, and A-Z, will be erased.   The contents in slots 0-7, however, will remain intact.

    This behavior may be useful to some people that want to, for example, keep a constant message in lower numbered slots...say 0, 1, and 2, but change a message periodicaly that sits in slot 3.  If you don't need this kind of functionality, however, just don't supply the slot argument. 
     

        #
        # example of using the slot parameter INCORRECTLY
        #  "Message Two" will never show.
        #  Every time you use slot, all higher numbered slots are erased.
        #  So, because these are sent out of order, the message in slot 1 is erased
        my $sign=LedSign::M500->new();
        $sign->queueMsg(
            data => "Message Two",
            slot => 1
        );
        $sign->queueMsg(
            data => "Message One",
            slot => 0
        );
        #
        #
        $sign->sendQueue(device => "COM3");

        #
        # example of using the slot parameter CORRECTLY
        #   since these slots are in consecutive order (3, then 4), neither will
        #   be erased 
        # 
        #   also, if the sign already had messages in slots 0, 1, or 2, they will continue
        #   to be shown.
        # 
        #   however, any message running on the sign with a message slot higher 
        #   than 4 would have been erased 
        #
        my $sign=LedSign::M500->new();
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







## $sign->sendCmd

Adds a configuration messsage to change some setting on the sign.  The first argument, setting, is mandatory in all cases.   The second argument, value, is optional sometimes, and required in other cases.

### Settings you can change, with examples

- __alarm__

        #
        # turn the alarm on or off
        #
        $sign->sendCmd(
            setting => "alarm",
            value => "on",
        );
        $sign->sendQueue(device => "/dev/ttyUSB0");
- __setttime__

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
            setting => "settime",
            value => "now"
        );
        $sign->sendQueue(device => "/dev/ttyUSB0");
- __test__

        # display a test pattern on the sign, where every LED is lit
        $sign->sendCmd(
            setting => "test",
        );
        $sign->sendQueue(device => "/dev/ttyUSB0");





## $sign->send

The send method connects to the sign over RS232 and sends all the data accumulated from prior use of the $sign->queueMsg method.  The only mandatory argument is 'device', denoting which serial device to send to.

It supports one optional argument: baudrate

- __baudrate__: defaults to 9600, no real reason to use something other than the default, but it's there if you feel the need.  Must be a value that Device::Serialport or Win32::Serialport thinks is valid

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

# AUTHOR

Kerry Schwab, `<sales at brightledsigns.com>`

# SUPPORT

    You can find documentation for this module with the perldoc command.
     
     perldoc LedSign::M500
    
    You can also look for information at:

- Our Website:
[http://www.brightledsigns.com/developers](http://www.brightledsigns.com/developers)

# BUGS

Please report any bugs or feature requests to
`bug-device-miniled at rt.cpan.org`, or through the web interface at
[http://rt.cpan.org](http://rt.cpan.org) .  I will be notified, and then you'll automatically be
notified of progress on your bug as I make changes.

# ACKNOWLEDGEMENTS

Inspiration from similar work:

- [ProLite Perl Module](https://metacpan.org/pod/ProLite) - The only other CPAN perl module I could find that does something similar, albeit for a different type of sign.





# LICENSE AND COPYRIGHT

Copyright 2013 Kerry Schwab.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at: [http://www.perlfoundation.org/artistic_license_2_0](http://www.perlfoundation.org/artistic_license_2_0)

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


