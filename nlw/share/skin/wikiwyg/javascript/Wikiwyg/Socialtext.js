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

if (! window.wikiwyg_nlw_debug)
    window.wikiwyg_nlw_debug = false;

var WW_SIMPLE_MODE = 'Wikiwyg.Wysiwyg.Socialtext';
var WW_ADVANCED_MODE = 'Wikiwyg.Wikitext.Socialtext';
var WW_PREVIEW_MODE = 'Wikiwyg.Preview.Socialtext';
var WW_HTML_MODE = 'Wikiwyg.HTML';

Wikiwyg.browserIsSupported = (
    Wikiwyg.is_gecko ||
    Wikiwyg.is_ie ||
    Wikiwyg.is_safari
);

Wikiwyg.is_old_firefox = (
    Wikiwyg.ua.indexOf('firefox/1.0.7') != -1 &&
    Wikiwyg.ua.indexOf('safari') == -1 &&
    Wikiwyg.ua.indexOf('konqueror') == -1
);

Wikiwyg.is_safari2 = (
    Wikiwyg.is_safari &&
    Wikiwyg.ua.indexOf("version/2") != -1
);

Wikiwyg.is_safari3 = (
    Wikiwyg.is_safari &&
    Wikiwyg.ua.indexOf("version/3") != -1
);

Wikiwyg.is_safari_unknown = (
    Wikiwyg.is_safari &&
    Wikiwyg.ua.indexOf("version/") == -1
);

