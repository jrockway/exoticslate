/*==============================================================================
This Wikiwyg mode supports a DesignMode wysiwyg editor with toolbar buttons

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

proto = new Subclass('Wikiwyg.Wysiwyg', 'Wikiwyg.Mode');

proto.classtype = 'wysiwyg';
proto.modeDescription = 'Wysiwyg';

proto.config = {
    useParentStyles: true,
    useStyleMedia: 'wikiwyg',
    iframeId: null,
    iframeObject: null,
    disabledToolbarButtons: [],
    editHeightMinimum: 150,
    editHeightAdjustment: 1.3,
    clearRegex: null
};

proto.initializeObject = function() {
    this.edit_iframe = this.get_edit_iframe();
    this.div = this.edit_iframe;
    this.div.style.width = '99%';
    var self = this;
    this.get_edit_window().onload = function() {
        self.is_ready = true;
        self.get_edit_document().body.className = 'wiki';
    }
}

proto.fromHtml = function(html) {
    var dom = document.createElement('div');
    dom.innerHTML = html;
    this.sanitize_dom(dom);
    this.set_inner_html(dom.innerHTML);
}

proto.toHtml = function(func) {
    func(this.get_inner_html());
}

// This is needed to work around the broken IMGs in Firefox design mode.
// Works harmlessly on IE, too.
// TODO - IMG URLs that don't match /^\//
proto.fix_up_relative_imgs = function() {
    var base = location.href.replace(/(.*?:\/\/.*?\/).*/, '$1');
    var imgs = this.get_edit_document().getElementsByTagName('img');
    for (var ii = 0; ii < imgs.length; ++ii)
        imgs[ii].src = imgs[ii].src.replace(/^\//, base);
}

proto.enableThis = function() {
    Wikiwyg.Mode.prototype.enableThis.call(this);
    this.edit_iframe.style.border = '1px black solid';
    this.edit_iframe.width = '99%';
    this.setHeightOf(this.edit_iframe);
    this.fix_up_relative_imgs();

    var self = this;
    var ready = function() {
        if (!self.is_ready)
            self.fromHtml( self.wikiwyg.div.innerHTML );
        self.get_edit_document().designMode = 'on';
        self.enable_keybindings();
        self.set_clear_handler();

        if (Wikiwyg.is_gecko) {
            setTimeout(function() {
                self.get_edit_document().execCommand("enableObjectResizing", false, false);
                self.get_edit_document().execCommand("enableInlineTableEditing", false, false);
            }, 100);
        }

        self.is_ready = true;
    };
    if (self.is_ready)
        ready();
    else
        self.get_edit_window().onload = ready;
}

proto.clear_inner_html = function() {
    var inner_html = this.get_inner_html();
    var clear = this.config.clearRegex;
    var res = inner_html.match(clear) ? 'true' : 'false';
    if (clear && inner_html.match(clear))
        this.set_inner_html('');
}

proto.set_clear_handler = function () {
    var self = this;
    this.get_edit_iframe().contentWindow.addEventListener(
        'click',
        function () { self.clear_inner_html() },
        false
    );
    this.get_edit_iframe().contentWindow.addEventListener(
        'keydown',
        function () { self.clear_inner_html() },
        false
    );
}


proto.get_keybinding_area = function() {
    return this.get_edit_document();
}

proto.get_edit_iframe = function() {
    var iframe;
    if (this.config.iframeId) {
        iframe = document.getElementById(this.config.iframeId);
        iframe.iframe_hack = true;
    }
    else if (this.config.iframeObject) {
        iframe = this.config.iframeObject;
        iframe.iframe_hack = true;
    }
    else {
        // XXX in IE need to wait a little while for iframe to load up
        iframe = document.createElement('iframe');
    }
    return iframe;
}

proto.get_edit_window = function() { // See IE, below
    return this.edit_iframe.contentWindow;
}

proto.get_edit_document = function() { // See IE, below
    return this.get_edit_window().document;
}

proto.get_inner_html = function() {
    return this.get_edit_document().body.innerHTML;
}

proto.set_inner_html = function(html) {
    if (this.get_edit_document().body)
        this.get_edit_document().body.innerHTML = html;
}

proto.apply_stylesheets = function() {
    var styles = document.styleSheets;
    var head   = this.get_edit_document().getElementsByTagName("head")[0];

    for (var i = 0; i < styles.length; i++) {
        var style = styles[i];

        if (style.href == location.href)
            this.apply_inline_stylesheet(style, head);
        else
            if (this.should_link_stylesheet(style))
                this.apply_linked_stylesheet(style, head);
    }
}

