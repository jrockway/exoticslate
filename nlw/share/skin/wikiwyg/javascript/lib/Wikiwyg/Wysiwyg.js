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
    }
}

proto.toHtml = function(func) {
    func(this.get_inner_html());
}

proto.clear_inner_html = function() {
    var inner_html = this.get_inner_html();
    var clear = this.config.clearRegex;
    var res = inner_html.match(clear) ? 'true' : 'false';
    if (clear && inner_html.match(clear))
        this.set_inner_html('\n');
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

proto.insert_html = function(html) { // See IE
    this.get_edit_window().focus();
    this.exec_command('inserthtml', html);
}

proto.do_unlink = proto.exec_command;

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

// Here goes the original javascript/Wikiwyg/Socialtext.js.
/*==============================================================================
Wikiwyg - Turn any HTML div into a wikitext /and/ wysiwyg edit area.

DESCRIPTION:

Wikiwyg is a Javascript library that can be easily integrated into any
wiki or blog software. It offers the user multiple ways to edit/view a
piece of content: Wysiwyg, Wikitext, Raw-HTML and Preview.

The library is easy to use, completely object oriented, configurable and
extendable.

See the Wikiwyg documentation for details.

AUTHORS:

    Ingy döt Net <ingy@cpan.org>
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
Socialtext Wysiwyg subclass.
 =============================================================================*/

proto.process_command = function(command) {
    command = command
        .replace(/-/g, '_');
    if (this['do_' + command])
        this['do_' + command](command);

    if ( command == 'link' ) {
        var self = this;
        setTimeout(function() {
            self.wikiwyg.toolbarObject
                .focus_link_menu('do_widget_link2', 'Wiki');
        }, 100);
    }

    if (Wikiwyg.is_gecko) this.get_edit_window().focus();
}

proto.fix_up_relative_imgs = function() {
    var base = location.href.replace(/(.*?:\/\/.*?\/).*/, '$1');
    var imgs = this.get_edit_document().getElementsByTagName('img');
    for (var ii = 0; ii < imgs.length; ++ii) {
        if (imgs[ii].src != imgs[ii].src.replace(/^\//, base)) {
            if ( jQuery.browser.msie && !imgs[ii].complete) {
                jQuery(imgs[ii]).load(function(){
                    this.src = this.src.replace(/^\//, base);
                });
            }
            else {
                imgs[ii].src = imgs[ii].src.replace(/^\//, base);
            }
        }
    }
}

proto.set_focus = function() {
    try {
        if (Wikiwyg.is_gecko) this.get_edit_window().focus();
        if (Wikiwyg.is_ie && !this._hasFocus) {
            this.get_editable_div().focus();
        }
    } catch (e) {}
}

proto.set_paste_handler = function() {
    var self = this;

    self.pastebin = jQuery("#pastebin").get(0).contentWindow;
    self.pastebin.document.body.innerHTML = "";
    self.pastebin.document.designMode = "on";

    var event_name = "keydown";
    if (jQuery.browser.mozilla && navigator.oscpu.match(/Mac/)) {
        event_name = "keypress";
    }

    jQuery( self.get_edit_document() ).unbind(event_name).bind(event_name, function(e) {
        if ((e.ctrlKey || e.metaKey) && (e.which == 86 || e.which == 118)) {
            self.pastebin.focus();

            setTimeout(function() {
                var html = self.pastebin.document.body.innerHTML;
                self.pastebin.document.body.innerHTML = "";

                self.on_pasted(html);
            }, 100);
        }
    });
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

    setTimeout(function() {
        try {
            if (Wikiwyg.is_gecko) self.get_edit_window().focus();
            if (Wikiwyg.is_ie) { 
                /* IE needs this to prevent stack overflow when switching modes,
                 * as described in {bz: 1511}.
                 */
                self._ieSelectionBookmark = null;

                jQuery(self.get_editable_div()).focus();

                if (jQuery.browser.version <= 6) {
                    /* We take advantage of IE6's overflow:visible bug
                     * to make the DIV always agree with the dimensions
                     * of the inner content.  More details here:
                     *     http://www.quirksmode.org/css/overflow.html
                     * Note that this must not be applied to IE7+, because
                     * overflow:visible is implemented correctly there, and
                     * setting it could trigger a White Screen of Death
                     * as described in {bz: 1366}.
                     */
                    jQuery(self.get_editable_div()).css(
                        'overflow', 'visible'
                    );
                }
                self.set_clear_handler();
            }

            self.set_paste_handler();
        }
        catch(e) { }
    }, 1);

    if (!this.__toolbar_styling_interval) {
        this.__toolbar_styling_interval = setInterval(
            function() {
                try {
                    self.toolbarStyling()
                }
                catch(e) { }
            }, 1000
        );
    }
}

proto.on_pasted = function(html) {
    var self = this;

    // XXX: for testing purpose.
    // html = html.toUpperCase();

    if (this.paste_buffer_is_simple(html)) {
        self.insert_html( html );
        return;
    }

    // The "false" here for isWholeDocument means we're dealing with HTML fragments.
    var wikitext = self.wikiwyg.mode_objects[WW_ADVANCED_MODE].convert_html_to_wikitext(html, false);

// XXX - Lightboxing causes insert to be in wrong place
//     jQuery.showLightbox({ html: "pasting...", overlayBackground: "transparent", speed: 1 });

    jQuery.ajax({
        type: 'post',
        url: 'index.cgi',
        data: {
            action: 'wikiwyg_wikitext_to_html',
            content: wikitext
        },
        success: function(html) {
            html = html
                .replace(/^<div class="wiki">\n*/i, '')
                .replace(/\n*<br\/><\/div>\n*$/i, '')
                .replace(/^<p>([\s\S]*?)<\/p>/, '$1');

            self.insert_html( html );

//             jQuery.hideLightbox();
        },
        error: function(xhr) {
//             jQuery.hideLightbox();
        }
    });

}

proto.paste_buffer_is_simple = function(buffer) {
    return (
        (buffer.indexOf("<") < 0 && buffer.indexOf(">") < 0) ||
        (!buffer.match(/<(font|script|applet|object|div|p|br)/i))
    );
}

proto.toolbarStyling = function() {
    if (this.busy_styling)
        return;
    this.busy_styling = true;
    try {
        var selection = this.get_edit_document().selection
            ? this.get_edit_document().selection
            : this.get_edit_window().getSelection();
        var anchor = selection.anchorNode
            ? selection.anchorNode
            : selection.createRange().parentElement();

        if( jQuery(anchor, this.get_edit_window()).parents("table").size() > 0 ) {
            jQuery(".table_buttons").removeClass("disabled");
        }
        else {
            jQuery(".table_buttons").addClass("disabled");
        }

        if (Wikiwyg.is_gecko) {
            this.get_edit_document().execCommand("enableInlineTableEditing", false, false);
        }
    } catch(e) {}
    this.busy_styling = false;
}

proto.set_clear_handler = function () {
    var self = this;
    var editor = Wikiwyg.is_ie ? self.get_editable_div() : self.get_edit_window();

    var clean = function() {
        self.clear_inner_html();
        jQuery(editor).unbind();

        /* We've just unbound the paste handler, so re-enable it here */
        self.set_paste_handler();
    };

    try {
        jQuery(editor).one("click", clean).one("keydown", clean);
    } catch (e) {};
}

proto.fromHtml = function(html) {
    this.show_messages(html);
    var dom = document.createElement('div');
    dom.innerHTML = html;
    this.sanitize_dom(dom);
    this.set_inner_html(dom.innerHTML);
}

proto.show_messages = function(html) {
    var advanced_link = this.advanced_link_html();
    var message_titles = {
        wiki:  loc('Advanced Content in Grey Border'),
        table: loc('Table Edit Tip'),
        both:  loc('Table & Advanced Editing')
    };
    var message_bodies = {
        wiki:
            loc('Advanced content is shown inside a grey border. Switch to [_1] to edit areas inside a grey border.',advanced_link),
        table: loc('Use [_1] to change the number of rows and columns in a table.', advanced_link),
        both: ''
    };
    message_bodies.both = message_bodies.table + ' ' + message_bodies.wiki;

    var wiki    = html.match(/<!--\s*wiki:/);
    var table   = html.match(/<table /i);
    var message = null;
    if      (wiki && table) message = 'both'
    else if (table)         message = 'table'
    else if (wiki)          message = 'wiki';

    if (message) {
        this.wikiwyg.message.display({
            title: message_titles[message],
            body: message_bodies[message],
            timeout: 60
        });
    }
}

proto.do_p = function() {
    this.format_command("p");
}

proto.do_attach = function() {
    this.wikiwyg.message.display(this.use_advanced_mode_message(loc('Attachments')));
}

proto.do_image = function() {
    this.do_widget_image();
}

proto.do_link = function(widget_element) {
    this._do_link(widget_element);
}

proto.add_wiki_link = function(widget_element, dummy_widget) {
    var label     = jQuery("#wiki-link-text").val(); 
    var workspace = jQuery("#st-widget-workspace_id").val() || "";
    var page_name = jQuery("#st-widget-page_title").val();
    var section   = jQuery("#wiki-link-section").val();
    var workspace_id = dummy_widget.title_and_id.workspace_id.id || workspace.replace(/\s+/g, '');

    if (!page_name) {
        this.set_add_a_link_error( "Please fill in the Page field for wiki links." );
        return false;
    } 

    if (workspace && workspace_id && !this.lookupTitle("workspace_id", workspace_id)) {
        this.set_add_a_link_error( "That workspace does not exist." );
        return false;
    }

    if (!section && (!workspace || workspace == Socialtext.wiki_id)) {  // blue links
        this.make_wiki_link(page_name, label);
    } else { // widgets
        var wafl = this.create_link_wafl(label, workspace_id, page_name , section);
        this.insert_link_wafl_widget(wafl, widget_element);
    }

    return true;
}

proto.add_section_link = function(widget_element) {
    var section = jQuery('#section-link-text').val();

    if (!section) {
        this.set_add_a_link_error( "Please fill in the section field for section links." );
        return false;
    } 

    var wafl = this.create_link_wafl(false, false, false, section);
    this.insert_link_wafl_widget(wafl, widget_element);

    return true;
}

proto.add_web_link = function() {
    var url       = jQuery('#web-link-destination').val();
    var url_text  = jQuery('#web-link-text').val();

    if (!url || !url.match(/^(http|https|ftp|irc|mailto|file):/)) {
        this.set_add_a_link_error("Please fill in the Link destination field for web links.");
        return false;
    }

    this.make_web_link(url, url_text);
    return true;
}

proto.insert_link_wafl_widget = function(wafl, widget_element) {
    var widget_text = this.getWidgetImageText(wafl);
    var self = this;
    jQuery.ajax({
        type: 'post',
        url: location.pathname,
        data: {
            action: "wikiwyg_generate_widget_image",
            widget: widget_text,
            widget_string: wafl
        },
        success: function() {
            self.insert_widget(wafl, widget_element);
        }
    });
}

proto.make_wiki_link = function(page_name, link_text) {
    this.make_link(link_text, page_name, false);
}

proto.make_web_link = function(url, link_text) {
    this.make_link(link_text, false, url);
}

proto.make_link = function(label, page_name, url) {
    var link_node = document.createElement("a");

    // Anchor text
    var text = label || page_name || url;
    link_node.appendChild( document.createTextNode(text) );

    // Anchor HREF
    link_node.href = url || "?" + encodeURIComponent(page_name);

    // Anchor hint for "label"[page] style links
    if (label && page_name && label != page_name) {
        var comment = document.createComment("wiki-renamed-link " + page_name);
        link_node.appendChild(comment);
    }

    if (label && url) {
        var comment = document.createComment(
            'wiki-renamed-hyperlink "' + label + '"<' + url + '>'
        );
        link_node.appendChild(comment);
    }

    this.insert_element_at_cursor(link_node);
}

if (Wikiwyg.is_ie) {
    proto.make_link = function(label, page_name, url) {

        var text = html_escape( label || page_name || url );
        var href = url || "?" + encodeURIComponent(page_name);
        var attr = "";
        if (page_name) {
            attr = " wiki_page=\"" + page_name + "\"";
        }
        var html = "<a href=\"" + href + "\"" + attr + ">" + text;

        if (label && url) {
            html += '<!--' +
                    'wiki-renamed-hyperlink "' + label + '"<' + url + '>' +
                    '-->';
        }

        html += "</a>";

        this.set_focus(); // Need this before .insert_html
        this.insert_html(html);
    }
}

proto.insert_element_at_cursor = function(ele) {
    var selection = this.get_edit_window().getSelection();
    if (selection.toString().length > 0) {
        selection.deleteFromDocument();
    }

    selection  = this.get_edit_window().getSelection();
    var anchor = selection.anchorNode;
    var offset = selection.anchorOffset;

    if (anchor.nodeName == '#text') {  // Insert into a text element.
        var secondNode = anchor.splitText(offset);
        anchor.parentNode.insertBefore(ele, secondNode);
    } else {  // Insert at the start of the line.
        var children = selection.anchorNode.childNodes;
        if (children.length > offset) {
            selection.anchorNode.insertBefore(ele, children[offset]);
        } else {
            anchor.appendChild(ele);
        }
    }
}

proto.use_advanced_mode_message = function(subject) {
    return {
        title: loc('Use Advanced Mode for [_1]', subject),
        body: loc('Switch to [_1] to use this feature.',  this.advanced_link_html()) 
    }
}

proto.advanced_link_html = function() {
    return '<a onclick="wikiwyg.wikitext_link.onclick(); return false" href="#">' + loc('Advanced Mode') + '</a>';
}

proto.make_table_html = function(rows, columns) {
    var innards = '';
    var cell = '<td style="border: 1px solid black;padding: .2em;"><span style="padding:.5em">&nbsp;</span></td>';
    for (var i = 0; i < rows; i++) {
        var row = '';
        for (var j = 0; j < columns; j++)
            row += cell;
        innards += '<tr>' + row + '</tr>';
    }
    return '<table style="border-collapse: collapse;" class="formatter_table">' + innards + '</table>';
}

proto.closeTableDialog = function() {
    var doc = this.get_edit_document();
    jQuery(doc).unbind("keypress");
    jQuery.hideLightbox();
    this.set_paste_handler();
}

proto.do_new_table = function() {
    var self = this;
    var do_table = function() {
        var $error = jQuery('.table-create .error');

        var rows = jQuery('.table-create input[name=rows]').val();
        var cols = jQuery('.table-create input[name=columns]').val();
        if (! rows.match(/^\d+$/))
            return $error.text(loc('Rows is invalid.'));
        if (! cols.match(/^\d+$/))
            return $error.text(loc('Columns is invalid.'));
        rows = Number(rows);
        cols = Number(cols);
        if (! (rows && cols))
            return $error.text(loc('Rows and Columns must be non-zero.'));
        if (rows > 100)
            return $error.text(loc('Rows is too big. 100 maximum.'));
        if (cols > 35)
            return $error.text(loc('Columns is too big. 35 maximum.'));
        self.set_focus(); // Need this before .insert_html
        self.insert_html(self.make_table_html(rows, cols));
        self.closeTableDialog();
    }
    var setup = function() {
        jQuery('.table-create input[name=columns]').focus();
        jQuery('.table-create input[name=columns]').select();
        jQuery('.table-create input[name=save]')
            .unbind("click")
            .bind("click", function() {
                do_table();
            });
        jQuery('.table-create input[name=cancel]')
            .unbind("click")
            .bind("click", function() {
                self.closeTableDialog();
            });
        jQuery("#lightbox").one("unload", function() {
            self.set_focus();
        });
    }
    jQuery.showLightbox({
        html: Jemplate.process("table-create.html", {"loc": loc}),
        width: 300,
        callback: setup
    });
    return false;
}

proto.deselect = function() {
    if (Wikiwyg.is_ie) {
        var r = this.get_edit_document().selection.createRange();
        r.collapse(true);
        r.select();

        this.__range = undefined;
    }
    else {
        this.get_edit_window().getSelection().collapseToStart();
    }
}

proto.find_table_cell_with_cursor = function() {
    var doc = this.get_edit_document();

    jQuery("span.find-cursor", doc).removeClass('find-cursor');

    // Note that we explicitly don't call set_focus() here, otherwise
    // IE will move the cursor to the next cell -- See {bz: 1692}.
    this.deselect();
    this.insert_html("<span class=\"find-cursor\"></span>");

    var cursor = jQuery("span.find-cursor", doc);
    if (! cursor.parents('td').length)
        return;
    var $cell = cursor.parents("td");

    cursor.remove();
    $cell.html($cell.html()
        .replace(/<span style="padding: [^;]*;">(.*?)<\/span>/g, '$1')
    );

    return $cell;
}

proto._do_table_manip = function(callback) {
    var self = this;
    setTimeout(function() {
        var $cell = self.find_table_cell_with_cursor();
        if (! $cell) return;

        var $new_cell = callback.call(self, $cell);

        if ($new_cell) {
            self.set_focus();
            if ($.browser.mozilla) {
                if (parseFloat($.browser.version) >= 1.9) {
                    // FF3+ has a natural .collapse(parentNode) method.
                    self.get_edit_window().getSelection().collapse(
                        $new_cell.find("span").get(0), 0
                    );
                }
                else {
                    // FF2 needs a complex dance here: {bz: 1815}
                    var $span = $new_cell.find("span");
                    if ($span.length > 0) {
                        if ($span.html() == '') {
                            $span.html('&nbsp;');
                        }
                    }
                    else {
                        $span = $new_cell;
                    }

                    var r = self.get_edit_document().createRange();
                    r.setStart( $span.get(0), 0 );
                    r.setEnd( $span.get(0), 0 );

                    var s = self.get_edit_window().getSelection();
                    s.removeAllRanges();
                    s.addRange(r);
                }
            }
            else if (jQuery.browser.msie) {
                var r = self.get_edit_document().selection.createRange();
                r.moveToElementText( $new_cell.get(0) );
                r.collapse(true);
                r.select();
            }
        }
    }, 100);
}

proto.do_add_row_below = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        var doc = this.get_edit_document();
        var $tr = jQuery(doc.createElement('tr'));
        $cell.parents("tr").find("td").each(function() {
            $tr.append('<td><span style=\"padding:0.5em\"></span></td>');
        });
        $tr.insertAfter( $cell.parents("tr") );
    });
}

proto.do_add_row_above = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        var doc = this.get_edit_document();
        var $tr = jQuery(doc.createElement('tr'));

        $cell.parents("tr").find("td").each(function() {
            $tr.append('<td><span style=\"padding:0.5em\"></span></td>');
        });
        $tr.insertBefore( $cell.parents("tr") );
    });
}

