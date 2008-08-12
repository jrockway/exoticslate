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
        var html = Jemplate.process('layout/edit_wikiwyg', Socialtext.wikiwyg_variables);

        var el = jQuery(html).get(0);
        var c = jQuery("#st-display-mode-container").get(0);
        c.parentNode.insertBefore(el, c.nextSibling);

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

    var clearRx = 
        new RegExp("^" + loc("Replace this text with your own.") + "\\s*$");

    // Wikiwyg configuration
    var myConfig = {
        doubleClickToEdit: false,
        firstMode: firstMode,
        javascriptLocation: nlw_make_s2_path('/javascript/'),
        toolbar: {
            imagesLocation: nlw_make_s2_path('/images/wikiwyg_icons/')
        },
        wysiwyg: {
            clearRegex: (
                Wikiwyg.is_ie ?
                    /^\s*Replace this text with your own.\s*<BR>\s*$/i :
                    /^<div class="?wiki"?>\s*Replace this text with your own.\s*<br><\/div>\s*$/i
            ),
            iframeId: 'st-page-editing-wysiwyg',
            editHeightMinimum: 200,
            editHeightAdjustment: 1.3
        },
        wikitext: {
            clearRegex: clearRx,
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

    // node handles
    var edit_bar = $('st-editing-tools-edit'); // XXX I think this is wrong
    var edit_link = $('st-edit-button-link');
    var save_link = $('st-save-button-link');
    var html_link = $('edit-wikiwyg-html-link');
    var preview_link = $('st-preview-button-link');
    var cancel_link = $('st-cancel-button-link');
    var wysiwyg_link = $('st-mode-wysiwyg-button');
    var wikitext_link = $('st-mode-wikitext-button');

    // For example, because of a unregistered user on a self-register space:
    if (!edit_bar || !edit_link)
        return;

    ww.wikitext_link = wikitext_link;

    Wikiwyg.setup_newpage();

    Wikiwyg.Socialtext.edit_bar = edit_bar;
    // XXX Surely we could use plain HTML here
    Wikiwyg.Socialtext.loading_bar = document.createElement("div");
    Wikiwyg.Socialtext.loading_bar.innerHTML =
        '<span style="color: red" id="loading-message">' + loc('Loading...') + '</span>';
    Wikiwyg.Socialtext.loading_bar.style.display = 'none';
    Wikiwyg.Socialtext.edit_bar.parentNode.appendChild(Wikiwyg.Socialtext.loading_bar);

    // XXX start_nlw_wikiwyg goes in the object because display_edit.js
    // wants it there.
    ww.start_nlw_wikiwyg = function() {
        Wikiwyg.transition_message({
            show: true,
            message: "Loading editor..."
        });
        try {
            Attachments.reset_new_attachments();
            if (Wikiwyg.is_safari) {
                delete ww.current_wikitext;
            }
            if (Wikiwyg.is_safari || Wikiwyg.is_old_firefox) {
                jQuery("#st-page-editing-uploadbutton").hide();
            }
            jQuery("#st-all-footers, #st-display-mode-container").hide();
            jQuery("#st-edit-mode-container").show();
 
            if (!Socialtext.new_page)
                Page.refresh_page_content();

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

            ww.set_edit_tips_span_display('none');
            ww.editMode();
            ww.preview_link_reset();
            jQuery("#st-pagetools").hide();
            Wikiwyg.transition_message({
                show: false
            });
            jQuery("#st-editing-tools-display").hide();
            jQuery("#st-editing-tools-edit, #wikiwyg_toolbar").show();

            if (jQuery("#st-page-boxes").is(":visible"))
                jQuery("#st-page-maincontent").css("margin-right", "240px");

            nlw_edit_controls_visible = true;
            ww.enableLinkConfirmations();

            jQuery(window).bind("resize", function () {
                ww.resizeEditor();
            }).trigger("resize");
 
            ww.is_editing = true;

            if (Wikiwyg.is_safari) {
                ww.message.display({
                    title: loc("Socialtext has limited editing capabilities in Safari."),
                    body: loc("<a target=\"_blank\" href=\"http://www.mozilla.com/firefox/\">Download Firefox</a> for richer Socialtext editing functionality.")
                });
            }

            //Socialtext.logEvent('edit_begin');

        } catch(e) {
            throw(e);
        }
        return false;
    }

    jQuery(edit_link).bind("click", ww.start_nlw_wikiwyg);

    jQuery("#st-edit-actions-below-fold-edit").bind("click", ww.start_nlw_wikiwyg);

    if (Socialtext.double_click_to_edit) {
        jQuery("#st-page-content").bind("dblclick", ww.start_nlw_wikiwyg);
    }

    jQuery(save_link).bind("click", function() {
        ww.is_editing = false;
        return ww.saveButtonHandler();
    });

    jQuery(cancel_link).bind("click", function() {
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
            jQuery("#st-edit-mode-container").hide();
            jQuery("#st-display-mode-container, #st-all-footers").show();

            //Socialtext.logEvent('edit_cancel');

            ww.cancelEdit();
            ww.preview_link_reset();
            window.TagQueue.clear_list();
            jQuery("#st-pagetools, #st-editing-tools-display").show();
            jQuery("#st-editing-tools-edit").hide();
            jQuery("#st-page-maincontent").css('margin-right', '0px');
            jQuery(Page.element.content).css("height", "100%");

            // XXX WTF? ENOFUNCTION
            //do_post_cancel_tidying();
            ww.disableLinkConfirmations();
            if (location.href.match(/caller_action=weblog_display;?/))
                location.href = 'index.cgi?action=weblog_redirect;start=' +
                    encodeURIComponent(location.href);

            ww.is_editing = false;
        } catch(e) {}
        return false;
    });

    preview_link.onclick = function() {
        return ww.preview_link_action();
    };

    if (window.wikiwyg_nlw_debug) {
        jQuery(html_link).bind("click", function() {
            ww.switchMode(WW_HTML_MODE);
            return false;
        })
    }

    wysiwyg_link.onclick = function() {
        ww.button_enabled_func(WW_SIMPLE_MODE)();
        return false;
    };

    // Disable simple mode button for Safari browser.
    if ( Wikiwyg.is_safari )  {
        jQuery(wysiwyg_link)
        .css("text-decoration", "line-through")
        .unbind("click")
        .bind("click", function() {
            alert(loc("Safari does not support simple mode editing"));
            return false;
        });
    }

    wikitext_link.onclick = function() {
        ww.button_enabled_func(WW_ADVANCED_MODE)();
        return false;
    };

    ww.modeButtonMap = {};
    ww.modeButtonMap[WW_SIMPLE_MODE] = wysiwyg_link;
    ww.modeButtonMap[WW_ADVANCED_MODE] = wikitext_link;
    ww.modeButtonMap[WW_PREVIEW_MODE] = preview_link;
    ww.modeButtonMap[WW_HTML_MODE] = html_link;
}