proto.apply_inline_stylesheet = function(style, head) {
    var style_string = "";
    for ( var i = 0 ; i < style.cssRules.length ; i++ ) {
        if ( style.cssRules[i].type == 3 ) {
            // IMPORT_RULE

            /* It's pretty strange that this doesnt work.
               That's why Ajax.get() is used to retrive the css text.

            this.apply_linked_stylesheet({
                href: style.cssRules[i].href,
                type: 'text/css'
            }, head);
            */

            style_string += Ajax.get(style.cssRules[i].href);
        } else {
            style_string += style.cssRules[i].cssText + "\n";
        }
    }
    if (style_string.length > 0) {
        style_string += "\nbody { padding: 5px; }\n";
        this.append_inline_style_element(style_string, head);
    }
}

proto.append_inline_style_element = function(style_string, head) {
    // Add a body padding so words are not touching borders.
    var style_elt = document.createElement("style");
    style_elt.setAttribute("type", "text/css");
    if ( style_elt.styleSheet ) { /* IE */
        style_elt.styleSheet.cssText = style_string;
    }
    else { /* w3c */
        var style_text = document.createTextNode(style_string);
        style_elt.appendChild(style_text);
        head.appendChild(style_elt);
    }
    // XXX This doesn't work in IE!!
    // head.appendChild(style_elt);
}

proto.should_link_stylesheet = function(style, head) {
        var media = style.media;
        var config = this.config;
        var media_text = media.mediaText ? media.mediaText : media;
        var use_parent =
             ((!media_text || media_text == 'screen') &&
             config.useParentStyles);
        var use_style = (media_text && (media_text == config.useStyleMedia));
        if (!use_parent && !use_style) // TODO: simplify
            return false;
        else
            return true;
}

proto.apply_linked_stylesheet = function(style, head) {
    var link = Wikiwyg.createElementWithAttrs(
        'link', {
            href:  style.href,
            type:  style.type,
            media: 'screen',
            rel:   'STYLESHEET'
        }, this.get_edit_document()
    );
    head.appendChild(link);
}

proto.process_command = function(command) {
    if (this['do_' + command])
        this['do_' + command](command);
    this.get_edit_window().focus();
}

proto.exec_command = function(command, option) {
    this.get_edit_document().execCommand(command, false, option);
}

proto.format_command = function(command) {
    this.exec_command('formatblock', '<' + command + '>');
}

proto.do_bold = proto.exec_command;
proto.do_italic = proto.exec_command;
proto.do_underline = proto.exec_command;
proto.do_strike = function() {
    this.exec_command('strikethrough');
}
proto.do_hr = function() {
    this.exec_command('inserthorizontalrule');
}
proto.do_ordered = function() {
    this.exec_command('insertorderedlist');
}
proto.do_unordered = function() {
    this.exec_command('insertunorderedlist');
}
proto.do_indent = proto.exec_command;
proto.do_outdent = proto.exec_command;

proto.do_h1 = proto.format_command;
proto.do_h2 = proto.format_command;
proto.do_h3 = proto.format_command;
proto.do_h4 = proto.format_command;
proto.do_h5 = proto.format_command;
proto.do_h6 = proto.format_command;
proto.do_pre = proto.format_command;
proto.do_p = proto.format_command;

proto.do_table = function() {
    var html =
        '<table><tbody>' +
        '<tr><td>A</td>' +
            '<td>B</td>' +
            '<td>C</td></tr>' +
        '<tr><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>' +
        '<tr><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>' +
        '</tbody></table>';
    this.insert_html(html);
}

proto.insert_html = function(html) { // See IE
    this.get_edit_window().focus();
    this.exec_command('inserthtml', html);
}

proto.do_unlink = proto.exec_command;

proto.do_link = function() {
    var selection = this.get_link_selection_text();
    if (! selection) return;
    var url;
    var match = selection.match(/(.*?)\b((?:http|https|ftp|irc|file):\/\/\S+)(.*)/);
    if (match) {
        if (match[1] || match[3]) return null;
        url = match[2];
    }
    else {
        url = '?' + escape(selection);
    }
    this.exec_command('createlink', url);
}

proto.do_www = function() {
    var selection = this.get_link_selection_text();
	if (selection != null) {
		var  url =  prompt("Please enter a link", "Type in your link here");
		this.exec_command('createlink', url);
	}
}