proto.do_add_col_left = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        var doc = this.get_edit_document();
        self._traverse_column($cell, function($td) {
            $td.before(
                $(doc.createElement('td'))
                    .html('<span style=\"padding:0.5em\"></span>')
            );
        });
    });
}

proto.do_add_col_right = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        var doc = this.get_edit_document();
        self._traverse_column($cell, function($td) {
            $td.after(
                $(doc.createElement('td'))
                    .html('<span style=\"padding:0.5em\"></span>')
            );
        });
    });
}

proto.do_del_row = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        var col = self._find_column_index($cell);
        var $new_cell = $cell.parents('tr')
            .next().find("td:nth-child(" + col + ")");
        if (!$new_cell.length) {
            $new_cell = $cell.parents('tr')
                .prev().find("td:nth-child(" + col + ")");
        }
        if ($new_cell.length) {
            $cell.parents('tr').remove();
            return $new_cell;
        }
        else {
            $cell.parents("table").remove();
            return;
        }
    });
}

proto._traverse_column_with_prev = function($cell, callback) {
    this._traverse_column($cell, callback, -1);
}

proto._traverse_column_with_next = function($cell, callback) {
    this._traverse_column($cell, callback, +1);
}

proto._traverse_column = function($cell, callback, offset) {
    var $table = $cell.parents("table");
    var col = this._find_column_index($cell);
    var trs = $table.find('tr');
    for (var i = 0; i < trs.length; i++) {
        var tds = $(trs[i]).find('td');
        if (tds.length >= col) {
            var $td = $(tds.get(col-1));
            if (offset) {
                if (tds.length >= col+offset && col+offset >= 1) {
                    var $td2 = $(tds.get(col+offset-1));
                    callback($td, $td2);
                }
            }
            else {
                callback($td);
            }
        }
    }
}