function setup_wikiwyg() {
    if (! Wikiwyg.browserIsSupported) return;

    if ( jQuery("#st-edit-mode-container").size() != 1 ||
         jQuery("iframe#st-page-editing-wysiwyg").size() != 1 ) {
        Socialtext.wikiwyg_variables.loc = loc;
        var template = Socialtext.S3 ? 'edit_wikiwyg' : 'layout/edit_wikiwyg';
        var html = Jemplate.process(template, Socialtext.wikiwyg_variables);

        jQuery(html).insertBefore('#st-display-mode-container');

        if (!Socialtext.wikiwyg_variables.hub.current_workspace.enable_spreadsheet) {
            jQuery('a[do="do_widget_ss"]').parent("li").remove()
        }
    }

    // The div that holds the page HTML
    var myDiv = jQuery('#wikiwyg-page-content').get(0);
    if (! myDiv)
        return false;
    if (window.wikiwyg_nlw_debug)
        Wikiwyg.Socialtext.prototype.modeClasses.push(WW_HTML_MODE);

    // Get the "opening" mode from a cookie, or reasonable default
    var firstMode = Cookie.get('first_wikiwyg_mode')
    if (firstMode == null ||
        (firstMode != WW_SIMPLE_MODE && firstMode != WW_ADVANCED_MODE)
    ) firstMode = WW_SIMPLE_MODE;

    if ( Wikiwyg.is_safari ) firstMode = WW_ADVANCED_MODE;

    var clearRichText = new RegExp(
        ( "^"
        + "\\s*(</?(span|br|div)\\b[^>]*>)*\\s*"
        + loc("Replace this text with your own.")
        + "\\s*(</?(span|br|div)\\b[^>]*>)*\\s*"
        + "$"
        ), "i"
    );

    var clearWikiText = new RegExp(
        "^" + loc("Replace this text with your own.") + "\\s*$"
    );

    // Wikiwyg configuration
    var myConfig = {
        doubleClickToEdit: false,
        firstMode: firstMode,
        javascriptLocation: nlw_make_s2_path('/javascript/'),
        toolbar: {
            imagesLocation: nlw_make_s2_path('/images/wikiwyg_icons/')
        },
        wysiwyg: {
            clearRegex: clearRichText,
            iframeId: 'st-page-editing-wysiwyg',
            editHeightMinimum: 200,
            editHeightAdjustment: 1.3
        },
        wikitext: {
            clearRegex: clearWikiText,
            textareaId: 'st-page-editing-pagebody-decoy'
        },
        preview: {
            divId: 'st-page-preview'
        }
    };

    // The Wikiwyg object must be stored as a global (aka window property)
    // so that it stays in scope for the duration of the window. The Wikiwyg
    // code should not make reference to the global wikiwyg variable, though,
    // since that breaks encapsulation. (It's an easy trap to fall into.)
    var ww = new Wikiwyg.Socialtext();
    window.wikiwyg = ww;

    ww.createWikiwygArea(myDiv, myConfig);
    if (! ww.enabled) return;

    ww.message = new Wikiwyg.MessageCenter();

    // For example, because of a unregistered user on a self-register space:
    if (!jQuery('#st-editing-tools-edit').size() ||
        !jQuery('#st-edit-button-link').size())
        throw new Error('Unauthorized');

    ww.wikitext_link = jQuery('#st-mode-wikitext-button').get(0);

    Wikiwyg.setup_newpage();

    // XXX start_nlw_wikiwyg goes in the object because display_edit.js
    // wants it there.
    ww.starting_edit = false;
    ww.start_nlw_wikiwyg = function() {
        if (ww.starting_edit) {
            return;
        }

        ww.starting_edit = true;

        try {
            if (Wikiwyg.is_safari) {
                delete ww.current_wikitext;
            }
            if (Wikiwyg.is_safari || Wikiwyg.is_old_firefox) {
                jQuery("#st-page-editing-uploadbutton").hide();
            }
            
            if (!Socialtext.S3)
                jQuery("#st-all-footers").hide();

            jQuery("#st-display-mode-container").hide();

            // See the comment about "two seconds" below
            if (Socialtext.S3 && (firstMode == WW_SIMPLE_MODE)) {
                jQuery("#st-editing-tools-edit .buttonRight a").hide();
            }

            jQuery("#st-editing-tools-edit, #wikiwyg_toolbar").show();
            jQuery("#st-edit-mode-container").show();

            if (jQuery("#contentRight").is(":visible"))
                jQuery("#st-page-maincontent").css("margin-right", "240px");
 
            if (!Socialtext.new_page)
                Page.refreshPageContent();

            Attachments.reset_new_attachments();

// We used to use this line:
//          myDiv.innerHTML = $('st-page-content').innerHTML;
// But IE likes to take our non XHTML formatted lists and make them XHTML.
// That messes up the wikiwyg formatter. So now we do this line:
            myDiv.innerHTML =
                // This lines fixes
                // https://bugs.socialtext.net:555/show_bug.cgi?id=540
                "<span></span>" +
                (Page.html
                // And the variable above is undefined for new pages. This is
                // what we fallback to.
                || jQuery('#st-page-content').html());

            ww.editMode();
            ww.preview_link_reset();
            jQuery("#st-pagetools").hide();
            jQuery("#st-editing-tools-display").hide();

            nlw_edit_controls_visible = true;
            ww.enableLinkConfirmations();

            ww.is_editing = true;

            if (Wikiwyg.is_safari) {
                ww.message.display({
                    title: loc("Socialtext has limited editing capabilities in Safari."),
                    body: loc("<a target=\"_blank\" href=\"http://www.mozilla.com/firefox/\">Download Firefox</a> for richer Socialtext editing functionality.")
                });
            }

            if (Socialtext.S3 && (firstMode == WW_SIMPLE_MODE)) {
                // Give the browser two seconds to render the initial iframe.
                // If we don't do this, click on "Wiki text" prematurely will
                // hang the editor up.  Humans usually take more than 1000ms
                // to find the link anyway, but Selenium can trigger this bug
                // quite regularly given a high enough latency to the server.
                setTimeout( function() {
                    jQuery("#st-editing-tools-edit .buttonRight a").show();
                    ww.set_edit_tips_span_display('none');
                }, 2000 );
            }

            if (Socialtext.ui_expand_setup) {
                Socialtext.ui_expand_setup();
            }

            jQuery(window).trigger("resize");

            ww.starting_edit = false;
        } catch(e) {
            ww.starting_edit = false;
            throw(e);
        };

        return false;
    }

    jQuery(window).bind("resize", function () {
        ww.resizeEditor();
    });
 
    jQuery('#st-edit-button-link').click(ww.start_nlw_wikiwyg);
    jQuery("#st-edit-actions-below-fold-edit").click(ww.start_nlw_wikiwyg);

    if (Socialtext.double_click_to_edit) {
        jQuery("#st-page-content").bind("dblclick", ww.start_nlw_wikiwyg);
    }

    if (!Socialtext.new_page) {
        jQuery('#st-save-button-link').click(function() {
            ww.is_editing = false;
            ww.showScrollbars();
            ww.saveButtonHandler();
            return false;
        });
    }

    // node handles
    jQuery('#st-cancel-button-link').click(function() {
        try {
            if (ww.contentIsModified()) {
                // If it's not confirmed somewhere else, do it right here.
                if (ww.confirmed != true && !confirm(loc("Are you sure you want to Cancel?\n\nYou have unsaved changes.\n\nPress OK to continue, or Cancel to stay in the editor.")))
                    return false;
                else
                    ww.confirmed = true;
            }
            Attachments.delete_new_attachments();
            if (Socialtext.new_page) {
                window.location = '?action=homepage';
            }
            else if (location.href.match(/caller_action=weblog_display;?/)) {
                location.href = 'index.cgi?action=weblog_redirect;start=' +
                    encodeURIComponent(location.href);
                return false;
            }
            else if (Socialtext.S3 && jQuery.browser.msie) {
                // Cheap-and-cheerful-but-not-fun workaround for {bz: 1261}.
                // XXX TODO XXX - Implement a proper fix!
                window.location.reload();
            }

            jQuery("#st-edit-mode-container").hide();
            jQuery("#st-display-mode-container, #st-all-footers").show();

            ww.cancelEdit();
            ww.preview_link_reset();
            jQuery("#st-pagetools, #st-editing-tools-display").show();
            jQuery("#st-editing-tools-edit").hide();
            jQuery("#st-page-maincontent").css('margin-right', '0px');

            if (Page.element && Page.element.content) {
                jQuery(Page.element.content).css("height", "100%");
            }

            // XXX WTF? ENOFUNCTION
            //do_post_cancel_tidying();
            ww.disableLinkConfirmations();

            ww.is_editing = false;
            ww.showScrollbars();

            Socialtext.ui_expand_off();
        } catch(e) {}
        return false;
    });

    jQuery('#st-preview-button-link')
        .unbind('click')
        .click(function () {
            ww.preview_link_action();
            return false;
        });

    if (window.wikiwyg_nlw_debug) {
        jQuery('#edit-wikiwyg-html-link').click( function() {
            ww.switchMode(WW_HTML_MODE);
            return false;
        })
    }

    jQuery('#st-mode-wysiwyg-button').click(function () {
        ww.button_enabled_func(WW_SIMPLE_MODE)();
        return false;
    });

    // Disable simple mode button for Safari browser.
    if ( Wikiwyg.is_safari )  {
        jQuery('#st-mode-wysiwyg-button')
            .css("text-decoration", "line-through")
            .unbind("click")
            .bind("click", function() {
                alert(loc("Safari does not support simple mode editing"));
                return false;
            });
    }

    jQuery('#st-mode-wikitext-button').click(function() {
        ww.button_enabled_func(WW_ADVANCED_MODE)();
        return false;
    });

    jQuery('#st-edit-mode-tagbutton').click(function() {
        jQuery.showLightbox({
            content:'#st-tagqueue-interface',
            close:'#st-tagqueue-close'
        });
        return false;
    });

    jQuery('#st-tagqueue-field')
        .lookahead({
            submitOnClick: true,
            url: '/data/workspaces/' + Socialtext.wiki_id + '/tags',
            linkText: function (i) {
                return [i.name, i.name];
            }
        });

    var add_tag = function() {
        var rand = (''+Math.random()).replace(/\./, '');
        var input_field = jQuery('#st-tagqueue-field');
        var tag = input_field.val();
        input_field.val('');

        var skip = false;
        jQuery('.st-tagqueue-taglist-name').each(function (index, element) {
            var text = jQuery(element).text();
            text = text.replace(/^, /, '');
            if ( tag == text ) {
                skip = true;
            }
        });

        if ( skip ) { return false; }

        jQuery('<input type="hidden" name="add_tag" />')
            .attr('id', 'st-tagqueue-'+rand)
            .attr('value', tag)
            .appendTo('#st-page-editing-files');

        jQuery('#st-tagqueue-list').show();
        jQuery('<span class="st-tagqueue-taglist-name" />')
            .attr('id', 'st-taglist-'+rand)
            .append(
                jQuery('.st-tagqueue-taglist-name').size() ? ', ' : '',
                tag,
                jQuery('<a class="st-tagqueue-taglist-delete" />')
                    .attr('title', loc("Remove [_1] from the queue", tag))
                    .attr('href', '#')
                    .click(function () {
                        jQuery('#st-taglist-'+rand).remove();
                        jQuery('#st-tagqueue-'+rand).remove();
                        if (!jQuery('.st-tagqueue-taglist-name').size())
                            jQuery('#st-tagqueue-list').hide();
                        return false;
                    })
                    .html(Socialtext.S3
                        ? '<img src="/static/skin/common/images/delete.png" width="16" height="16" border="0" />'
                        : '[x]'
                    )
            )
            .appendTo('#st-tagqueue-list');
        return false;
    };

    if (Socialtext.S3) {
        jQuery('#st-tagqueue').submit(add_tag);
    }
    else {
        jQuery('#st-tagqueue-submitbutton').click(add_tag);
    }

    jQuery('#st-edit-mode-uploadbutton').click(function () {
        Attachments.showUploadInterface();
        $('#st-attachments-attach-editmode').val(1);
        return false;
    });

    ww.modeButtonMap = bmap = {};
    bmap[WW_SIMPLE_MODE] = jQuery('#st-mode-wysiwyg-button').get(0);
    bmap[WW_ADVANCED_MODE] = jQuery('#st-mode-wikitext-button').get(0);
    bmap[WW_PREVIEW_MODE] = jQuery('#st-preview-button-link').get(0);
    bmap[WW_HTML_MODE] = jQuery('#edit-wikiwyg-html-link').get(0);
}

