/*==============================================================================
This Wikiwyg class provides toolbar support

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

proto = new Subclass('Wikiwyg.Toolbar', 'Wikiwyg.Base');
proto.classtype = 'toolbar';

proto.config = {
    divId: null,
    imagesLocation: 'images/',
    imagesExtension: '.gif',
    selectorWidth: '100px',
    controlLayout: [
        'save', 'cancel', 'mode_selector', '/',
        // 'selector',
        'h1', 'h2', 'h3', 'h4', 'p', 'pre', '|',
        'bold', 'italic', 'underline', 'strike', '|',
        'link', 'hr', '|',
        'ordered', 'unordered', '|',
        'indent', 'outdent', '|',
        'table', '|',
        'help'
    ],
    styleSelector: [
        'label', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'pre'
    ],
    controlLabels: {
        save: 'Save',
        cancel: 'Cancel',
        bold: 'Bold (Ctrl+b)',
        italic: 'Italic (Ctrl+i)',
        underline: 'Underline (Ctrl+u)',
        strike: 'Strike Through (Ctrl+d)',
        hr: 'Horizontal Rule',
        ordered: 'Numbered List',
        unordered: 'Bulleted List',
        indent: 'More Indented',
        outdent: 'Less Indented',
        help: 'About Wikiwyg',
        label: '[Style]',
        p: 'Normal Text',
        pre: 'Preformatted',
        h1: 'Heading 1',
        h2: 'Heading 2',
        h3: 'Heading 3',
        h4: 'Heading 4',
        h5: 'Heading 5',
        h6: 'Heading 6',
        link: 'Create Link',
        unlink: 'Remove Linkedness',
        table: 'Create Table'
    }
};

proto.initializeObject = function() {
    this.div = document.getElementById("wikiwyg_toolbar");
    this.button_container = this.div;

    var self = this;
    $("img.wikiwyg_button", this.div).bind("click", function(e) {
        var action = $(this).attr("id").replace(/^wikiwyg_button_/, '');
        self.wikiwyg.current_mode.process_command(action);
    });
}

proto.enableThis = function() {
    this.button_container.style.display = 'block';
}

proto.disableThis = function() {
    this.button_container.style.display = 'none';
}

proto.setup_widgets_pulldown = function(title) {
    var widgets_list = Wikiwyg.Widgets.widgets;
    var widget_data = Wikiwyg.Widgets.widget;

    var tb = eval(this.classname).prototype;

    tb.styleSelector = [ 'label' ];
    for (var i = 0; i < widgets_list.length; i++) {
        var widget = widgets_list[i];
        if (! widget_data[widget].hide_in_menu) {
            tb.styleSelector.push('widget_' + widget);
        }
    }
    tb.controlLayout.push('selector');

    tb.controlLabels.label = title;
    for (var i = 0; i < widgets_list.length; i++) {
        var widget = widgets_list[i];
        if (! widget_data[widget].hide_in_menu) {
            tb.controlLabels['widget_' + widget] = widget_data[widget].label;
        }
    }
}

proto.set_style = function(style_name) {
    var idx = this.styleSelect.selectedIndex;
    // First one is always a label
    if (idx != 0)
        this.wikiwyg.current_mode.process_command(style_name);
    this.styleSelect.selectedIndex = 0;
}

proto.imagesExtension = '.png';

proto.controlLayout = [
    '{other_buttons',
    'bold', 'italic', 'strike', '|',
    'h1', 'h2', 'h3', 'h4', 'p', '|',
    'ordered', 'unordered', 'outdent', 'indent', '|',
    'link', 'image', '|', 'table', 'table-settings', '|',
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
    'table-settings': loc('Table Settings'),
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

proto.setup_widgets = function() {
    this.setup_widgets_menu(loc('Insert'));
}

proto.setup_widgets_menu = function(title) {
    jQuery("#st-editing-insert-menu > li")
        .find("li:has('ul') > a")
        .addClass('daddy');
    if (jQuery.browser.msie) {
        jQuery("#st-editing-insert-menu li")
            .hover(
                function () { jQuery(this).addClass('sfhover') }, 
                function () { jQuery(this).removeClass('sfhover') }
            );
    }

    var self = this;
    if (jQuery.browser.msie) {
        jQuery("#st-editing-insert-menu > li > ul a").mouseover(function(){
            if (self.wikiwyg.current_mode.get_editable_div) {
                self._currentModeHadFocus = wikiwyg.current_mode._hasFocus;
            }
        });
    }
    jQuery("#st-editing-insert-menu > li > ul a, #st-editing-insert-menu > li > ul > li > ul > li > a").click(
        function(e) {
            var action = jQuery(this).attr("do");
            if (action == null) {
                return false;
            }

            if (jQuery.isFunction( self.wikiwyg.current_mode[action] ) ) {
                if (jQuery.browser.msie &&
                    self.wikiwyg.current_mode.get_editable_div
                ) {
                    if (!self._currentModeHadFocus) {
                        self.wikiwyg.current_mode.set_focus();
                    }
                }

                self.wikiwyg.current_mode[action]
                    .apply(self.wikiwyg.current_mode);

                self.focus_link_menu(action, e.target.innerHTML)

                return false;
            }

            var self2 = this;
            setTimeout(function() {
                alert("'" +
                    jQuery(self2).text() +
                    "' is not supported in this mode"
                );
            }, 50);
            return false;
        }
    );
}

proto.focus_link_menu = function(action, label) {
    if (! (
        action.match(/^do_widget_link2/)
        &&
        label.match(/^(Wiki|Web|Section)/)
    )) return;

    type = RegExp.$1.toLowerCase();
    jQuery("#add-" + type + "-link")
        .attr("checked", "checked");
    jQuery("#add-" + type + "-link-section")
        .find('input[type="text"]:eq(0)').focus().end()
        .find('input[type="text"][value]:eq(0)').focus().select();
}