proto.do_del_col = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        if ($cell.parents('tr:first').find('td').length <= 1) {
            $cell.parents("table").remove();
            return;
        }

        var $tr = $cell.parents('tr:first');
        var col = self._find_column_index($cell);
        self._traverse_column($cell, function($td) {
            $td.remove();
        });

        var tds = $tr.find('td');
        if (tds.length >= col) {
            return $(tds[col-1]);
        }
        else {
            return $(tds[col-2]);
        }
    });
}

proto.do_move_row_up = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        var $r = $cell.parents("tr");
        $r.prev().insertAfter( $r );
    });
}

proto.do_move_row_down = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        var $r = $cell.parents("tr");
        $r.next().insertBefore( $r );
    });
}

proto.do_move_col_left = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        self._traverse_column_with_prev($cell, function($td, $prev) {
            $prev.insertAfter($td);
        });
    });
}

proto.do_move_col_right = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        self._traverse_column_with_next($cell, function($td, $next) {
            $next.insertBefore($td);
        });
    });
}

proto.do_table = function() {
    var doc = this.get_edit_document();
    jQuery("span.find-cursor", doc).removeClass('find-cursor');
    this.set_focus(); // Need this before .insert_html
    this.insert_html( "<span class=\"find-cursor\"></span>" );

    var self = this;
    setTimeout(function() {
        var $cell = self.find_table_cell_with_cursor();
        if (! $cell)
            return self.do_new_table();
        return;
    }, 100);
}