Wikiwyg.in_transition = false;
Wikiwyg.transition_message = function (arg) {
    var msg = $('st-editing-tools-transition-message');
    var toolbar = $('st-editing-tools-edit');
    if (arg.message) {
        Element.update(msg, arg.message);
    }
    if (arg.show) {
        Element.setStyle(toolbar, {display: 'none'});
        Element.setStyle(msg, {display: 'block'});
        Wikiwyg.in_transition = true;
    } else {
        Element.setStyle(msg, {display: 'none'});
        Element.setStyle(toolbar, {display: 'block'});
        Wikiwyg.in_transition = false;
    }
};

Wikiwyg.setup_newpage = function() {
    var newpage_saveName;
    var newpage_saveButton;
    var newpage_cancelButton;
    var newpage_duplicate_saveButton;
    var newpage_duplicate_cancelButton;
    if (Socialtext.new_page) {
        newpage_saveButton = $('st-newpage-save-savebutton');
        newpage_saveButton.onclick = function() {
            return wikiwyg.newpage_saveClicked();
        };

        newpage_cancelButton = $('st-newpage-save-cancelbutton');
        newpage_cancelButton.onclick = function() {
            return wikiwyg.newpage_cancel();
        };

        // XXX Observe
        newpage_saveName = $('st-newpage-save-pagename');
        newpage_saveName.onkeyup = function(event) {
            wikiwyg.newpage_keyupHandler(event);
        }

        newpage_duplicate_okButton = $('st-newpage-duplicate-okbutton');
        newpage_duplicate_okButton.onclick = function() {
            wikiwyg.newpage_duplicate_ok();
            return false;
        };

        newpage_duplicate_cancelButton = $('st-newpage-duplicate-cancelbutton');
        newpage_duplicate_cancelButton.onclick = function() {
            wikiwyg.newpage_duplicate_cancel();
            return false;
        };

        // XXX Observe
        $('st-newpage-duplicate-pagename').onkeyup = function(event) {
            wikiwyg.newpage_duplicate_pagename_keyupHandler(event);
        }
        $('st-newpage-duplicate-option-different').onkeyup = function(event) {
            wikiwyg.newpage_duplicate_keyupHandler(event);
        }
        $('st-newpage-duplicate-option-suggest').onkeyup = function(event) {
            wikiwyg.newpage_duplicate_keyupHandler(event);
        }
        $('st-newpage-duplicate-option-append').onkeyup = function(event) {
            wikiwyg.newpage_duplicate_keyupHandler(event);
        }

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
    var wikiwyg_edit_page_bar =
        $('st-page-editing-toolbar');
    if (! wikiwyg_edit_page_bar) {
        return;
    }
    wikiwyg_edit_page_bar.appendChild(toolbar_div);
}

proto.resizeEditor = function () {
    if (this.__resizing) return;
    this.__resizing = true;

    this.modeByName(WW_SIMPLE_MODE).setHeightOf(this.modeByName(WW_SIMPLE_MODE).edit_iframe);
    this.modeByName(WW_ADVANCED_MODE).setHeightOfEditor();

    var $iframe = jQuery('#st-page-editing-wysiwyg');
    var $textarea = jQuery('#wikiwyg_wikitext_textarea');

    if ($iframe.is(":visible"))
        jQuery("#st-editing-prefix-container").width($iframe.width()+2);
    else if ($textarea.is(":visible"))
        jQuery("#st-editing-prefix-container").width($textarea.width());

    this.__resizing = false;
}

proto.preview_link_text = loc('Preview');
proto.preview_link_more = loc('Edit More');

proto.preview_link_action = function() {
    var preview = this.modeButtonMap[WW_PREVIEW_MODE];
    var current = this.current_mode;

    preview.innerHTML = this.preview_link_more;
    jQuery("#st-edit-mode-toolbar").hide();

    var self = this;
    preview.onclick = this.button_disabled_func();
    this.enable_edit_more = function() {
        preview.onclick = function () {
            if (jQuery("#st-page-boxes").is(":visible")) 
                jQuery('#st-page-maincontent').css({ 'margin-right': '240px'});
            self.switchMode(current.classname);
            self.preview_link_reset();
            return false;
        }
    }
    this.modeByName(WW_PREVIEW_MODE).div.innerHTML = "";
    this.switchMode(WW_PREVIEW_MODE)
    this.disable_button(current.classname);

    if (window.wikiwyg_nlw_double_click_to_edit)
        this.mode_objects[WW_PREVIEW_MODE].div.ondblclick = preview.onclick;

    Element.setStyle('st-page-maincontent', {marginRight: '0px'});
    return false;
}

proto.preview_link_reset = function() {
    var preview = this.modeButtonMap[WW_PREVIEW_MODE];

    preview.innerHTML = this.preview_link_text;
    jQuery("#st-edit-mode-toolbar").show();

    var self = this;
    preview.onclick = function() {
        return self.preview_link_action();
    }
}

proto.enable_button = function(mode_name) {
    if (mode_name == WW_PREVIEW_MODE) return;
    var button = this.modeButtonMap[mode_name];
    if (! button) return; // for when the debugging button doesn't exist
    button.style.fontWeight = 'normal';
    button.style.background = 'none';
    button.style.textDecoration = 'underline';
    button.style.color = 'blue';  // XXX should not be hardcoded
    button.onclick = this.button_enabled_func(mode_name);
}

proto.button_enabled_func = function(mode_name) {
    var self = this;
    return function() {
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
    button.style.fontWeight = 'bold';
    button.style.textDecoration = 'none';
    button.style.background = 'none';
    button.style.color = 'black';
    button.onclick = this.button_disabled_func(mode_name);
}

proto.button_disabled_func = function(mode_name) {
    return function() { return false }
}

proto.newpage_keyupHandler = function(event) {
    var key;

    if (window.event) {
        key = window.event.keyCode;
    }
    else if (event.which) {
        key = event.which;
    }

    if (key == Event.KEY_RETURN) {
        this.newpage_saveClicked();
        return false;
    }
}

proto.newpage_duplicate_pagename_keyupHandler = function(event) {
    $('st-newpage-duplicate-option-different').checked = true;
    $('st-newpage-duplicate-option-suggest').checked = false;
    $('st-newpage-duplicate-option-append').checked = false;
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
    Element.update('st-newpage-duplicate-suggest',
        Socialtext.fullname + ': ' + page_name
    );
    Element.update('st-newpage-duplicate-appendname', page_name);
    Element.update('st-newpage-duplicate-link', page_name);
    $('st-newpage-duplicate-link').href = Page.ContentUri() + "?" + page_name;
    $('st-newpage-duplicate-link').target = page_name;
    $('st-newpage-duplicate-pagename').value = page_name;
    $('st-newpage-duplicate-option-different').checked = true;
    $('st-newpage-duplicate-option-suggest').checked = false;
    $('st-newpage-duplicate-option-append').checked = false;
    $('st-newpage-duplicate').style.display = 'block';
    $('st-newpage-duplicate-pagename').focus();

    var divs = {
        wrapper: $('st-newpage-duplicate'),
        background: $('st-newpage-duplicate-overlay'),
        content: $('st-newpage-duplicate-interface'),
        contentWrapper: $('st-newpage-duplicate-interface').parentNode
    }
    Widget.Lightbox.show({ divs:divs, effects:['RoundedCorners'] });
    divs.contentWrapper.style.width="520px";

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
        if (Page.active_page_exists(page_name)) {
            this.newpage_cancel();
            this.newpage_display_duplicate_dialog(page_name);
        } else {
            var formPageNameField = $('st-page-editing-pagename');
            formPageNameField.value = page_name;
            this.saveContent();
            saved = true;
        }
    }
    return saved;
}

proto.saveContent = function() {
    Wikiwyg.Socialtext.edit_bar.style.display = 'none';
    Wikiwyg.Socialtext.loading_bar.innerHTML =
        '<span style="color: red" id="saving-message">' + loc('Saving...') + '</span>';
    Wikiwyg.Socialtext.loading_bar.style.display = 'block';
    this.saveChanges();
}


proto.newpage_saveClicked = function() {
    var edit_field = $('st-newpage-save-pagename');
    var saved = this.newpage_save(edit_field.value, edit_field);
    if (saved) {
        $('st-newpage-save').style.display = 'none';
    }
    return saved;
}

proto.newpage_cancel = function() {
    $('st-newpage-save').style.display = 'none';
    return false;
}

proto.newpage_duplicate_ok = function() {
    // Ok - this is the suck. I am duplicating the radio buttons in the HTML form here
    // in the JavaScript code. Damn deadlines
    var options = ['different', 'suggest', 'append'];
    var option;
    for (var i=0; i< options.length; i++) {
        var node = $('st-newpage-duplicate-option-' + options[i]);
        if (node.checked) {
            option = node.value;
            break;
        }
    }
    if (!option) {
        alert(loc('You must select one of the options or click cancel'));
        return;
    }
    switch(option) {
        case 'different':
            var edit_field = $('st-newpage-duplicate-pagename');
            if (this.newpage_save(edit_field.value, edit_field)) {
                $('st-newpage-duplicate').style.display = 'none';
            } else {
                if (!is_reserved_pagename(edit_field.value)) {
                    Element.addClassName(
                        'st-newpage-duplicate-emphasis',
                        'st-newpage-duplicate-emphasis'
                    );
                }
            }
            break;
        case 'suggest':
            var suggest_name = $('st-newpage-duplicate-suggest');
            if (this.newpage_save(suggest_name.innerHTML)) {
                $('st-newpage-duplicate').style.display = 'none';
            }
            break;
        case 'append':
            $('st-page-editing-append').value='bottom';
            var pagename = $('st-newpage-duplicate-appendname').innerHTML;
            var formPageNameField = $('st-page-editing-pagename');
            formPageNameField.value = pagename;
            $('st-newpage-duplicate').style.display = 'none';
            this.saveContent();
            break;
    }
    return false;
}

proto.newpage_duplicate_cancel = function() {
    $('st-newpage-duplicate').style.display = 'none';
    return false;
}

proto.displayNewPageDialog = function() {
    $('st-newpage-save-pagename').value = '';
    $('st-newpage-duplicate-option-different').checked = false;
    $('st-newpage-duplicate-option-suggest').checked = false;
    $('st-newpage-duplicate-option-append').checked = false;
    Element.removeClassName(
        'st-newpage-duplicate-emphasis',
        'st-newpage-duplicate-emphasis'
    );
    $('st-newpage-save').style.display = 'block';

    var divs = {
        wrapper: $('st-newpage-save'),
        background: $('st-newpage-save-overlay'),
        content: $('st-newpage-save-interface'),
        contentWrapper: $('st-newpage-save-interface').parentNode
    }
    Widget.Lightbox.show({ 'divs': divs, 'effects': ['RoundedCorners'] });

    $('st-newpage-save-pagename').focus();

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
    var new_page_name = $('st-newpage-pagename-edit');
    var edit_page_name = $('st-page-editing-pagename');
    if (! is_reserved_pagename(new_page_name.value)
    ) {
        if (Page.active_page_exists(new_page_name.value)) {
            edit_page_name.value = new_page_name.value;
            $('st-newpage-save-pagename').value = new_page_name.value;
            return this.newpage_saveClicked();
        }
        else  {
            if (encodeURIComponent(new_page_name.value).length > 255) {
                alert(loc('Page title is too long after URL encoding'));
                this.displayNewPageDialog();
                return;
            }

            edit_page_name.value = new_page_name.value;
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
            var editList = $('st-page-editing-files');
            var new_page_name = $('st-newpage-pagename-edit');

            for (var i=0; i < window.TagQueue.count(); i++) {
                var new_input = document.createElement( 'input' );
                new_input.type = 'hidden';
                new_input.name = 'add_tag';
                new_input.value = window.TagQueue.tag(i);
                editList.appendChild(new_input);
            }
            window.TagQueue.clear_list();

            // Move Images from "Current Page" to the new page
            if (Socialtext.new_page) {
                var recent = Attachments.get_new_attachments();

                for (var i=0; i < recent.length; i++) {
                    var new_input = document.createElement( 'input' );
                    new_input.type = 'hidden';
                    new_input.name = 'attachment';
                    new_input.value = [ recent[i]['id'],
                                        recent[i]['page-id']
                                      ].join(':');
                    editList.appendChild(new_input);
                }
            }

            $('st-page-editing-pagebody').value = wikitext;
            $('st-page-editing-form').submit();
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
 
    var links = document.getElementsByTagName('a');
    for (var i = 0; i < links.length; i++) {
        if (links[i].id == 'st-cancel-button-link') continue;
        if (links[i].onclick) continue;
        if (links[i].id == 'st-save-button-link') continue;
        if (links[i].id == 'st-edit-mode-uploadbutton') continue;
        if (links[i].id == 'st-edit-mode-tagbutton') continue;
        if (links[i].id == 'st-attachmentsqueue-submitbutton') continue;
        if (links[i].id == 'st-attachmentsqueue-closebutton') continue;
        if (links[i].id == 'st-attachments-attach-closebutton') continue;
        if (links[i].id == 'st-tagqueue-closebutton') continue;
        if (links[i].id == 'st-tagqueue-submitbutton') continue;

        links[i].onclick = this.confirmLinkFromEdit;
    }
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
    var edit_tips = $('st-edit-tips');
    edit_tips.style.display = display;
}

proto.editMode = function() {
    if (Socialtext.page_type == 'spreadsheet') return;

    this.current_mode = this.first_mode;
    this.current_mode.fromHtml(this.div.innerHTML);
    this.toolbarObject.resetModeSelector();
    this.current_mode.enableThis();
}

/*==============================================================================
Mode class generic overrides.
 =============================================================================*/
proto = Wikiwyg.Mode.prototype;

// magic constant to make sure edit window does not scroll off page
proto.footer_offset = Wikiwyg.is_ie? 30 : 48;

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
    Wikiwyg.Socialtext.edit_bar.style.display = 'none';
    Wikiwyg.Socialtext.loading_bar.style.display = 'block';
    this.wikiwyg.disable_button(this.classname);
    this.wikiwyg.enable_button(this.wikiwyg.current_mode.classname);
}

proto.enableFinished = function() {
    Wikiwyg.Socialtext.loading_bar.style.display = 'none';
    Wikiwyg.Socialtext.edit_bar.style.display = 'block';
}

var WW_ERROR_TABLE_SPEC_BAD =
    loc("That doesn't appear to be a valid number.");
var WW_ERROR_TABLE_SPEC_TOO_BIG =
    loc("That seems like a bit too large for a table.");
var WW_ERROR_TABLE_SPEC_HAS_ZERO =
    loc("Can't have a 0 for a size.");
proto.parse_input_as_table_spec = function(input) {
    var match = input.match(/^\s*(\d+)(?:\s*x\s*(\d+))?\s*$/i);
    if (match == null)
        return [ false, WW_ERROR_TABLE_SPEC_BAD ];
    var one = match[1], two = match[2];
    function tooBig(x) { return x > 50 };
    function tooSmall(x) { return x.match(/^0+$/) ? true : false };
    if (two == null) two = ''; // IE hack
    if (tooBig(one) || (two != null) && tooBig(two))
        return [ false, WW_ERROR_TABLE_SPEC_TOO_BIG ];
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
    }
    return [ rows, columns ];
}

proto._do_link = function(widget_element) {
    var html = Jemplate.process("add-a-link.html", {});

    var box  = new Widget.Lightbox.Socialtext({contentClassName: 'jsan-widget-lightbox-content-wrapper', wrapperClassName: 'st-lightbox-dialog'});
    box.content( html );
    box.create();

    this.load_add_a_link_focus_handlers("add-wiki-link");
    this.load_add_a_link_focus_handlers("add-web-link");
    this.load_add_a_link_focus_handlers("add-section-link");

    var selection = this.get_selection_text();
    if (!widget_element || !widget_element.nodeName ) {
        widget_element = false;
    }

    var dummy_widget = {'title_and_id': { 'workspace_id': {'id': "", 'title': ""}}};
    if (widget_element) {
        var widget = this.parseWidgetElement(widget_element);
        if (widget.section_name && !widget.label && !widget.workspace_id && !widget.page_title) {
            // pre-populate the section link section
            $("section-link-text").value  = widget.section_name;
            $("add-section-link").checked = true;
        } else { 
            // Pre-populate the wiki link section
            $("wiki-link-text").value = widget.label || "";

            var ws_id    = widget.workspace_id || "";
            var ws_title = this.lookupTitle( "workspace_id", ws_id );
            dummy_widget.title_and_id.workspace_id.id    = ws_id;
            dummy_widget.title_and_id.workspace_id.title = ws_title || "";
            $("st-widget-workspace_id").value            = ws_title || ws_id || "";

            $("st-widget-page_title").value = widget.page_title || "";
            $("wiki-link-section").value = widget.section_name || "";
        }
    } else if (selection) {
        // IE returns the actual selection element as a string, rather than
        // just the selection element's HTML. Eew.
        if ( Wikiwyg.is_ie ) {
            selection = selection.replace( /<[^>]+>/g, '' );
        }

        $('st-widget-page_title').value = selection;
        $('web-link-text').value = selection;
    }

    if (! $("st-widget-page_title").value ) {
        $("st-widget-page_title").value = Socialtext.page_title || "";
    }

    var tmp = $("st-widget-workspace_id").value;
    this.setup_add_a_link_lookahead(box.divs.contentWrapper, dummy_widget);
    $("st-widget-workspace_id").value = tmp;

    var self = this;
    var callback = function(element) {
        var form    = $("add-a-link-form");
        var onreset = function() {
            box.releaseFocus();
            box.release();

            Wikiwyg.Widgets.widget_editing = 0;
            return false;
        }
        var onsubmit = function() {
            if ( jQuery.browser.msie )
                jQuery("<input type='text'>").appendTo(document.body).focus().remove();

            if ($('add-wiki-link').checked) {
                if (!self.add_wiki_link(widget_element, dummy_widget)) { return false; }
            } else if ($('add-section-link').checked) {
                if (!self.add_section_link(widget_element)) { return false; }
            } else {
                if (!self.add_web_link()) { return false; }
            }

            box.release();

            Wikiwyg.Widgets.widget_editing = 0;

            return false;
        }
        form.onsubmit = onsubmit;
        form.onreset  = onreset;
    }
    box.show(callback);
}

proto.setup_add_a_link_lookahead = function(dialog, widget) {
    var cssSugestionWindow = 'st-widget-lookaheadsuggestionwindow';
    var cssSuggestionBlock = 'st-widget-lookaheadsuggestionblock';
    var cssSuggestionText  = 'st-widget-lookaheadsuggestion';

    window.workspaceLookahead = new WorkspaceLookahead(
        dialog,
        'st-widget-workspace_id',
        cssSugestionWindow,
        cssSuggestionBlock,
        cssSuggestionText,
        'workspaceLookahead',
        widget
    );

    window.pageLookahead = new PageNameLookahead(
        dialog,
        'st-widget-page_title',
        cssSugestionWindow,
        cssSuggestionBlock,
        cssSuggestionText,
        'pageLookahead',
        widget
    );

    this.update_page_lookahead_workspace = function() {
        var new_ws = $('st-widget-workspace_id').value || Socialtext.wiki_id;
        if (new_ws != window.pageLookahead.defaultWorkspace) {
            window.pageLookahead.defaultWorkspace = new_ws;
        }
    }

    this.update_page_lookahead_workspace();
}

proto.load_add_a_link_focus_handlers = function(radio_id) {
    var radio  = $(radio_id);
    var inputs = $(radio_id + "-section").getElementsByTagName('input');
    var self   = this;
    var i;

    for (i = 0; i < inputs.length; i++) {
        if (inputs[i] != radio) {
            inputs[i].onfocus = function() {
                radio.checked = true;
                if (this.id == 'st-widget-page_title') {
                    self.update_page_lookahead_workspace();
                }
            }
        }
    }
}

proto.set_add_a_link_error = function(msg) {
    var div = $("add-a-link-error");
    if (div) {
        div.style.display = 'block';
        div.innerHTML = '<span>' + msg + '</span>';
    }
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

proto.controlLayout = [
    'bold', 'italic', 'strike', '|',
    'h1', 'h2', 'h3', 'h4', 'p', '|',
    'ordered', 'unordered', 'outdent', 'indent', '|',
    'link', 'image', 'table'
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
    table: loc('Create Table'),
    underline: loc('Underline') + '(Ctrl+u)',
    unlink: loc('Unlink'),
    unordered: loc('Bulleted List')
};

proto.add_separator = function() {
    var base = this.config.imagesLocation;
    var ext = this.config.imagesExtension;
    jQuery(this.div).append("&nbsp;&nbsp;&nbsp;");
}

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
    if (this['do_' + command])
        this['do_' + command](command);

    if ( command == 'link' ) {
        var self = this;
        setTimeout(function() {
            self.wikiwyg.toolbarObject
                .focus_link_menu('do_widget_link2', 'Wiki');
        }, 100);
    }
}

proto.enableThis = function() {
    Wikiwyg.Wysiwyg.prototype.enableThis.apply(this, arguments);

    var self = this;

    setTimeout(function() {
        try {
            if (Wikiwyg.is_gecko) self.get_edit_window().focus();
            if (Wikiwyg.is_ie) { 
                jQuery(self.get_editable_div()).focus().css({ overflow: 'visible' });
            }
        }
        catch(e) { }
    }, 1);
}

proto.set_clear_handler = function () {
    var self = this;
    var editor = Wikiwyg.is_ie ? self.get_editable_div() : self.get_edit_iframe();

    var clean = function() {
        self.clear_inner_html();
        jQuery(editor).unbind();
    };

    jQuery(editor).one("click", clean).one("keydown", clean);
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
    var label     = $("wiki-link-text").value; 
    var workspace = $("st-widget-workspace_id").value || "";
    var page_name = $("st-widget-page_title").value;
    var section   = $("wiki-link-section").value;
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
    var section = $("section-link-text").value;

    if (!section) {
        this.set_add_a_link_error( "Please fill in the section field for section links." );
        return false;
    } 

    var wafl = this.create_link_wafl(false, false, false, section);
    this.insert_link_wafl_widget(wafl, widget_element);

    return true;
}

proto.add_web_link = function() {
    var url       = $("web-link-destination").value;
    var url_text  = $("web-link-text").value;

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
    var text = html_escape( label || page_name || url );
    link_node.appendChild( document.createTextNode(text) );

    // Anchor HREF
    link_node.href = url || "?" + encodeURIComponent(page_name);

    // Anchor hint for "label"[page] style links
    if (label && page_name && label != page_name) {
        var comment = document.createComment("wiki-renamed-link " + page_name);
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
        var html = "<a href=\"" + href + "\"" + attr + ">" + text + "</a>";
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

proto.do_table = function() {
    var result = this.prompt_for_table_dimensions();
    if (! result) return false;
    this.insert_html(this.make_table_html(result[0], result[1]));
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
        var list = $('wikiwyg_test_results');
        list.innerHTML += '<a href="#'+div.id+'">Failed '+div.id+'</a>; ';
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