Wikiwyg.setup_newpage = function() {
    if (Socialtext.new_page) {
        jQuery('#st-save-button-link').click(function () {
            wikiwyg.saveNewPage();
            return false;
        });

        jQuery('#st-newpage-duplicate-okbutton').click(function () {
            wikiwyg.newpage_duplicate_ok();
            return false;
        });

        jQuery('#st-newpage-duplicate-cancelbutton').click(function () {
            jQuery.hideLightbox();
            return false;
        });

        // XXX Observe
        jQuery('#st-newpage-duplicate-pagename').bind('keyup', 
            function(event) {
                wikiwyg.newpage_duplicate_pagename_keyupHandler(event);
            }
        );
        jQuery('#st-newpage-duplicate-option-different').bind('keyup',
            function(event) {
                wikiwyg.newpage_duplicate_keyupHandler(event);
            }
        );
        jQuery('#st-newpage-duplicate-option-suggest').bind('keyup',
            function(event) {
                wikiwyg.newpage_duplicate_keyupHandler(event);
            }
        );
        jQuery('#st-newpage-duplicate-option-append').bind('keyup',
            function(event) {
                wikiwyg.newpage_duplicate_keyupHandler(event);
            }
        );
    }
}

/*==============================================================================
Socialtext Wikiwyg subclass
 =============================================================================*/
proto = new Subclass('Wikiwyg.Socialtext', 'Wikiwyg');

proto.default_config = {
    toolbarClass: 'Wikiwyg.Toolbar.Socialtext',
    modeClasses: [ WW_SIMPLE_MODE, WW_ADVANCED_MODE, WW_PREVIEW_MODE ]
}

if (window.wikiwyg_nlw_debug)
    proto.default_config.modeClasses.push(WW_HTML_MODE);

proto.placeToolbar = function(toolbar_div) {
    jQuery('#st-page-editing-toolbar')
        .append(toolbar_div);
}

proto.hideScrollbars = function () {
    this._originalHTMLOverflow = jQuery('html').css('overflow') || 'visible';
    this._originalBodyOverflow = jQuery('body').css('overflow') || 'visible';
}

proto.showScrollbars = function () {
    jQuery('html').css('overflow', this._originalHTMLOverflow);
    jQuery('body').css('overflow', this._originalBodyOverflow);
}

proto.resizeEditor = function () {
    if (!this.is_editing) return;
    if (this.__resizing) return;
    this.__resizing = true;

    this.modeByName(WW_SIMPLE_MODE).setHeightOf(this.modeByName(WW_SIMPLE_MODE).edit_iframe);
    this.modeByName(WW_ADVANCED_MODE).setHeightOfEditor();

    var $iframe = jQuery('#st-page-editing-wysiwyg');
    var $textarea = jQuery('#wikiwyg_wikitext_textarea');

    var self = this;
    if (
        jQuery(window).width() > $iframe.width() * 3  ||
        jQuery(window).width() > $textarea.width() * 3 
    ) {
        // console.log("iframe/textarea is too small to make sense, wait a little bit");
        self.__resizing = false;
        setTimeout( function() { self.resizeEditor() }, 100 );
        return;
    }

    if ($iframe.is(":visible")) {
        jQuery("#st-editing-prefix-container").width($iframe.width()+2);
        $iframe.width( jQuery('#st-edit-mode-view').width() - 48 );
    }
    else if ($textarea.is(":visible")) {
        jQuery("#st-editing-prefix-container").width($textarea.width());
    }


    self.__resizing = false;
}

proto.preview_link_text = loc('Preview');
proto.preview_link_more = loc('Edit More');

proto.preview_link_action = function() {
    var preview = this.modeButtonMap[WW_PREVIEW_MODE];
    var current = this.current_mode;

    preview.innerHTML = this.preview_link_more;
    jQuery("#st-edit-mode-toolbar").hide();
    this.showScrollbars();

    var self = this;
    jQuery(preview)
        .unbind('click')
        .click(this.button_disabled_func());
    this.enable_edit_more = function() {
        jQuery(preview)
            .removeClass('previewButton')
            .addClass('editButton')
            .unbind('click')
            .click( function () {
                if (jQuery("#contentRight").is(":visible")) 
                    jQuery('#st-page-maincontent')
                        .css({ 'margin-right': '240px'});
                self.switchMode(current.classname);
                self.preview_link_reset();

                // This timeout is for IE so the iframe is ready - {bz: 1358}.
                setTimeout(function() {
                    self.resizeEditor();
                    self.hideScrollbars();
                }, 50);

                return false;
            });
    }
    this.modeByName(WW_PREVIEW_MODE).div.innerHTML = "";
    this.switchMode(WW_PREVIEW_MODE)
    this.disable_button(current.classname);

    jQuery('#st-page-maincontent').attr('marginRight', '0px');
    return false;
}

proto.preview_link_reset = function() {
    var preview = this.modeButtonMap[WW_PREVIEW_MODE];

    preview.innerHTML = this.preview_link_text;
    jQuery("#st-edit-mode-toolbar").show();

    var self = this;
    jQuery(preview)
        .removeClass('editButton')
        .addClass('previewButton')
        .unbind('click')
        .click( function() {
            self.preview_link_action();
            return false;
        });
}