proto._scroll_to_center = function($cell) {
    var $editor;
    var eHeight, eWidth;

    if (Wikiwyg.is_ie) {
        $editor = jQuery( this.get_editable_div() );
        if (jQuery.browser.version <= 6) {
            if ($editor.css('overflow') != 'auto') {
                $editor.css('overflow', 'auto');
            }
        }

        eHeight = $editor.height();
        eWidth = $editor.width();
    }
    else {
        var doc = this.get_edit_document();
        eHeight = doc.body.clientHeight;
        eWidth = doc.body.clientWidth;
    }

    var cHeight = $cell.height();
    var cWidth = $cell.width();

    var cTop, cLeft;
    if (Wikiwyg.is_ie) {
        cTop = $cell.offset().top + $editor.scrollTop();
        cLeft = $cell.offset().left + $editor.scrollLeft();
    }
    else {
        cTop = $cell.position().top;
        cLeft = $cell.position().left;
    }

    var sLeft = cLeft + (cWidth - eWidth) / 2;
    var sTop = cTop + (cHeight - eHeight) / 2;

    if (sLeft < 0) sLeft = 0;
    if (sTop < 0) sTop = 0;

    if (Wikiwyg.is_ie) {
        $editor.scrollLeft(sLeft).scrollTop(sTop);
    }
    else {
        var win = this.get_edit_window();
        win.scrollTo(sLeft, sTop);
    }
}

