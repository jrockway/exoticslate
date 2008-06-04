;(function() {

if (! window.SocialCalc) return;

var current_cell_comment = function() {
    var c = "";
    if (ss.editor.ecell && ss.editor.ecell.coord && ss.sheet.cells[ss.editor.ecell.coord]) {
        c = ss.sheet.cells[ss.editor.ecell.coord].comment || "";
    }
    return c;
}

var current_spreadsheet_cell = function() {
    return ss.editor.ecell.coord;
}

var current_spreadsheet_range = function() {
    var range = ss.editor.ecell.coord;
    if (ss.editor.range.hasrange) {
        range = SocialCalc.crToCoord(ss.editor.range.left, ss.editor.range.top)+             ":"+SocialCalc.crToCoord(ss.editor.range.right, ss.editor.range.bottom);
    }
    return range; 
}

Socialtext.render_spreadsheet_editor = function() {
    jQuery("#st-edit-mode-container").remove();

    Socialtext.wikiwyg_variables.loc = loc;
    var html = Jemplate.process('edit_spreadsheet', Socialtext.wikiwyg_variables);
    var el = jQuery(html).get(0);
    var c = jQuery("#st-display-mode-container").get(0);
    c.parentNode.insertBefore(el, c.nextSibling);

    (function($) {
        var colors = [
        "#ffffff","#cccccc","#c0c0c0","#999999","#666666","#333333","#000000",
        "#ffcccc","#ff6666","#ff0000","#cc0000","#990000","#660000","#330000",
        "#ffcc99","#ff9966","#ff9900","#ff6600","#cc6600","#993300","#663300",
        "#ffff99","#ffff66","#ffcc66","#ffcc33","#cc9933","#996633","#663333",
        "#ffffcc","#ffff33","#ffff00","#ffcc00","#999900","#666600","#333300",
        "#99ff99","#66ff99","#33ff33","#33cc00","#009900","#006600","#003300",
        "#99ffff","#33ffff","#66cccc","#00cccc","#339999","#336666","#003333",
        "#ccffff","#66ffff","#33ccff","#3366ff","#3333ff","#000099","#000066",
        "#ccccff","#9999ff","#6666cc","#6633ff","#6600cc","#333399","#330099",
        "#ffccff","#ff99ff","#cc66cc","#cc33cc","#993399","#663366","#330033"
        ];
        
        jQuery.each(colors, function(i, color) {
            var html =
                '<a href="#" style="background: '+ color +';">&nbsp;</a>'
                + (i%7==6 ? "<br>":"");
            $("#st-spreadsheet-toolbar-colorpicker").append(html);
            $("#st-spreadsheet-toolbar-bgcolorpicker").append(html);
        });
        
        $("#st-spreadsheet-toolbar-colorpicker, #st-spreadsheet-toolbar-bgcolorpicker").unbind('ciick').bind("click", function(e) {
            var elem = e.target;
            if (!$(elem).is("a")) return false;

            var colorType =
                $(this).is("#st-spreadsheet-toolbar-bgcolorpicker")
                ? " bgcolor " : " color ";

            var range = current_spreadsheet_range();

            ss.sheet.ExecuteSheetCommand("set " + range + colorType + $(elem).css("background-color"), true);
            ss.FullRefreshAndRender();

            $(this).hide();
            return false;
        });

        $("a#st-color-button-link").bind("click", function() {
            $("#st-spreadsheet-toolbar-colorpicker")
            .toggle().css( $(this).offset() );
        });
        $("a#st-bgcolor-button-link").bind("click", function() {
            $("#st-spreadsheet-toolbar-bgcolorpicker")
            .toggle().css( $(this).offset() );
        });

    })(jQuery);

    var $drawer = jQuery("#st-spreadsheet-toolbar-drawer");
    var refresh_range_names_list = function() {
        jQuery("#st-spreadsheet-name-tools input[type='text']").val("");
        jQuery("#st-spreadsheet-range-names option:gt(0)").remove();
        jQuery.each(ss.sheet.names, function(key, val) {
            jQuery("#st-spreadsheet-range-names").append(
                "<option>" + key + "</option>"
            );
        });
    };

    jQuery("input#st-spreadsheet-range-delete").bind("click", function() {
        var name = jQuery("#st-spreadsheet-range-names").val();
        ss.ExecuteCommand("name delete "+name);
        refresh_range_names_list();
        jQuery(this).hide();
        jQuery("#st-spreadsheet-range-value").val(
            current_spreadsheet_range()
        );
        jQuery("#st-spreadsheet-range-name").focus().click();
        return false;
    });

    jQuery("#st-spreadsheet-range-cancel").bind("click", function() {
        slideUp($drawer, "name");
        return false;
    });

    jQuery("input#st-spreadsheet-clipboard-paste").bind("click", function() {
        var content = jQuery("#st-spreadsheet-clipboard-tools textarea").val();

        if (content.length > 0) {
            var cmd =
                "loadclipboard "+
                SocialCalc.encodeForSave(SocialCalc.ConvertOtherFormatToSave(content, "tab"));

            ss.sheet.ExecuteSheetCommand(cmd, false);
            cmd ="paste " + current_spreadsheet_cell() + " all";
            ss.sheet.ExecuteSheetCommand(cmd, true);
            ss.FullRefreshAndRender();
        }

        slideUp($drawer, "clipboard");
        return false;
    });

    jQuery("input#st-spreadsheet-clipboard-clear").bind("click", function() {
         $drawer.find("textarea#st-spreadsheet-clipboard-input").val('').focus().click();
         return false;
    });

    jQuery("input#st-spreadsheet-clipboard-cancel").bind("click", function() {
         slideUp($drawer, "clipboard");
         return false;
    });

    var slideDown = function($drawer, type) {
        $drawer.slideDown();
        SocialCalc.Keyboard.passThru =
            SocialCalc.EditorMouseInfo.ignore =
            true;

        if (type == 'comment') {
            jQuery("#st-spreadsheet-comment-tools textarea").val( current_cell_comment() );
            jQuery("#st-spreadsheet-comment-input").focus().click();
            setTimeout(function() {
                jQuery("#st-spreadsheet-comment-input").focus().click();
            }, 1000);
        }

        if (type == 'name') {
            refresh_range_names_list();
            jQuery("#st-spreadsheet-range-names").bind("change", function() {
                var name = jQuery(this).val();
                var named = ss.sheet.names[ name ] || {};
                var value = named.definition || current_spreadsheet_range();
                var desc = named.desc || "";
                if (named.definition) {
                    $drawer.find("input#st-spreadsheet-range-delete").show();
                }
                else {
                    $drawer.find("input#st-spreadsheet-range-delete").hide();
                    name = "";
                }

                $drawer
                .find("input#st-spreadsheet-range-name").val(name).end()
                .find("input#st-spreadsheet-range-value").val(value).end()
                .find("input#st-spreadsheet-range-description").val(desc).end();
            });
            $drawer.find("input#st-spreadsheet-range-value").val(
                current_spreadsheet_range()
            );
            jQuery("#st-spreadsheet-range-name").focus().click();
            setTimeout(function() {
                jQuery("#st-spreadsheet-range-name").focus().click();
            }, 1000);
        }
        if (type == 'clipboard') {
            jQuery("#st-spreadsheet-clipboard-tools textarea").val('');
            jQuery("#st-spreadsheet-clipboard-input").focus().click();
            setTimeout(function() {
                jQuery("#st-spreadsheet-clipboard-input").focus().click();
            }, 1000);
        }

        if (type == 'sort') {
            var $majorsort = jQuery("#st-spreadsheet-sort-major-columns").empty();
            var $minorsort = jQuery("#st-spreadsheet-sort-minor-columns").empty();
            var $lastsort = jQuery("#st-spreadsheet-sort-last-columns").empty();

            var $majorsortdir = jQuery("#st-spreadsheet-sort-major-direction");
            var $minorsortdir = jQuery("#st-spreadsheet-sort-minor-direction");
            var $lastsortdir = jQuery("#st-spreadsheet-sort-last-direction");

            $minorsort.append("<option>(none)</option>");
            $lastsort.append("<option>(none)</option>");

           var range = SocialCalc.ParseRange( current_spreadsheet_range() );
            for (var col=range.cr1.col; col<=range.cr2.col; col++) {
                var colname = SocialCalc.rcColname(col);
                $majorsort.append("<option>" + colname + "</option>");
                $minorsort.append("<option>" + colname + "</option>");
                $lastsort.append("<option>" + colname + "</option>");
            }

            var sorter = function () {
                var cmd = "sort " 
                + current_spreadsheet_range()
                + " " + $majorsort.val()
                + " " + $majorsortdir.val();

                if ($minorsort.val()) {
                    cmd += " " + $minorsort.val() + " " + $minorsortdir.val();
                }
                if ($lastsort.val()) {
                    cmd += " " + $lastsort.val() + " " + $lastsortdir.val();
                }

                ss.sheet.ExecuteSheetCommand(cmd, true);
                ss.FullRefreshAndRender();
            };

            $majorsortdir.unbind().bind("change", sorter);
            $majorsort.unbind().bind("change", sorter);
            $minorsortdir.unbind().bind("change", sorter);
            $minorsort.unbind().bind("change", sorter);
            $lastsortdir.unbind().bind("change", sorter);
            $lastsort.unbind().bind("change", sorter);
        }
    };

    var slideUp = function($drawer, type) {
        $drawer.slideUp();
        SocialCalc.Keyboard.passThru =
            SocialCalc.EditorMouseInfo.ignore =
            null;
    };

    jQuery("#st-spreadsheet-range-save").bind("click", function() {
        var name = $drawer.find("input#st-spreadsheet-range-name").val()
            .replace(/^\s+/, '')
            .replace(/\s+$/, '')
            .replace(/\s+/g, '_');
        if (name.length == 0) return;

        var desc = $drawer.find("input#st-spreadsheet-range-description")
            .val()
            .replace(/^\s+/, '')
            .replace(/\s+$/, '')
            .replace(/\s+/g, ' ');
        var range = $drawer.find("input#st-spreadsheet-range-value").val()
            .replace(/\s+/g, '');

        ss.ExecuteCommand(
            "name define "+name+" "+ range + "\n"+
            "name desc "+name+" "+desc
        );

        slideUp($drawer, "name");

        return false;
    });

    jQuery("#st-spreadsheet-comment-save").bind("click", function() {
        var cmd = "set " + current_spreadsheet_cell() + " comment " + SocialCalc.encodeForSave( jQuery("#st-spreadsheet-comment-tools textarea").val() );

        ss.sheet.ExecuteSheetCommand(
            cmd,
            true
        );
        slideUp($drawer, "comment");
        return false;
    });

    jQuery("input#st-spreadsheet-comment-clear").bind("click", function() {
         jQuery("#st-spreadsheet-comment-input").val('').focus().click();
         return false;
    });

    jQuery("#st-spreadsheet-comment-cancel").bind("click", function() {
        slideUp($drawer, "comment");
        return false;
    });

    jQuery(".st-drawer-button-link").bind("click", function() {
        var prevtype = '';
        jQuery(".st-spreadsheet-drawer:visible").each(function() {
            prevtype = this.id.replace(/.*-(name|sort|comment|clipboard|cell-settings|sheet-settings)-.*/, '$1')
        });
        var type = this.id.replace(/.*-(name|sort|comment|clipboard|cell-settings|sheet-settings)-.*/, '$1');
        jQuery(".st-spreadsheet-drawer")
            .not('#st-spreadsheet-' + type + '-tools')
            .hide();
        jQuery('#st-spreadsheet-' + type + '-tools').show();
        $drawer.width($drawer.parent().width() - 5);
        if ($drawer.is(':hidden')) {
            slideDown($drawer, type);
        }
        else {
            slideUp($drawer, prevtype);
            if (type != prevtype) {
                slideDown($drawer, type);
            }
        }
        return false;
    });

    jQuery("#st-redo-button-link").bind("click", function() {
        ss.sheet.SheetRedo();
        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-undo-button-link").bind("click", function() {
        ss.sheet.SheetUndo();
        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-bold-button-link").bind("click", function() {
        var range = current_spreadsheet_range();

        ss.sheet.ExecuteSheetCommand(
            "set " + range + " font normal bold * *",
            true
        );

        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-italic-button-link").bind("click", function() {
        var range = current_spreadsheet_range();

        ss.sheet.ExecuteSheetCommand(
            "set " + range + " font italic normal * *",
            true
        );

        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-left-button-link").bind("click", function() {
        var range = current_spreadsheet_range();

        ss.sheet.ExecuteSheetCommand(
            "set " + range + " cellformat left",
            true
        );

        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-center-button-link").bind("click", function() {
        var range = current_spreadsheet_range();

        ss.sheet.ExecuteSheetCommand(
            "set " + range + " cellformat center",
            true
        );

        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-right-button-link").bind("click", function() {
        var range = current_spreadsheet_range();

        ss.sheet.ExecuteSheetCommand(
            "set " + range + " cellformat right",
            true
        );

        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-erase-button-link").bind("click", function() {
        var range = current_spreadsheet_range();

        ss.sheet.ExecuteSheetCommand(
            "erase " + range + " all",
            true
        );

        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-cut-button-link").bind("click", function() {
        var range = current_spreadsheet_range();

        ss.sheet.ExecuteSheetCommand(
            "cut " + range + " all",
            true
        );

        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-copy-button-link").bind("click", function() {
        var range = current_spreadsheet_range();

        ss.sheet.ExecuteSheetCommand(
            "copy " + range + " all",
            true
        );

        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-paste-button-link").bind("click", function() {
        var range = current_spreadsheet_range();

        ss.sheet.ExecuteSheetCommand(
            "paste " + range + " all",
            true
        );

        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-insert-row-button-link, #st-insert-col-button-link, #st-delete-row-button-link, #st-delete-col-button-link").bind("click", function() {

        var cmd = jQuery(this).attr("id")
            .replace(/^st-/,'').replace(/-button-link/,'')
            .replace(/-/,'') + " " + current_spreadsheet_cell();

        ss.sheet.ExecuteSheetCommand(cmd, true);
        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-filldown-button-link").bind("click", function() {
        var range = current_spreadsheet_range();

        ss.sheet.ExecuteSheetCommand(
            "filldown " + range + " all",
            true
        );

        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-fillright-button-link").bind("click", function() {
        var range = current_spreadsheet_range();

        ss.sheet.ExecuteSheetCommand(
            "fillright " + range + " all",
            true
        );

        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("select[name='cell_content']").bind("change", function(e) {
        var cmd = jQuery(this).val() ;
        var matched = null;
        if (matched = cmd.match(/border_(on|off)/)) {
            cmd = "set %C bt %S\nset %C br %S\nset %C bb %S\nset %C bl %S"
                .replace(/%C/g, current_spreadsheet_range())
                .replace(/%S/g, matched[1] == "on" ? "1px solid #000":"");
        }
        else if (cmd == 'wiki_on') {
            cmd = "set %C textvalueformat text-wiki"
                .replace(/%C/, current_spreadsheet_range());
        }
        else if ( cmd == 'wiki_off') {
            cmd = "set %C textvalueformat "
                .replace(/%C/, current_spreadsheet_range());
        }
        else {
            // merge/unmerge
            cmd += " " + current_spreadsheet_range();
        }

        ss.sheet.ExecuteSheetCommand(cmd, true);
        ss.FullRefreshAndRender();

        jQuery(this).val("");
    });

    jQuery("select#st-spreadsheet-cell-number-format").bind("change", function(e) {
        var cmd = "set %C nontextvalueformat %S"
        .replace(/%C/, current_spreadsheet_cell())
        .replace(/%S/, jQuery(this).val() );

        ss.sheet.ExecuteSheetCommand(cmd, true);
        ss.FullRefreshAndRender();

        jQuery(this).val("");
        return false;
    });

    jQuery("#st-spreadsheet-cell-settings-tools select.st-spreadsheet-calignvert")
    .bind("change", function() {
        var cmd = "set " + current_spreadsheet_range()
            + " layout padding: * * * *;"
            + "vertical-align:" + jQuery(this).val() + ";";

        ss.sheet.ExecuteSheetCommand(cmd, true);
        ss.FullRefreshAndRender();
        return false;
    });

    jQuery("#st-spreadsheet-cell-settings-tools select#SocialCalc-cfontfamily-dd")
    .bind("change", function() {
        var cmd = "set " + current_spreadsheet_range()
            + " font "
            + jQuery(this).val() + ";";

        console.log(cmd);

        ss.sheet.ExecuteSheetCommand(cmd, true);
        ss.FullRefreshAndRender();
        return false;
    });


};

window.setup_socialcalc = function() {
    if (Socialtext.new_page) {
        if ( Socialtext.page_title == 'Untitled Page' )
            Socialtext.page_title = prompt("Enter Spreadsheet Page Name", Socialtext.page_title);

        jQuery("#st-newpage-pagename-edit").val(Socialtext.page_title);
        jQuery('#st-newpage-save-pagename').val(Socialtext.page_title);
        jQuery("#st-page-editing-pagename").val(Socialtext.page_title);
    }

    jQuery("#st-spreadsheet-name")
        .text(Socialtext.page_title);

    jQuery('#st-save-button-link, #st-preview-button-link')
        .unbind()
        .each(function() { this.onclick = function() { }; });

    jQuery("#st-cancel-button-link")
        .unbind()
        .each(function() {
            this.onclick = function() { };
        })
        .bind("click", function() {
            jQuery("#st-edit-mode-container").hide();
            jQuery("#st-editing-tools-display, #st-display-mode-container, #st-all-footers").show();
            wikiwyg.disableLinkConfirmations();
        });

    jQuery("#st-save-button-link").bind("click", function() {
        var saver = function() {
            var serialization =
                ss.CreateSpreadsheetSave() +
                "\n__SPREADSHEET_HTML__\n" +
                ss.CreateSheetHTML() +
                "\n__SPREADSHEET_VALUES__\n" +
                ss.CreateCellHTMLSave() +
                "\n";
            jQuery('#st-page-editing-pagebody').val(serialization);
            jQuery('#st-page-editing-form').submit();
            return true;
        }
        saver();

        return false;
    });

    jQuery("#st-preview-mode-button-link").bind("click", function() {
        jQuery("#st-spreadsheet-edit").hide();
        jQuery("#st-spreadsheet-preview").html( ss.CreateSheetHTML() ).show();
    });

    jQuery("#st-edit-mode-button-link").bind("click", function() {
        jQuery("#st-spreadsheet-edit").show();
        jQuery("#st-spreadsheet-preview").hide();
    });

    jQuery("#st-audit-mode-button-link").bind("click", function() {
        jQuery("#st-spreadsheet-edit").hide();
        jQuery("#st-spreadsheet-preview").html( 
            "<pre style='margin:0;'>" + ss.sheet.CreateSheetSave() + "</pre>"
        ).show();
    });

    jQuery.get(
        Page.restApiUri(),
        {
            _: (new Date()).getTime(),
            accept: 'text/x.socialtext-wiki'
        },
        function(serialization) {
            serialization = serialization
                .replace(/^__SPREADSHEET_HTML__[\s\S]*/m, '');
            ss.DecodeSpreadsheetSave(serialization);
            var parts = ss.DecodeSpreadsheetSave(serialization);
            if (parts) {
                if (parts.sheet) {
                    ss.sheet.ResetSheet();
                    ss.ParseSheetSave(
                        serialization.substring(
                            parts.sheet.start,
                            parts.sheet.end
                        )
                    );
                }
                if (parts.edit) {
                    ss.editor.LoadEditorSettings(
                        serialization.substring(
                            parts.edit.start,
                            parts.edit.end
                        )
                    );
                }
            }
            ss.sheet.RecalcSheet();
            ss.FullRefreshAndRender();
        }
    );


    jQuery("#st-spreadsheet-tabs").bind("click", function(e) {
        var elem = e.target;
        var $elem = jQuery(elem);
        if ( $elem.is("a.button") ) {
            jQuery("a.button", this).removeClass("active");
            $elem.addClass("active");
        }

        var mode = $elem.attr('id')
            .replace(/^st-/,'')
            .replace(/-button-link$/,'');

        jQuery(".spreadsheet-toolbar a").hide();
        jQuery(".spreadsheet-toolbar.for-" + mode + " a").show();

        return false;
    });

};

SocialCalc.default_expand_markup = function(wikitext, sheet, style) {
    var uri = location.pathname;
    var postdata = 'action=wikiwyg_wikitext_to_html;content=' +
        encodeURIComponent(wikitext);

    var post = new Ajax.Request (
        uri,
        {
            method: 'post',
            parameters: $H({
                action: 'wikiwyg_wikitext_to_html',
                page_name: ($('st-newpage-pagename-edit') ? $('st-newpage-pagename-edit').value : $('st-page-editing-pagename').value),
                content: wikitext
            }).toQueryString(),
            asynchronous: false
        }
    );

    var html = post.transport.responseText
        .replace(/^<div class="wiki">\s*/, '')
        .replace(/^<p>\s*/, '')
        .replace(/<\/div>\s*$/, '')
        .replace(/<br\/>\s*$/, '')
        .replace(/<\/p>\s*$/, '');

    return html;
};

SocialCalc.Formula.SheetCache.loadsheet = function(sheetname) {
    var wiki_id = Page.wiki_id;
    var page_id = sheetname;
    if (page_id.match(/^([\w\-]+):/)) {
        wiki_id = RegExp.$1;
        page_id = page_id.replace(/^([\w\-]+):/, '');
    }

    page_id = page_id
        .replace(/[^a-zA-Z0-9]+/g, '_')
        .replace(/^_/, '')
        .replace(/_$/, '')
        .toLowerCase();

    var url = Page.restApiUri.call({
        "wiki_id": wiki_id,
        "page_id": page_id
    })
    + "?accept=text/x.socialtext-wiki";

    var serialization = null;
    jQuery.ajax({
        'url': url,
        'async': false,
        'success': function(response) {
            serialization = response
                .replace(/[\s\S]*?\ncell:/, 'cell:')
                .replace(/\n--SocialCalc[\s\S]*/, '\n');
        },
        'error': function() {
        }
    });

    return serialization;
};

})();