proto.enable_button = function(mode_name) {
    if (mode_name == WW_PREVIEW_MODE) return;
    var button = this.modeButtonMap[mode_name];
    if (! button) return; // for when the debugging button doesn't exist

    if (Socialtext.S3) {
        jQuery(button).removeClass('disabled');
    }
    else {
        button.style.fontWeight = 'normal';
        button.style.background = 'none';
        button.style.textDecoration = 'underline';
        button.style.color = 'blue';  // XXX should not be hardcoded
    }

    jQuery(button).unbind('click').click(this.button_enabled_func(mode_name));
}

proto.button_enabled_func = function(mode_name) {
    var self = this;
    return function() {
        if (mode_name == self.current_mode.classname) {
            /* Already in the correct mode -- No need to switch */
            return false;
        }
        self.message.clear();
        self.switchMode(mode_name);
        for (var mode in self.modeButtonMap) {
            if (mode != mode_name)
                self.enable_button(mode);
        }
        self.preview_link_reset();
        Cookie.set('first_wikiwyg_mode', mode_name);
        self.setFirstModeByName(mode_name);
        return false;
    }
}

proto.disable_button = function(mode_name) {
    if (mode_name == WW_PREVIEW_MODE) return;
    var button = this.modeButtonMap[mode_name];
    if (Socialtext.S3) {
        jQuery(button).addClass('disabled');
    }
    else {
        button.style.fontWeight = 'bold';
        button.style.textDecoration = 'none';
        button.style.background = 'none';
        button.style.color = 'black';
    }
    button.onclick = this.button_disabled_func(mode_name);
}

proto.button_disabled_func = function(mode_name) {
    return function() { return false }
}

proto.active_page_exists = function (page_name) {
    return Page.active_page_exists(page_name);
}

proto.newpage_duplicate_pagename_keyupHandler = function(event) {
    jQuery('#st-newpage-duplicate-option-different').attr('checked', true);
    jQuery('#st-newpage-duplicate-option-suggest').attr('checked', false);
    jQuery('#st-newpage-duplicate-option-append').attr('checked', false);
    return this.newpage_duplicate_keyupHandler(event);
}

proto.newpage_duplicate_keyupHandler = function(event) {
    var key;

    if (window.event) {
        key = window.event.keyCode;
    }
    else if (event.which) {
        key = event.which;
    }

    if (key == Event.KEY_RETURN) {
        this.newpage_duplicate_ok();
        return false;
    }
}

proto.newpage_display_duplicate_dialog = function(page_name) {
    jQuery('#st-newpage-duplicate-suggest')
        .html(Socialtext.username + ': ' + page_name);
    jQuery('#st-newpage-duplicate-appendname').html(page_name);

    jQuery('#st-newpage-duplicate-link')
        .html(page_name)
        .attr('href', '/' + Socialtext.wiki_id + '/index.cgi?' + page_name)
        .attr('target', page_name);
    
    jQuery('#st-newpage-duplicate-pagename').val(page_name);
    jQuery('#st-newpage-duplicate-option-different').attr('checked', true);
    jQuery('#st-newpage-duplicate-option-suggest').attr('checked', false);
    jQuery('#st-newpage-duplicate-option-append').attr('checked', false);
    jQuery('#st-newpage-duplicate').show();
    jQuery('#st-newpage-duplicate-pagename').trigger('focus');

    jQuery.showLightbox({
        content:'#st-newpage-duplicate-interface',
        close:'#st-newpage-duplicate-cancelbutton'
    });

    return false;
}

proto.newpage_save = function(page_name, pagename_editfield) {
    var saved = false;
    page_name = trim(page_name);

    if (page_name.length == 0) {
        alert(loc('You must specify a page name'));
        if (pagename_editfield) {
            pagename_editfield.focus();
        }
    }
    else if (is_reserved_pagename(page_name)) {
        alert(loc('"[_1]" is a reserved page name. Please use a different name', page_name));
        if (pagename_editfield) {
            pagename_editfield.focus();
        }
    }
    else if (encodeURIComponent(page_name).length > 255) {
        alert(loc('Page title is too long after URL encoding'));
        if (pagename_editfield) {
            pagename_editfield.focus();
        }
    }
    else {
        if (this.active_page_exists(page_name)) {
            jQuery.hideLightbox();
            setTimeout(function () {
                wikiwyg.newpage_display_duplicate_dialog(page_name)
            }, 1000);
        } else {
            jQuery('#st-page-editing-pagename').val(page_name);
            this.saveContent();
            saved = true;
        }
    }
    return saved;
}

proto.saveContent = function() {
    if (jQuery('#st-editing-tools-edit ul').is(':hidden')) {
        // Don't allow "Save" to be clicked while saving: {bz: 1718}
        return;
    }

    jQuery('#st-editing-tools-edit ul').hide();
    jQuery('<div id="saving-message" />')
        .html(loc('Saving...'))
        .css('color', 'red')
        .appendTo('#st-editing-tools-edit');

    var self = this;
    setTimeout(function(){
        self.saveChanges();
    }, 1);
}


proto.newpage_saveClicked = function() {
    var page_name = jQuery('#st-page-editing-pagename').val() || '';
    var focus_field = jQuery(
        '#st-page-editing-pagename:visible, #st-newpage-save-pagename:visible'
    );
    var saved = this.newpage_save(page_name, focus_field.get(0));
    if (saved) {
        jQuery.hideLightbox();
    }
    return saved;
}

proto.newpage_duplicate_ok = function() {
    // Ok - this is the suck. I am duplicating the radio buttons in the HTML form here
    // in the JavaScript code. Damn deadlines
    var options = ['different', 'suggest', 'append'];
    var option = jQuery('input[name=st-newpage-duplicate-option]:checked').val();
    if (!option) {
        alert(loc('You must select one of the options or click cancel'));
        return;
    }
    switch(option) {
        case 'different':
            var edit_field = jQuery('#st-newpage-duplicate-pagename');
            if (this.newpage_save(edit_field.val(), edit_field.get(0))) {
                jQuery.hideLightbox();
            }
            break;
        case 'suggest':
            var name = jQuery('#st-newpage-duplicate-suggest').html();
            if (this.newpage_save(name)) {
                jQuery.hideLightbox();
            }
            break;
        case 'append':
            jQuery('#st-page-editing-append').val('bottom');
            jQuery('#st-page-editing-pagename').val(
                jQuery('#st-newpage-duplicate-appendname').html()
            );
            jQuery.hideLightbox();
            this.saveContent();
            break;
    }
    return false;
}