proto._find_column_index = function($cell) {
    $cell.addClass('find-cell');
    var tds = $cell.parents('tr:first').find('td');
    for (var i = 0; i < tds.length; i++) {
        if ($(tds[i]).hasClass('find-cell')) {
            $cell.removeClass('find-cell');
            return i+1;
        }
    }
    $cell.removeClass('find-cell');
    return 0;
}

proto.setHeightOf = function (iframe) {
    iframe.style.height = this.get_edit_height() + 'px';
};

proto.socialtext_wikiwyg_image = function(image_name) {
    return this.wikiwyg.config.toolbar.imagesLocation + image_name;
}


proto.get_link_selection_text = function() {
    var selection = this.get_selection_text();
    if (! selection) {
        alert(loc("Please select the text you would like to turn into a link."));
        return;
    }
    return selection;
}

/* This function is the same as the baseclass one, except it doesn't use
 * Function.prototype.bind(), and hence is free of the dependency on
 * Prototype.js, as required by S3.
 */
proto.get_editable_div = function () {
    if (!this._editable_div) {
        var doc = this.get_edit_document();
        this._editable_div = doc.createElement('div');
        this._editable_div.contentEditable = true;
        this._editable_div.style.overflow = 'auto';
        this._editable_div.style.border = 'none'
        this._editable_div.style.width = '100%';
        this._editable_div.style.height = '100%';
        this._editable_div.id = 'wysiwyg-editable-div';
        this._editable_div.className = 'wiki';

        var self = this;
        this._editable_div.onbeforedeactivate = function () {
            self.__range = doc.selection.createRange();
        };
        this._editable_div.onactivate = function () {
            /* We don't undefine self.__range here as exec_command()
             * will make use of the previous range after onactivate.
             */
            return;
        };

        if ( jQuery.browser.msie ) {
            var win = self.get_edit_window();
            self._ieSelectionBookmark = null;
            self._hasFocus = false;

            doc.attachEvent("onbeforedeactivate", function() {
                self._ieSelectionBookmark = null;
                try {
                    var range = doc.selection.createRange();
                    self._ieSelectionBookmark = range.getBookmark();
                } catch (e) {};
            });

            self.get_edit_window().attachEvent("onfocus", function() {
                self._hasFocus = true;
            });

            self.get_edit_window().attachEvent("onblur", function() {
                self._hasFocus = false;
            });

            doc.attachEvent("onactivate", function() {
                 if (! self._ieSelectionBookmark) {
                     return;
                 }

                 try {
                     var range = doc.body.createTextRange();
                     range.moveToBookmark(self._ieSelectionBookmark);
                     range.collapse();
                     range.select();
                 } catch (e) {};
            });
        } 

        var tryFocusDiv = function(tries) {
            setTimeout(function() {
                try {
                    self._editable_div.focus();
                } catch(e) {
                    /* If we get here, the doc is partially initializing so we
                     * may get a "Permission denied" error, so try again.
                     */
                    if (tries > 0) {
                        tryFocusDiv(tries - 1);
                    }
                }
            }, 500);
        };

        var tryAppendDiv = function(tries) {
            setTimeout(function() {
                try {
                    if (doc.body) {
                        jQuery("iframe#st-page-editing-wysiwyg").width( jQuery('#st-edit-mode-view').width() - 48 );
                        doc.body.appendChild(self._editable_div);
                        tryFocusDiv(100);
                    }
                    else if (tries > 0) {
                        tryAppendDiv(tries - 1);
                    }
                } catch(e) {
                    /* If we get here, the doc is partially initializing so we
                     * may get a "Permission denied" error, so try again.
                     */
                    if (tries > 0) {
                        tryAppendDiv(tries - 1);
                    }
                }
            }, 500);
        };

        // Retry for up to 100 times = 50 seconds
        tryAppendDiv(100);
    }
    return this._editable_div;
}

