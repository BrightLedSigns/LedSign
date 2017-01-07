# NAME

LedSign::M500 - send text and graphics to led signs 

# VERSION

Version 1.02

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

- **data**

    The message you want to display on the sign.  Can be either plain text, like "hello World!", or it can be marked up with font,color, and/or time tags. 

    Valid values for time tags are shown in the code example above. See ["font"](#font) for valid font values, and ["color"](#color) for valid color values.

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

- **effect**

    Optional. Valid values are: AUTO, COVERDOWN, COVERFROMCENTER, COVERFROMLEFT, COVERFROMRIGHT, COVERTOCENTER, COVERUP, CYCLIC, EXPLODE, FLASH, IMMEDIATE, INTERLACE1, INTERLACE2, OPENFROMCENTER, OPENFROMLEFT, OPENFROMRIGHT, OPENTOCENTER, PACMAN, RANDOM, SCANLINE, SCROLLDOWN, SCROLLUP, SHOOT, SLIDEIN, STACK. Defaults to AUTO.

- **speed**

    Optional. An integer from 1 to 5, where 1 is the fastest 5 is the slowest

    Defaults to 2.

- **pause**

    Optional. An integer from 0 to 9, indicating how many seconds to hold the message on screen before moving to the next message

    Defaults to 2.

- **font**

    Allows you to specify the default font for the message.  Defaults to "7X6".   Note that you can use multiple fonts in a single message via the use of [font tags in the data parameter](#data).

    Valid values are: SHORT, WIDE, EXTRAWIDE, 7X6, SHORTWIDE, 7X9, and SMALL.

- **color**

    Allows you to specify the default color for the message.  Defaults to "RED".   Note that you can use multiple colors in a single message via the use of [color tags in the data parameter](#data).

    Valid values are: RED, BRIGHTRED, ORANGE,  BRIGHTORANGE, YELLOW, BRIGHTYELLOW, GREEN, BRIGHTGREEN, LAYERMIX, BRIGHTLAYERMIX, VERTICALMIX, SAWTOOTHMIX, REDONGREEN, YELLOWONGREEN

- **start**

    Allows you to specify a start time for the message. It's a 4 digit number representing the start time in a 24 hour clock, such that 0800 would be 8am, and 1300 would be 1pm.      

    Valid values: 0000 to 2359

    Default value: 0000

- **stop**

    Allows you to specify a stop time for the message. It's a 4 digit number repres
    enting the stop time in a 24 hour clock, such that 0800 would be 8am, and 1300
    would be 1pm.      

    Valid values: 0000 to 2359

    Default value: 2359

- **rundays**

    Allows you to specify which days the message should run.  It's a 7 digit binary string, meaning that the number can only have ones and zeros in it.  The first digit is Sunday, the second is Monday, and so forth.  So, for example, to run the sign only on Sunday, you would use 1000000.  To run it every day, 1111111.  Or, for example, to show it only on Monday, Wednesday, and Friday, 0101010.

    Default value: 1111111

- **slot**

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

## $sign->sendCmd

Adds a configuration messsage to change some setting on the sign.  The first argument, setting, is mandatory in all cases.   The second argument, value, is optional sometimes, and required in other cases.

Settings you can change, with examples:

- **alarm**

        #
        # turn the alarm on or off
        #
        $sign->sendCmd(
            setting => "alarm",
            value => "on",
        );
        $sign->sendQueue(device => "/dev/ttyUSB0");

- **setttime**

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

- **test**

        # display a test pattern on the sign, where every LED is lit
        $sign->sendCmd(
            setting => "test",
        );
        $sign->sendQueue(device => "/dev/ttyUSB0");

## $sign->sendQueue

The sendQueue method connects to the sign over RS232 and sends all the data accumulated from prior use of the $sign->queueMsg method.  The only mandatory argument is 'device', denoting which serial device to send to.

It supports one optional argument: baudrate

- **baudrate**: defaults to 9600, no real reason to use something other than the default, but it's there if you feel the need.  Must be a value that Device::Serialport or Win32::Serialport thinks is valid

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

You can find documentation for this module with the perldoc command.  `perldoc LedSign::M500`

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