proto.displayNewPageDialog = function() {
    jQuery('#st-newpage-save-pagename').val('');
    jQuery.showLightbox({
        content: '#st-newpage-save',
        close: '#st-newpage-save-cancelbutton',
        focus: '#st-newpage-save-pagename'
    });
    jQuery('#st-newpage-save-form').unbind('submit').submit( function () {
        jQuery('#st-page-editing-pagename').val(
            jQuery('#st-newpage-save-pagename').val()
        );
        wikiwyg.newpage_saveClicked();
        return false;
    });
    jQuery('#st-newpage-save-savebutton').unbind('click').click(function () {
        jQuery('#st-newpage-save-form').submit();
        return false;
    });
    return false;
}

proto.saveButtonHandler = function() {
    if (Socialtext.new_page) {
        this.saveNewPage();
    }
    else {
        this.saveContent();
    }

    return false;
}

proto.saveNewPage = function() {
    var new_page_name = jQuery('#st-newpage-pagename-edit').val();
    if (trim(new_page_name).length > 0 && ! is_reserved_pagename(new_page_name)) {
        if (this.active_page_exists(new_page_name)) {
            jQuery('#st-page-editing-pagename').val(new_page_name);
            return this.newpage_saveClicked();
        }
        else  {
            if (encodeURIComponent(new_page_name).length > 255) {
                alert(loc('Page title is too long after URL encoding'));
                this.displayNewPageDialog();
                return;
            }
            jQuery('#st-page-editing-pagename').val(new_page_name);
            this.saveContent();
        }
    }
    else {
        this.displayNewPageDialog();
    }
}

proto.saveChanges = function() {
    this.disableLinkConfirmations();
    var submit_changes = function(wikitext) {
        /*
        if ( Wikiwyg.is_safari ) {
            var e = $("content-edit-body");
            e.style.display = "block";
            e.style.height = "1px";
        }
        */

        var saver = function() {
            // Move Images from "Current Page" to the new page
            if (Socialtext.new_page) {
                var files = Attachments.get_new_attachments();

                jQuery.each(files, function () {
                    jQuery('<input type="hidden" name="attachment" />')
                        .val(this['id'] + ':' + this['page-id'])
                        .appendTo('#st-page-editing-files');
                });
            }

            jQuery('#st-page-editing-pagebody').val(wikitext);
            jQuery('#st-page-editing-form').trigger('submit');
            return true;
        }

        // This timeout is so that safari's text box is ready
        setTimeout(function() { return saver() }, 1);

        return true;
    }

    // Safari just saves the wikitext, with no conversion.
    if (Wikiwyg.is_safari) {
        var wikitext_mode = this.modeByName(WW_ADVANCED_MODE);
        var wikitext = wikitext_mode.toWikitext();
        submit_changes(wikitext);
        return;
    }
    var self = this;
    this.current_mode.toHtml(
        function(html) {
            var wikitext_mode = self.modeByName(WW_ADVANCED_MODE);
            wikitext_mode.convertHtmlToWikitext(
                html,
                function(wikitext) { submit_changes(wikitext) }
            );
        }
    );
}

proto.confirmLinkFromEdit = function() {
    if (wikiwyg.contentIsModified()) {
        var response = confirm(loc("Are you sure you want to navigate away from this page?\n\nYou have unsaved changes.\n\nPress OK to continue, or Cancel to stay on the current page."));

        // wikiwyg.confirmed is for the situations when multiple confirmations
        // are considered. It store the value of this confirmation for
        // other handlers to check whether user has already confirmed
        // or not.
        wikiwyg.confirmed = response;

        if (response) {
            wikiwyg.disableLinkConfirmations();
        }
        return response;
    }
    return true;
}

proto.enableLinkConfirmations = function() {
    this.originalWikitext = Wikiwyg.is_safari
        ? this.mode_objects[WW_ADVANCED_MODE].getTextArea()
        : this.get_wikitext_from_html(this.div.innerHTML);

    wikiwyg.confirmed = false;

    window.onbeforeunload = function(ev) {
        if (typeof Selenium != 'undefined') {
            /* Selenium cannot handle .onbeforeunload, so simply let the
             * browser unload the window because there's no way to force
             * "Cancel" from within Javascript.
             */
            return undefined;
        }

        var msg = loc("You have unsaved changes.");
        if (!ev) ev = window.event;
        if ( wikiwyg.confirmed != true && wikiwyg.contentIsModified() ) {
            if (Wikiwyg.is_safari) {
                return msg;
            }
            ev.returnValue = msg;
        }
    }

    window.onunload = function(ev) {
        Attachments.delete_new_attachments();
    }

    /* Handle the Home link explicitly instead of relying on
     * window.onbeforeunload, so Selenium can test it.
     */
    jQuery('#st-home-link').click(this.confirmLinkFromEdit);
 
    return false;
}

proto.disableLinkConfirmations = function() {
    this.originalWikitext = null;
    window.onbeforeunload = null;
    window.onunload = null;

    var links = document.getElementsByTagName('a');
    for (var i = 0; i < links.length; i++) {
        if (links[i].onclick == this.confirmLinkFromEdit)
            links[i].onclick = null;
    }

    // Disable the Home confirmLinkFromEdit trigger explicitly. -- {bz: 1735}
    jQuery('#st-home-link').unbind('click');
}

proto.contentIsModified = function() {
    if (this.originalWikitext == null) {
        return true;
    }
    // XXX This could be done more upstream...
    var current_wikitext = this.get_current_wikitext().replace(
        /\r/g, ''
    );
    return (current_wikitext != this.originalWikitext);
}

proto.diffContent = function () {
    if (this.originalWikitext == null) {
        jQuery.showLightbox('There is no originalWikitext');
    }
    else if (this.contentIsModified()) {
        var current_wikitext = this.get_current_wikitext().replace(/\r/g, '');
        jQuery.ajax({
            type: 'POST',
            url: location.pathname,
            data: {
                action: 'wikiwyg_diff',
                text1: this.originalWikitext,
                text2: current_wikitext
            },
            success: function (data) {
                jQuery.showLightbox({
                    html: '<pre style="font-family:Courier">'+data+'</pre>',
                    width: '95%'
                });
            }
        });
    }
    else {
        jQuery.showLightbox("Content is not modified");
    }
    return void(0);
}