proto.exec_command = function(command, option) {
    if ( Wikiwyg.is_ie && command.match(/^insert/) && !command.match(/^insert.*list$/)) {
        /* IE6+7 has a bug that prevents insertion at the beginning of
         * the edit document if it begins with a non-text element.
         * So we test if the selection starts at the beginning, and
         * prepends a temporary space so the insert can work. -- {bz: 1451}
         */

        this.set_focus(); // Need this before .insert_html

        var range = this.__range
                 || this.get_edit_document().selection.createRange();

        if (range.boundingLeft == 1 && range.boundingTop <= 20) {
            var doc = this.get_edit_document();
            var div = doc.getElementsByTagName('div')[0];

            var randomString = Math.random();
            var stub = doc.createTextNode(' ');

            div.insertBefore(stub, div.firstChild);

            var stubRange = doc.body.createTextRange();
            stubRange.findText(' ');
            stubRange.select();
        }
        else {
            range.collapse();
            range.select();
        }
    }

    if ((command == 'inserthtml') && ((typeof(option) != 'string') || option.length == 0)) {
        return true;
    }
    return(this.get_edit_document().execCommand(command, false, option));
};

/*==============================================================================
Socialtext Debugging code
 =============================================================================*/
klass = Wikiwyg;

klass.run_formatting_tests = function(link) {
    var all = document.getDivsByClassName('wikiwyg_formatting_test');
    foreach(all, function (each) {
        klass.run_formatting_test(each);
    })
}