proto.get_selection_text = function() { // See IE, below
    return this.get_edit_window().getSelection().toString();
}

proto.get_link_selection_text = function() {
    var selection = this.get_selection_text();
    if (! selection) {
        alert("Please select the text you would like to turn into a link.");
        return;
    }
    return selection;
}

/*==============================================================================
Support for Internet Explorer in Wikiwyg.Wysiwyg
 =============================================================================*/
if (Wikiwyg.is_ie) {

proto.toHtml = function(func) {
    var html = this.get_inner_html();
    var br = "<br class=\"p\"/>";

    html = this.remove_padding_material(html);
    html = html
        .replace(/\n*<p>\n?/ig, "")
        .replace(/<\/p>/ig, br)

    func(html);
}

proto.remove_padding_material = function(html) {
    var dom = document.createElement("div");
    if (Wikiwyg.is_ie)
        html = html.replace(/<P>\s*<HR>\s*<\/P>\s*/g, '<HR>\n\n');
    dom.innerHTML = html;

    // <BR>&nbsp; at t last. This is likely
    // something left by deleting from a padding <p>.
    var pTags = dom.getElementsByTagName("p");

    for(var i = 0; i < pTags.length; i++) {
      var p = pTags[i]
      if (p.nodeType == 1) {
          if (p.outerHTML.match(/<P class=padding>&nbsp;<\/P>/)) {
              p.outerHTML = "<BR>"
          } else if (p.innerHTML.match(/&nbsp;$/)) {
              var h = p.innerHTML
              p.innerHTML = h.replace(/&nbsp;$/,"");
          }
      }
    }

    return dom.innerHTML;
}

proto.process_command = function(command) {
    if (this['do_' + command])
        this['do_' + command](command);
}


proto.get_edit_window = function() {
    return this.edit_iframe;
}

proto.get_edit_document = function() {
    return this.edit_iframe.contentWindow.document;
}

proto.onbeforedeactivate = function() {
    this.__range = this.get_edit_document().selection.createRange();
}

proto.onactivate = function() {
    this.__range = undefined;
}

proto.get_selection_text = function() {
    var selection = this.get_edit_document().selection;

    if (selection != null) {
        this.__range = selection.createRange();
        return this.__range.htmlText;
    }
    return '';
}

proto.insert_html = function(html) {
    var doc = this.get_edit_document();
    var range = this.__range;
    if (!range) {
        range = this.get_edit_document().selection.createRange();
    }

    if (range.boundingTop == 2 && range.boundingLeft == 2)
        return;

    range.pasteHTML(html);
    range.collapse(false);
    range.select();
    if (this.__range) {
        this.__range = null;
    }
}

proto.get_inner_html = function( cb ) {
    if ( cb ) {
        this.get_inner_html_async( cb );
        return;
    }
    return this.get_editable_div().innerHTML;
}

proto.get_editable_div = function () {
    if (!this._editable_div) {
        this._editable_div = this.get_edit_document().createElement('div');
        this._editable_div.contentEditable = true;
        this._editable_div.style.overflow = 'auto';
        this._editable_div.style.border = 'none'
        this._editable_div.style.position = 'absolute';
        this._editable_div.style.width = '100%';
        this._editable_div.style.height = '100%';
        this._editable_div.id = 'wysiwyg-editable-div';
        this._editable_div.onbeforedeactivate = this.onbeforedeactivate.bind(this);
        this._editable_div.onactivate = this.onactivate.bind(this);
        this.get_edit_document().body.appendChild(this._editable_div);
        var self = this;
        setTimeout(function () { self._editable_div.focus() }, 500);
    }
    return this._editable_div;
}

proto.get_inner_html_async = function( cb ) {
    var self = this;
    var doc = this.get_edit_document();
    if ( doc.readyState == 'loading' ) {
        setTimeout( function() {
            self.get_inner_html(cb);
        }, 50);
    } else {
        var html = this.get_editable_div().innerHTML;
        cb(html);
        return html;
    }
}

proto.set_inner_html = function(html) {
    var self = this;
    var doc = this.get_edit_document();
    if ( doc.readyState == 'loading' ) {
        setTimeout( function() {
            self.set_inner_html(html);
        }, 50);
    } else {
        this.get_editable_div().innerHTML = html;
    }
}

// Use IE's design mode default key bindings for now.
proto.enable_keybindings = function() {}

} // end of global if