proto.get_current_wikitext = function() {
    if (this.current_mode.classname.match(/Wikitext/))
        return this.current_mode.toWikitext();
    var html = (this.current_mode.classname.match(/Wysiwyg/))
        ? this.current_mode.get_inner_html()
        : this.current_mode.div.innerHTML;
    return this.get_wikitext_from_html(html);
}

proto.get_wikitext_from_html = function(html) {
    return eval(WW_ADVANCED_MODE).prototype.convert_html_to_wikitext(html);
}

proto.set_edit_tips_span_display = function(display) {
    jQuery('#st-edit-tips').css('display', display);

    if (Socialtext.S3) {
        jQuery('#st-edit-tips')
            .unbind('click')
            .click(function () {
                jQuery.showLightbox({
                    content: '#st-ref-card',
                    close: '#st-ref-card-close'
                });
                return false;
            });
    }
}

proto.editMode = function() {
    if (Socialtext.page_type == 'spreadsheet') return;

    this.hideScrollbars();
    this.current_mode = this.first_mode;
    this.current_mode.fromHtml(this.div.innerHTML);
    this.toolbarObject.resetModeSelector();
    this.current_mode.enableThis();
}

proto.get_inner_html = function( cb ) {
    if ( cb ) {
        this.get_inner_html_async( cb );
        return;
    }

    var result = '';
    try {
        result = this.get_editable_div().innerHTML;
    } catch (e) {};
    return result;
}

proto.set_inner_html = function(html) {
    var self = this;
    var doc = this.get_edit_document();
    if ( doc.readyState == 'loading' ) {
        setTimeout( function() {
            self.set_inner_html(html);
        }, 500);
    } else {
        try { 
            this.get_editable_div().innerHTML = html;
        } catch (e) {
            setTimeout( function() {
                self.set_inner_html(html);
            }, 500);
        }
    }
}


/*==============================================================================
Mode class generic overrides.
 =============================================================================*/
proto = Wikiwyg.Mode.prototype;

// magic constant to make sure edit window does not scroll off page
proto.footer_offset = Wikiwyg.is_ie? 15 : 10;

proto.get_offset_top = function (e) {
    var offset = jQuery(e).offset();
    return offset.top;
}

// XXX - Hardcoded until we can get height of Save/Preview/Cancel buttons
proto.get_edit_height = function() {
    var available_height = jQuery(window).height();
    var edit_height = available_height -
                      this.get_offset_top(this.div) -
                      this.wikiwyg.toolbarObject.div.offsetHeight -
                      this.footer_offset;

    if (edit_height < 100) edit_height = 100;
    return edit_height;
}

proto.enableStarted = function() {
    jQuery('#st-editing-tools-edit ul').hide();
    jQuery('<div id="loading-message" />')
        .html(loc('Loading...'))
        .appendTo('#st-editing-tools-edit');
    this.wikiwyg.disable_button(this.classname);
    this.wikiwyg.enable_button(this.wikiwyg.current_mode.classname);
}

proto.enableFinished = function() {
    jQuery('#loading-message').remove();
    jQuery('#st-editing-tools-edit ul').show();
}

var WW_ERROR_TABLE_SPEC_BAD =
    loc("That doesn't appear to be a valid number.");
var WW_ERROR_TABLE_SPEC_HAS_ZERO =
    loc("Can't have a 0 for a size.");
proto.parse_input_as_table_spec = function(input) {
    var match = input.match(/^\s*(\d+)(?:\s*x\s*(\d+))?\s*$/i);
    if (match == null)
        return [ false, WW_ERROR_TABLE_SPEC_BAD ];
    var one = match[1], two = match[2];
    function tooSmall(x) { return x.match(/^0+$/) ? true : false };
    if (two == null) two = ''; // IE hack
    if (tooSmall(one) || (two && tooSmall(two)))
        return [ false, WW_ERROR_TABLE_SPEC_HAS_ZERO ];
    return [ true, one, two ];
}

proto.prompt_for_table_dimensions = function() {
    var rows, columns;
    var errorText = '';
    var promptTextMessageForRows = loc('Please enter the number of table rows:');
    var promptTextMessageForColumns = loc('Please enter the number of table columns:');
    
    while (!(rows && columns)) {
        var promptText;

        if(rows) {
           promptText = promptTextMessageForColumns;
        } else {
           promptText = promptTextMessageForRows;
        }

        if (errorText)
            promptText = errorText + "\n" + promptText;

        errorText = null;

        var answer = prompt(promptText, '3');
        if (!answer)
            return null;
        var result = this.parse_input_as_table_spec(answer);
        if (! result[0]) {
            errorText = result[1];
        }
         else if (! rows || result[2]) {
            rows = result[1];
            columns = result[2];
        }
        else {
            columns = result[1];
        }

        if (rows && rows > 100) {
            errorText = loc('Rows is too big. 100 maximum.');
            rows = null;
        }
        if (columns && columns > 35) {
            errorText = loc('Columns is too big. 35 maximum.');
            columns = null;
        }
    }
    return [ rows, columns ];
}