klass.run_formatting_test = function(div) {
    var pre_elements = div.getElementsByTagName('pre');
    var html_text = pre_elements[0].innerHTML;
    var wiki_text = pre_elements[1].innerHTML;
    html_text = Wikiwyg.htmlUnescape(html_text);
    var wikitext = new Wikiwyg.Wikitext();
    var result = wikitext.convert_html_to_wikitext(html_text);
    result = klass.ensure_newline_at_end_of_string(result);
    wiki_text = klass.ensure_newline_at_end_of_string(wiki_text);
    if (! div.wikiwyg_formatting_test_results_shown)
        div.wikiwyg_formatting_test_results_shown = 0;
    if (result == wiki_text) {
        div.style.backgroundColor = '#0f0';
    }
    else if (! div.wikiwyg_formatting_test_results_shown++) {
        div.style.backgroundColor = '#f00';
        div.innerHTML = div.innerHTML + '<br/>Bad: <pre>\n' +
            result + '</pre>';
        jQuery('#wikiwyg_test_results').append('<a href="#'+div.id+'">Failed '+div.id+'</a>; ');
    }
}

klass.ensure_newline_at_end_of_string = function(str) {
    return str + ('\n' == str.charAt(str.length-1) ? '' : '\n');
}

wikiwyg_run_all_formatting_tests = function() {
    var divs = document.getElementsByTagName('div');
    for (var i = 0; i < divs.length; i++) {
        var div = divs[i];
        if (div.className != 'wikiwyg_formatting_test') continue;
        klass.formatting_test(div);
    }
}

klass.run_all_formatting_tests = wikiwyg_run_all_formatting_tests;
