Socialtext.S3 = true;

function trim(value) {
    var ltrim = /\s*((\s*\S+)*)/;
    var rtrim = /((\s*\S+)*)\s*/;
    return value.replace(rtrim, "$1").replace(ltrim, "$1");
};

function is_reserved_pagename(pagename) {
    if (pagename && pagename.length > 0) {
        var name = nlw_name_to_id(trim(pagename));
        var untitled = nlw_name_to_id(loc('Untitled Page'))
        return name == untitled;
    }
    else {
        return false;
    }
}

function nlw_name_to_id(name) {
    if (name == '')
        return '';
    return encodeURI(
        name.replace(/[^A-Za-z0-9_+]/g, '_') /* For Safari, the similar regex below doesn't work in Safari */
            .replace(/[^A-Za-z0-9_+\u00C0-\u00FF]/g, '_')
            .replace(/_+/g, '_')
            .replace(/^_*(.*?)_*$/g, '$1')
            .replace(/^0$/, '_')
            .replace(/^$/, '_')
            .toLocaleLowerCase()
    );
}

push_onload_function = function (fcn) { jQuery(fcn) }

$(function() {
    $('#st-page-boxes-toggle-link')
        .bind('click', function() {
            var hidden = $('#contentColumns').hasClass('hidebox');
            if (hidden)
                $('#contentColumns').removeClass("hidebox").addClass("showbox");
            else
                $('#contentColumns').removeClass("showbox").addClass("hidebox");
            hidden = !hidden;
            this.innerHTML = hidden ? 'show' : 'hide';
            Cookie.set('st-page-accessories', hidden ? 'hide' : 'show');

            // Because the content area's height might have changed, repaint
            // the Edit/Comment buttons at the bottom for IE.
            Page._repaintBottomButtons();

            return false;
        });

    $('#st-tags-addlink')
        .bind('click', function () {
            $(this).hide();
            $('#st-tags-addbutton-link').show();
            $('#st-tags-field')
                .val('')
                .show()
                .focus();
            return false;
        })

    $('#st-tags-field')
        .blur(function () {
            setTimeout(function () {
                $('#st-tags-field').hide();
                $('#st-tags-addbutton-link').hide();
                $('#st-tags-addlink').show()
            }, 500);
        })
        .lookahead({
            url: Page.workspaceUrl() + '/tags',
            exceptUrl: Page.pageUrl() + '/tags',
            linkText: function (i) {
                return i.name
            },
            onAccept: function (val) {
                Page.addTag(val);
            }
        });
            

    $('#st-tags-form')
        .bind('submit', function () {
            var tag = $('#st-tags-field').val();
            Page.addTag(tag);
            return false;
        });

    $('#st-attachments-uploadbutton').unbind('click').click(function () {
        $('#st-attachments-attach-list').html('').hide();
        $.showLightbox({
            content:'#st-attachments-attachinterface',
            close:'#st-attachments-attach-closebutton'
        });
        return false;
    });

    $('#st-attachments-attach-filename')
        .val('')
        .bind('change', function () {
            var filename = $(this).val();
            if (!filename) {
                $('#st-attachments-attach-uploadmessage').html(
                    loc("Please click browse and select a file to upload.")
                );
                return false;
            }

            var filename = filename.replace(/^.*\\|\/:/, '');

            if (encodeURIComponent(filename).length > 255 ) {
                $('#st-attachments-attach-uploadmessage').html(
                    loc("Filename is too long after URL encoding.")
                );
                return false;
            }

            var basename = filename.match(/[^\\\/]+$/);

            $('#st-attachments-attach-uploadmessage').html(
                loc('Uploading [_1]...', basename)
            );

            $('#st-attachments-attach-formtarget')
                .one('load', function () {
                    $('#st-attachments-attach-uploadmessage').html(
                        loc('Upload Complete')
                    );
                    $('#st-attachments-attach-filename').attr(
                        'disabled', false
                    );
                    $('#st-attachments-attach-closebutton').attr(
                        'disabled', false
                    );

                    Attachments.refreshAttachments(function (list) {
                        // Add the freshly-uploaded file to the
                        // newAttachmentList queue.

                        for (var i=0; i< list.length; i++) {
                            var item = list[i];

                            // Compare basename, because FF2 would use the
                            // full pathname but item.name is basename-only.
                            if (basename == item.name) {
                                Attachments.addNewAttachment(item);
                            }
                        }

                        $('#st-attachments-attach-list')
                            .show()
                            .html('')
                            .append(
                                $('<span />')
                                    .attr(
                                        'class',
                                        'st-attachments-attach-listlabel'
                                    )
                                    .html(
                                        loc('Uploaded files:') + 
                                        '&nbsp;' +
                                        Attachments.attachmentList()
                                    )
                            );
                    });
                    Page.refreshPageContent();
                });

            $('#st-attachments-attach-form').submit();
            $('#st-attachments-attach-closebutton').attr('disabled', true);
            $(this).attr('disabled', true);

            return false;
        });


    var editor_uri = nlw_make_s3_path('/javascript/socialtext-editor.js.gz')
        .replace(/(\d+\.\d+\.\d+\.\d+)/,'$1.'+Socialtext.make_time);

    var lightbox_uri = nlw_make_s3_path('/javascript/socialtext-lightbox.js.gz')
        .replace(/(\d+\.\d+\.\d+\.\d+)/,'$1.'+Socialtext.make_time);

    var socialcalc_uri = nlw_make_plugin_path("/socialcalc/javascript/socialtext-socialcalc.js.gz")
            .replace(/(\d+\.\d+\.\d+\.\d+)/, '$1.' + Socialtext.make_time);

    function get_lightbox (cb) {
        $.ajaxSettings.cache = true;
        $.getScript(lightbox_uri, cb);
        $.ajaxSettings.cache = false;
    }

    $("#st-comment-button-link, #bottomButtons .commentButton")
        .click(function () {
            if ($('div.commentWrapper').length) {
                Page._currentGuiEdit.scrollTo();
                return;
            }

            get_lightbox(function () {
                var ge = new GuiEdit({
                    id: 'contentLeft',
                    oncomplete: function () {
                        Page.refreshPageContent();
                    },
                    onclose: function () {
                        Page._repaintBottomButtons();
                    }
                });
                Page._currentGuiEdit = ge;
                ge.show();
            });
            Page._repaintBottomButtons();
            return false;
        });

    $(".weblog_comment").click(function () {
        var page_id = this.id.replace(/^comment_/,'');
        get_lightbox(function () {
            var ge = new GuiEdit({
                page_id: page_id,
                id: 'content_'+page_id,
                oncomplete: function () {
                    $.get(Page.pageUrl(page_id), function (html) {
                        $('#content_'+page_id).html(html);
                    });
                }
            });
            ge.show();
        });
        return false;
    });

    $("#st-pagetools-email").click(function () {
        get_lightbox(function () {
            var Email = new ST.Email;
            Email.show();
        });
        return false;
    });

    //index.cgi?action=duplicate_popup;page_name=[% page.id %]
    $("#st-pagetools-duplicate").click(function () {
        get_lightbox(function () {
            var move = new ST.Move;
            move.duplicateLightbox();
        });
        return false;
    });

    $("#st-pagetools-rename").click(function () {
        get_lightbox(function () {
            var move = new ST.Move;
            move.renameLightbox();
        });
        return false;
    });

    //index.cgi?action=copy_to_workspace_popup;page_name=[% page.id %]')
    $("#st-pagetools-copy").click(function () {
        get_lightbox(function () {
            var move = new ST.Move;
            move.copyLightbox();
        });
        return false;
    });


    $("#st-pagetools-delete").click(function () {
        if (confirm(loc("Are you sure you want to delete this page?"))) {
            var page = Socialtext.page_id;
            document.location = "index.cgi?action=delete_page;page_name=" + page;
        }
        return false;
    });

    $("#st-edit-button-link,#st-edit-actions-below-fold-edit, #bottomButtons .editButton")
        .one("click", function () {
            $('#bootstrap-loader').show();
            $.ajaxSettings.cache = true;
            if (Socialtext.page_type == 'spreadsheet' && Socialtext.wikiwyg_variables.hub.current_workspace.enable_spreadsheet) {
                $.getScript(socialcalc_uri, function () {
                    jQuery("#st-all-footers, #st-display-mode-container").hide();
                    jQuery("#st-edit-mode-container, #st-editing-tools-edit").show();
                    Socialtext.render_spreadsheet_editor();
                });
            }
            else {
                $.getScript(editor_uri);
                var lnk = $('link[rel=stylesheet][media=screen]');
                lnk.clone()
                    .attr('href', nlw_make_s3_path('/css/wikiwyg.css'))
                    .attr('media', 'wikiwyg')
                    .appendTo('head');
            }
            $.ajaxSettings.cache = false;
            return false;
        });

    if (Socialtext.double_click_to_edit) {
        var double_clicker = function() {
            jQuery("#st-edit-button-link").click();
        };
        jQuery("#st-page-content").one("dblclick", double_clicker);
    }

    $('#st-listview-submit-pdfexport').click(function() {
        if (!$('.st-listview-selectpage-checkbox:checked').size()) {
            alert(loc("You must check at least one page in order to create a PDF."));
        }
        else {
            $('#st-listview-action').val('pdf_export')
            $('#st-listview-filename').val(Socialtext.wiki_id + '.pdf');
            $('#st-listview-form').submit();
        }
        return false;
    });

    $('#st-listview-submit-rtfexport').click(function() {
        if (!$('.st-listview-selectpage-checkbox:checked').size()) {
            alert(loc("You must check at least one page in order to create a Word document."));
        }
        else {
            $('#st-listview-action').val('rtf_export')
            $('#st-listview-filename').val(Socialtext.wiki_id + '.rtf');
            $('#st-listview-form').submit();
        }
        return false;
    });

    $('#st-listview-selectall').click(function () {
        $('input[type=checkbox]').attr('checked', this.checked);
        return false;
    });

    $('input[name=homepage_is_weblog]').click(function () {
        $('input[name=homepage_weblog]')
            .attr('disabled', Number($(this).val()) ? false : true)
    });

    $('input[name=homepage_weblog]').lookahead({
        url: function () { return Page.workspaceUrl() + '/tags' },
        filterValue: function (val) {
            return val + '.*(We)?blog$';
        },
        linkText: function (i) { return i.name }
    });

    function makeWatchHandler (pageId) { return function(){
        var self = this;
        if ($(this).hasClass('on')) {
            $.get(
                location.pathname + '?action=remove_from_watchlist'+
                ';page=' + pageId +
                ';_=' + (new Date()).getTime(),
                function () {
                    var text = loc("Watch");
                    $(self).attr('title', text).text(text);
                    $(self).removeClass('on');
                }
            );
        }
        else {
            $.get(
                location.pathname + '?action=add_to_watchlist'+
                ';page=' + pageId +
                ';_=' + (new Date()).getTime(),
                function () {
                    var text = loc('Stop Watching');
                    $(self).attr('title', text).text(text);
                    $(self).addClass('on');
                }
            );
        }
    }; }

    // Watch handler for single-page view
    $('#st-watchlist-indicator').click(makeWatchHandler(Socialtext.page_id));

    // Watch handler for watchlist view
    $('td.listview-watchlist a[id^=st-watchlist-indicator-]').each(function(){
        $(this).click(
            makeWatchHandler(
                $(this).attr('id').replace(/^st-watchlist-indicator-/, '')
            )
        );
    });

    if (Socialtext.new_page ||
        Socialtext.start_in_edit_mode ||
        location.hash.toLowerCase() == '#edit' ) {
        setTimeout(function() {
            $("#st-edit-button-link").click();
        }, 500);
    }
});