proto._do_link = function(widget_element) {
    var self = this;

    if (!jQuery('#st-widget-link-dialog').size()) {
        Socialtext.wikiwyg_variables.loc = loc;
        jQuery('body').append(
            Jemplate.process("add-a-link.html", Socialtext.wikiwyg_variables)
        );
    }

    var selection = this.get_selection_text();
    if (!widget_element || !widget_element.nodeName ) {
        widget_element = false;
    }

    var dummy_widget = {'title_and_id': { 'workspace_id': {'id': "", 'title': ""}}};
    if (widget_element) {
        var widget = this.parseWidgetElement(widget_element);
        if (widget.section_name && !widget.label && !widget.workspace_id && !widget.page_title) {
            // pre-populate the section link section
            jQuery("#section-link-text").val(widget.section_name);
            jQuery("#add-section-link").attr('checked', true);
        }
        else { 
            // Pre-populate the wiki link section
            jQuery("#wiki-link-text").val(widget.label || "");

            var ws_id    = widget.workspace_id || "";
            var ws_title = this.lookupTitle( "workspace_id", ws_id );
            dummy_widget.title_and_id.workspace_id.id    = ws_id;
            dummy_widget.title_and_id.workspace_id.title = ws_title || "";
            jQuery("#st-widget-workspace_id").val(ws_title || ws_id || "");

            jQuery("#st-widget-page_title").val(widget.page_title || "");
            jQuery("#wiki-link-section").val(widget.section_name || "");
        }
    }
    else if (selection) {
        // IE returns the actual selection element as a string, rather than
        // just the selection element's HTML. Eew.
        if ( Wikiwyg.is_ie ) {
            selection = selection.replace( /<[^>]+>/g, '' );
        }

        jQuery('#st-widget-page_title').val(selection);
        jQuery('#web-link-text').val(selection);
    }

    if (! jQuery("#st-widget-page_title").val() ) {
        jQuery('#st-widget-page_title').val(Socialtext.page_title || "");
    }

    var ws = jQuery('#st-widget-workspace_id').val() || Socialtext.wiki_id;
    jQuery('#st-widget-page_title')
        .lookahead({
            url: function () {
                var ws = jQuery('#st-widget-workspace_id').val() ||
                         Socialtext.wiki_id;
                return '/data/workspaces/' + ws + '/pages';
            },
            params: { minimal_pages: 1 },
            linkText: function (i) { return i.name },
            onError: {
                404: function () {
                    var ws = jQuery('#st-widget-workspace_id').val() ||
                             Socialtext.wiki_id;
                    return(
                        '<span class="st-suggestion-warning">'
                        + loc('Workspace "[_1]" does not exist on wiki', ws)
                        + '</span>'
                    );
                }
            }
        });

    jQuery('#st-widget-workspace_id')
        .lookahead({
            filterName: 'title_filter',
            url: '/data/workspaces',
            linkText: function (i) {
                return [ i.title + ' (' + i.name + ')', i.name ];
            }
        });

    jQuery('#add-a-link-form')
        .unbind('reset')
        .unbind('submit')
        .bind('reset', function() {
            jQuery.hideLightbox();
            Wikiwyg.Widgets.widget_editing = 0;
            return false;
        })
        .submit(function() {
            if (jQuery.browser.msie)
                jQuery("<input type='text' />").appendTo('body').focus().remove();

            if (jQuery('#add-wiki-link').is(':checked')) {
                if (!self.add_wiki_link(widget_element, dummy_widget)) return false;
            }
            else if (jQuery('#add-section-link').is(':checked')) {
                if (!self.add_section_link(widget_element)) return false;
            }
            else {
                if (!self.add_web_link()) return false;
            }

            var close = function() {
                jQuery.hideLightbox();
                Wikiwyg.Widgets.widget_editing = 0;
            }

            if (jQuery.browser.msie)
                setTimeout(close, 50);
            else
                close();

            return false;
        });

    jQuery('#add-a-link-error').hide();

    jQuery.showLightbox({
        content: '#st-widget-link-dialog',
        close: '#st-widget-link-cancelbutton'
    })

    // Set the unload handle explicitly so when user clicks the overlay gray
    // area to close lightbox, widget_editing will still be set to false.
    jQuery('#lightbox').unload(function(){
        Wikiwyg.Widgets.widget_editing = 0;
        if (wikiwyg.current_mode.set_focus) {
            wikiwyg.current_mode.set_focus();
        }
    });

    this.load_add_a_link_focus_handlers("add-wiki-link");
    this.load_add_a_link_focus_handlers("add-web-link");
    this.load_add_a_link_focus_handlers("add-section-link");

    var self = this;
    var callback = function(element) {
        var form    = jQuery("#add-a-link-form").get(0);
    }
}

proto.load_add_a_link_focus_handlers = function(radio_id) {
    var self = this;
    jQuery('#' + radio_id + '-section input[type=text]').focus(function () {
        jQuery('#' + radio_id).attr('checked', true);
    });
}

proto.set_add_a_link_error = function(msg) {
    jQuery("#add-a-link-error")
        .html('<span>' + msg + '</span>')
        .show()
}

proto.create_link_wafl = function(label, workspace, pagename, section) {
    var label_txt = label ? "\"" + label + "\"" : "";
    var wafl = label_txt + "{link:";
    if (workspace) { wafl += " " + workspace; }
    if (pagename) { wafl += " [" + pagename + "]"; }
    if (section) { wafl += " " + section; }
    wafl += "}";
    return wafl;
}

/*==============================================================================
Socialtext Wikiwyg Toolbar subclass
 =============================================================================*/
proto = new Subclass('Wikiwyg.Toolbar.Socialtext', 'Wikiwyg.Toolbar');

proto.imagesExtension = '.png';

proto.controlLayout = [
    '{other_buttons',
    'bold', 'italic', 'strike', '|',
    'h1', 'h2', 'h3', 'h4', 'p', '|',
    'ordered', 'unordered', 'outdent', 'indent', '|',
    'link', 'image', 'table', '|',
    '}',
    '{table_buttons disabled',
    'add-row-below', 'add-row-above',
    'move-row-down', 'move-row-up',
    'del-row',
    '|',
    'add-col-left', 'add-col-right',
    'move-col-left', 'move-col-right',
    'del-col',
    '}'
];

proto.controlLabels = {
    attach: loc('Link to Attachment'),
    bold: loc('Bold') + ' (Ctrl+b)',
    cancel: loc('Cancel'),
    h1: loc('Heading 1'),
    h2: loc('Heading 2'),
    h3: loc('Heading 3'),
    h4: loc('Heading 4'),
    h5: loc('Heading 5'),
    h6: loc('Heading 6'),
    help: loc('About Wikiwyg'),
    hr: loc('Horizontal Rule'),
    image: loc('Include an Image'),
    indent: loc('More Indented'),
    italic: loc('Italic') + '(Ctrl+i)',
    label: loc('[Style]'),
    link: loc('Create Link'),
    ordered: loc('Numbered List'),
    outdent: loc('Less Indented'),
    p: loc('Normal Text'),
    pre: loc('Preformatted'),
    save: loc('Save'),
    strike: loc('Strike Through') + '(Ctrl+d)',
    table: loc('New Table'),
    'add-row-above': loc('Add Table Row Above Current Row'),
    'add-row-below': loc('Add Table Row Below Current Row'),
    'add-col-left': loc('Add Table Column to the Left'),
    'add-col-right': loc('Add Table Column to the Right'),
    'del-row': loc('Delete Current Table Row'),
    'del-col': loc('Delete Current Table Column'),
    'move-row-up': loc('Move Current Table Row Up'),
    'move-row-down': loc('Move Current Table Row Down'),
    'move-col-left': loc('Move Current Table Column to the Left'),
    'move-col-right': loc('Move Current Table Column to the Right'),
    underline: loc('Underline') + '(Ctrl+u)',
    unlink: loc('Unlink'),
    unordered: loc('Bulleted List')
};

