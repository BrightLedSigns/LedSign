# NAME

LedSign - Perl library to communicate with various models of programmable LED signs

# VERSION

Version 1.02

# DESCRIPTION

The LedSign library is used to send text and graphics to different models of programmable LED signs. We tried to keep the interface consistent across models, and only introduced per-model variations where the underlying capabilities of the sign were different enough to warrant it.  

It has been tested on both Linux and Windows, and should theoretically run anywhere where the [Device::SerialPort](http://search.cpan.org/perldoc?Device%3A%3ASerialPort) or [Win32::SerialPort](http://search.cpan.org/perldoc?Win32%3A%3ASerialPort) modules can be  run.  

Note for Windows users: [Win32::SerialPort](http://search.cpan.org/perldoc?Win32%3A%3ASerialPort) is broken on most 64 bit installations of Perl for Windows.  Either use a 32 bit Perl install, or see [this bug](https://rt.cpan.org/Public/Bug/Display.html?id=113337) that has a comment on how to fix it manually. 

# SYNOPSIS

```perl
    #
    # "M500" is one specific model
    # For a different model, like the Mini signs, you
    # would do:
    #   use LedSign::Mini;
    #
    use LedSign::M500;
    my $buffer=LedSign::M500->new();
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
```

# USAGE

Since each of the supported signs is a bit different in terms of capability, the usage docs are within the documentation for each type of sign:

- [LedSign::Mini](./LedSign%3A%3AMini.md) - For our smaller, inexpensive LED badges and signs.  It probably works with most LED badges that are 12x36 or 12x48 pixels, as they come from the same manufacturer.  It probably also works with most 16 pixel high LED signs that are sold as "desktop" led signs.  
- [LedSign::M500](./LedSign%3A%3AM500.md) - For signs on our website that have a model number starting with M500, M1000, or M1500.  It's a very popular, low-cost, single line series of signs available from many sellers.  If the original windows software is entited "single line", "taioping", or "messager (sic)", and the communications settings require 9600 baud, this library will likely work with the sign.  M500 signs that require 2400 baud use an older, incompatible protocol, and won't work with this software.
 
- [LedSign::BB](./LedSign%3A%3ABB.md) - For signs that we have labeled with product id's that start with BB or SB.  It should also work with signs where the original windows-based software is called "Wonderful LED 2006" or "Moving Sign 2007".  

Depending on the model of sign, there may be support for various features

- fonts and colors
- effects (scrolling left, dropping in like snow, flashing, etc) 
- current time and/or date
- using specific message slots
- clearing the message queue
- simple bitmap or pixmap graphics

# RELATED SOFTWARE

- The [LedSign::Mini](./LedSign%3A%3AMini.md) portion of this module supercedes the previous, standalone, [Device::MiniLED](http://search.cpan.org/perldoc?Device%3A%3AMiniLED) module that supported the same type of sign.  Aside from supporting a wider variety of signs, this module includes bug fixes and features that will not be backported to the older module.
- We also created and maintain a python library, called [pyledsign](https://github.com/BrightLedSigns/pyledsign) that is mostly a straight port of this software to the [Python](http://www.python.org/) language.  Because it is ported from this software, it typically lags a bit in feature and/or model support.

# AUTHOR

Kerry Schwab, [sales@brightledsigns.com](mailto:sales@brightledsigns.com)

I am the owner of [BrightLEDSigns.com](http://www.brightledsigns.com/).  Our programmable LED signs, many of which work with this library, are located here: [Programmable Signs](http://www.brightledsigns.com/scrolling-led-signs.html).

# LICENSE AND COPYRIGHT

Copyright (c) 2013 Kerry Schwab & Bright Signs
All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of the the FreeBSD License . You may obtain a
copy of the full license at:

[http://www.freebsd.org/copyright/freebsd-license.html](http://www.freebsd.org/copyright/freebsd-license.html)

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
=over

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
- Neither the name of the <organization> nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
