/*==============================================================================
Wikiwyg - Turn any HTML div into a wikitext /and/ wysiwyg edit area.

DESCRIPTION:

Wikiwyg is a Javascript library that can be easily integrated into any
wiki or blog software. It offers the user multiple ways to edit/view a
piece of content: Wysiwyg, Wikitext, Raw-HTML and Preview.

The library is easy to use, completely object oriented, configurable and
extendable.

See the Wikiwyg documentation for details.

SYNOPSIS:

From anywhere you can produce a message box with a call like this:

    this.wikiwyg.message.display({
        title: 'Foo button does not work in Bar mode',
        body: 'To use the Foo button you should first switch to Baz mode'
    });

AUTHORS:

    Brian Ingerson <ingy@cpan.org>
    Casey West <casey@geeknest.com>
    Chris Dent <cdent@burningchrome.com>
    Matt Liggett <mml@pobox.com>
    Ryan King <rking@panoptic.com>
    Dave Rolsky <autarch@urth.org>

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation 
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

Wikiwyg is free software. 

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

/*==============================================================================
NLW Message Center Class
 =============================================================================*/
 
proto = Subclass('Wikiwyg.MessageCenter');
klass = Wikiwyg.MessageCenter;
klass.closeTimer = null;

proto.messageCenter = 'st-message-center';
proto.messageCenterTitle = 'st-message-center-title';
proto.messageCenterBody = 'st-message-center-body';
proto.messageCenterControlClose = 'st-message-center-control-close';
proto.messageCenterControlArrow = 'st-message-center-control-arrow';
proto.closeDelayDefault = 10;

proto.display = function (args) {
    this.closeDelay = 
        (args.timeout ? args.timeout : this.closeDelayDefault) * 1000;
    $(this.messageCenterTitle).innerHTML = args.title;
    $(this.messageCenterBody).innerHTML = args.body;
    var msgCenter = $(this.messageCenter);

    if (! msgCenter) {
        return;
    }

    msgCenter.style.display = 'block';
    this.setCloseTimer();
    this.installEvents();
    this.installControls();
};
proto.clearCloseTimer = function () {
    if (klass.closeTimer)
        window.clearTimeout(klass.closeTimer);
};
proto.setCloseTimer = function () {
    this.clearCloseTimer();
    var self = this;
    klass.closeTimer = window.setTimeout(
        function () { self.closeMessageCenter() },
        this.closeDelay
    );
};
proto.closeMessageCenter = function () {
    var msgCenter = $(this.messageCenter);
    if (! msgCenter) {
        return;
    }
    msgCenter.style.display = 'none';
    this.closeMessage();
    this.clearCloseTimer();
};
proto.clear = proto.closeMessageCenter;
proto.installEvents = function () {
    var msgCenter = $(this.messageCenter);
    var self = this;
    msgCenter.onmouseover = function () { self.openMessage() }
    msgCenter.onmouseout  = function () { self.closeMessage() }
};
proto.openMessage = function () {
    this.clearCloseTimer();
    $(this.messageCenterControlArrow).src
        = $(this.messageCenterControlArrow).src.replace(
              /right/,
              'down'
          );
    $(this.messageCenterBody).style.display
        = 'block';
};
proto.closeMessage = function () {
    this.setCloseTimer();
    $(this.messageCenterControlArrow).src
        = $(this.messageCenterControlArrow).src.replace(
              /down/,
              'right'
          );
    $(this.messageCenterBody).style.display
        = 'none';
};
proto.installControls = function () {
    var self = this;
    $(this.messageCenterControlClose).onclick
        = function () { self.closeMessageCenter() };
}