proto.resetModeSelector = function() {
    this.wikiwyg.disable_button(this.wikiwyg.first_mode.classname);
}

proto.add_styles = function() {
    var options = this.config.styleSelector;
    var labels = this.config.controlLabels;

    this.styleSelect = document.createElement('select');
    this.styleSelect.className = 'wikiwyg_selector';
    if (this.config.selectorWidth)
        this.styleSelect.style.width = this.config.selectorWidth;

    for (var i = 0; i < options.length; i++) {
        var value = options[i];
        var option = Wikiwyg.createElementWithAttrs(
            'option', { 'value': value }
        );
        var labelValue = labels[value] || value;
        var labelValue = labelValue.replace(/\\'/g, "'"); 
        var text = loc(labelValue);
        option.appendChild(document.createTextNode(text));
        this.styleSelect.appendChild(option);
    }
    var self = this;
    this.styleSelect.onchange = function() { 
        self.set_style(this.value) 
    };
    this.div.appendChild(this.styleSelect);
}


/*==============================================================================
Socialtext Wysiwyg subclass.
 =============================================================================*/
proto = new Subclass(WW_SIMPLE_MODE, 'Wikiwyg.Wysiwyg');

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

proto.enableThis = function() {
    Wikiwyg.Wysiwyg.prototype.enableThis.apply(this, arguments);

    var self = this;

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
        }
        catch(e) { }
    }, 1);

    if (!this.__toolbar_styling_interval)
        this.__toolbar_styling_interval = setInterval(function() {self.toolbarStyling() }, 1000);
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
    } catch(e) {}
    this.busy_styling = false;
}

proto.set_clear_handler = function () {
    var self = this;
    var editor = Wikiwyg.is_ie ? self.get_editable_div() : self.get_edit_window();

    var clean = function() {
        self.clear_inner_html();
        jQuery(editor).unbind();
    };

    try {
        jQuery(editor).one("click", clean).one("keydown", clean);
    } catch (e) {};
}

proto.fromHtml = function(html) {
    this.show_messages(html);
    Wikiwyg.Wysiwyg.prototype.fromHtml.call(this, html);
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
    Jemplate.Ajax.post(
        location.pathname,
        'action=wikiwyg_generate_widget_image;' +
        'widget=' + encodeURIComponent(widget_text) +
        ';widget_string=' + encodeURIComponent(wafl),
        function() {
            self.insert_widget(wafl, widget_element);
        }
    );
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

proto._do_table_manip = function(callback) {
    var doc = this.get_edit_document();
    jQuery("span.find-cursor", doc).removeClass('find-cursor');
    this.set_focus();
    this.insert_html( "<span class=\"find-cursor\"></span>" );

    var self = this;
    setTimeout(function() {
        var cur = window.cur = jQuery("span.find-cursor", doc);
        if (! cur.parents('td').length)
            return false;
        var $cell = cur.parents("td");
        cur.remove();

        var $new_cell = callback.call(self, $cell);

        if ($new_cell) {
            self.set_focus();
            if (jQuery.browser.mozilla) {
                self.get_edit_window().getSelection().collapse( $new_cell.find("span").get(0), 0 );
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
        var $table = $cell.parents("table");
        var col = self._find_column_index($cell);
        $table.find("td:nth-child(" + col + ")").each(function() {
            var $td = jQuery(doc.createElement('td'));
            $td.html('<span style=\"padding:0.5em\"></span>');
            jQuery(this).before($td);
        });
    });
}

proto.do_add_col_right = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        var doc = this.get_edit_document();
        var $table = $cell.parents("table");
        var col = self._find_column_index($cell);
        $table.find("td:nth-child(" + col + ")").each(function() {
            var $td = jQuery(doc.createElement('td'));
            $td.html('<span style=\"padding:0.5em\"></span>');
            jQuery(this).after($td);
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

proto.do_del_col = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        var $table = $cell.parents("table");
        var col = self._find_column_index($cell);

        var $new_cell = $cell.next();
        if (!$new_cell.length) {
            $new_cell = $cell.prev();
        }

        if ($new_cell.length) {
            $table.find("td:nth-child(" + col + ")").remove();
            return $new_cell;
        }
        else {
            $cell.parents("table").remove();
            return;
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
        var $table = $cell.parents("table");
        var col = self._find_column_index($cell);
        $table.find("td:nth-child(" + col + ")")
        .each(function() {
            var $c = jQuery(this);
            $c.prev().insertAfter( $c );
        });
    });
}

proto.do_move_col_right = function() {
    var self = this;
    this._do_table_manip(function($cell) {
        var $table = $cell.parents("table");
        var col = self._find_column_index($cell);
        $table.find("td:nth-child(" + col + ")")
        .each(function() {
            var $c = jQuery(this);
            $c.next().insertBefore( $c );
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
        var cur = window.cur = jQuery("span.find-cursor", doc);
        if (! cur.parents('td').length)
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

    return(this.get_edit_document().execCommand(command, false, option));
};

/*==============================================================================
Socialtext Preview subclass.
 =============================================================================*/
proto = new Subclass(WW_PREVIEW_MODE, 'Wikiwyg.Preview');

proto.fromHtml = function(html) {
    if (this.wikiwyg.previous_mode.classname.match(/Wysiwyg/)) {
        var wikitext_mode = this.wikiwyg.modeByName(WW_ADVANCED_MODE);
        var self = this;
        wikitext_mode.convertHtmlToWikitext(
            html,
            function(wikitext) {
                wikitext_mode.convertWikitextToHtml(
                    wikitext,
                    function(new_html) {
                        self.wikiwyg.enable_edit_more();
                        self.div.innerHTML = new_html;
                        self.div.style.display = 'block';
                        self.wikiwyg.enableLinkConfirmations();
                    }
                );
            }
        );
    }
    else {
        this.wikiwyg.enable_edit_more();
        this.div.innerHTML = html;
        this.div.style.display = 'block';
        this.wikiwyg.enableLinkConfirmations();
    }
}

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
    var wikitext = new Wikiwyg.Wikitext.Socialtext();
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
