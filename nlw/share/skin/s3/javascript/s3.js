
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

(function ($) {
Page = {
    attachmentList: [],
    newAttachmentList: [],

    active_page_exists: function (page_name) {
        page_name = trim(page_name);
        var data = jQuery.ajax({
            url: Page.pageUrl(page_name),
            async: false
        });
        return data.status == '200';
    },

    restApiUri: function (page_name) {
        return Page.pageUrl(page_name);
    },

    pageUrl: function (page_name) {
        if (!page_name) page_name = Socialtext.page_id;
        return '/data/workspaces/' + Socialtext.wiki_id +
               '/pages/' + page_name;
    },

    cgiUrl: function () {
        return '/' + Socialtext.wiki_id + '/index.cgi';
    },

    refreshPageContent: function (force_update) {
        $.ajax({
            url: this.pageUrl(),
            cache: false,
            dataType: 'json',
            success: function (data) {
                var newRev = data.revision_id;
                var oldRev = Socialtext.revision_id;
                if ((oldRev < newRev) || force_update) {
                    Socialtext.wikiwyg_variables.page.revision_id =
                        Socialtext.revision_id = newRev;

                    // By this time, the "edit_wikiwyg" Jemplate had already
                    // finished rendering, so we need to reach into the
                    // bootstrapped input form and update the revision ID
                    // there, otherwise we'll get a bogus editing contention.
                    $('#st-page-editing-revisionid').val(newRev);
                    $('#st-rewind-revision-count').html(newRev);

                    // After upload, refresh the wysiwyg and page contents.
                    $.ajax({
                        url: Page.pageUrl(),
                        cache: false,
                        dataType: 'html',
                        success: function (html) {
                            $('#st-page-content').html(html);
                            var iframe = $('iframe#st-page-editing-wysiwyg').get(0);
                            if (iframe && iframe.contentWindow) {
                                iframe.contentWindow.document.body.innerHTML = html;
                            }
                        }
                    });

                    // After upload, refresh the wikitext contents.
                    $.ajax({
                        url: Page.pageUrl(),
                        cache: false,
                        dataType: 'text',
                        beforeSend: function (xhr) {
                            xhr.setRequestHeader('Accept', 'text/x.socialtext-wiki');
                        },
                        success: function (text) {
                            $('#wikiwyg_wikitext_textarea').val(text);
                        }
                    });
                }
            } 
        });
    },

    tagUrl: function (tag) {
        return this.pageUrl() + '/tags/' + encodeURIComponent(tag);
    },

    attachmentUrl: function (attach_id) {
        return '/data/workspaces/' + Socialtext.wiki_id +
               '/attachments/' + Socialtext.page_id + ':' + attach_id
    },

    refreshTags: function () {
        var tag_url = '?action=category_display;category=';
        $.ajax({
            url: this.pageUrl() + '/tags',
            cache: false,
            dataType: 'json',
            success: function (tags) {
                $('#st-tags-listing').html('');
                for (var i=0; i< tags.length; i++) {
                    var tag = tags[i];
                    $('#st-tags-listing').append(
                        $('<li>').append(
                            $('<a>')
                                .html(tag.name)
                                .attr('href', tag_url + tag.name),

                            ' ',
                            $('<a href="#">')
                                .html('<img src="/static/skin/common/images/delete.png" width="16" height="16" border="0" />')
                                .attr('name', tag.name)
                                .attr('alt', loc('Delete this tag'))
                                .attr('title', loc('Delete this tag'))
                                .bind('click', function () {
                                    Page.delTag(this.name);
                                })
                        )
                    )
                }
                if (tags.length == 0) {
                    $('#st-tags-listing').append( 
                        $('<div id="st-no-tags-placeholder" />')
                            .html(loc('There are no tags for this page.'))
                    );
                }
            }
        });
    },

    _format_bytes: function(filesize) {
        var n = 0;
        var unit = '';
        if (filesize < 1024) {
            unit = '';
            n = filesize;
        } else if (filesize < 1024*1024) {
            unit = 'K';
            n = filesize/1024;
            if (n < 10)
                n = n.toPrecision(2);
            else
                n = n.toPrecision(3);
        } else {
            unit = 'M';
            n = filesize/(1024*1024);
            if (n < 10) {
                n = n.toPrecision(2);
            } else if ( n < 1000) {
                n = n.toPrecision(3);
            } else {
                n = n.toFixed(0);
            }
        }
        return n + unit;
    },

    refreshAttachments: function (cb) {
        Page.attachmentList = [];
        $.ajax({
            url: this.pageUrl() + '/attachments',
            cache: false,
            dataType: 'json',
            success: function (list) {
                $('#st-attachment-listing').html('');
                for (var i=0; i< list.length; i++) {
                    var item = list[i];
                    Page.attachmentList.push(item.name);
                    var extractLink = '';
                    if (item.name.match(/\.(zip|tar|tar.gz|tgz)$/)) {
                        var attach_id = item.id;
                        extractLink = $('<a href="#">')
                            .html('<img src="/static/skin/common/images/extract.png" width="16" height="16" border="0" />')
                            .attr('name', item.uri)
                            .attr('alt', loc('Extract this attachment'))
                            .attr('title', loc('Extract this attachment'))
                            .bind('click', function () {
                                Page.extractAttachment(attach_id);
                            });
                    }
                    $('#st-attachment-listing').append(
                        $('<li>').append(
                            $('<a>')
                                .html(item.name)
                                .attr('title', loc("Uploaded by [_1] on [_2]. ([_3] bytes)", item.uploader, item.date, Page._format_bytes(item['content-length'])))
                                .attr('href', item.uri),
                            ' ',
                            extractLink,
                            ' ',
                            $('<a href="#">')
                                .html('<img src="/static/skin/common/images/delete.png" width="16" height="16" border="0" />')
                                .attr('name', item.uri)
                                .attr('alt', loc('Delete this attachment'))
                                .attr('title', loc('Delete this attachment'))
                                .bind('click', function () {
                                    Page.delAttachment(this.name)
                                })
                        )
                    )
                }
                if (cb) cb(list);
            }
        });
    },

    delTag: function (tag) {
        $.ajax({
            type: "DELETE",
            url: this.tagUrl(tag),
            complete: function () {
                Page.refreshTags();
            }
        });
    },

    extractAttachment: function (attach_id) {
        $.ajax({
            type: "POST",
            url: location.pathname,
            cache: false,
            data: {
                action: 'attachments_extract',
                page_id: Socialtext.page_id,
                attachment_id: attach_id
            },
            complete: function () {
                Page.refreshAttachments();
                Page.refreshPageContent();
            }
        });
    },

    delAttachment: function (url) {
        $.ajax({
            type: "DELETE",
            url: url,
            complete: function () {
                Page.refreshAttachments();
                Page.refreshPageContent();
            }
        });
    },

    addTag: function (tag) {
        $.ajax({
            type: "PUT",
            url: this.tagUrl(tag),
            complete: function () {
                Page.refreshTags();
                $('#st-tags-field').val('');
            }
        });
    }
};

var push_onload_function = function (fcn) { jQuery(fcn) }

$(function() {
    $('#st-page-boxes-toggle-link')
        .bind('click', function() {
            $('#st-page-boxes').toggle();
            var hidden = $('#st-page-boxes').is(':hidden');
            this.innerHTML = hidden ? 'show' : 'hide';
            Cookie.set('st-page-accessories', hidden ? 'hide' : 'show');
        });

    $('#st-tags-addlink')
        .bind('click', function () {
            $(this).hide();
            $('#st-tags-field')
                .val('')
                .show()
                .focus();
        })

    $('#st-tags-field')
        .blur(function () {
            setTimeout(function () {
                $('#st-tags-field').hide();
                $('#st-tags-addlink').show()
            }, 500);
        })
        .lookahead({
            url: '/data/workspaces/' + Socialtext.wiki_id + '/tags',
            linkText: function (i) {
                return [i.name, i.name];
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

            $('#st-attachments-attach-uploadmessage').html(
                loc('Uploading [_1]...', filename.match(/[^\\\/]+$/))
            );

            $('#st-attachments-attach-formtarget')
                .unbind('load')
                .bind('load', function () {
                    $('#st-attachments-attach-uploadmessage').html(
                        loc('Upload Complete')
                    );
                    $('#st-attachments-attach-filename').attr(
                        'disabled', false
                    );
                    $('#st-attachments-attach-closebutton').attr(
                        'disabled', false
                    );
                    Page.refreshAttachments(function (list) {
                        // Add the freshly-uploaded file to the
                        // newAttachmentList queue.
                        for (var i=0; i< list.length; i++) {
                            var item = list[i];
                            if (filename == item.name) {
                                Page.newAttachmentList.push(item.uri);
                            }
                        }

                        $('#st-attachments-attach-list')
                            .show()
                            .html('')
                            .append(
                                $('<span>')
                                    .attr(
                                        'class',
                                        'st-attachments-attach-listlabel'
                                    )
                                    .html(
                                        loc('Uploaded files:') + 
                                        Page.attachmentList.join(', ')
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

    $("#st-comment-button-link").click(function () {
        get_lightbox(function () {
            var ge = new GuiEdit({
                oncomplete: function () {
                    Page.refreshPageContent()
                }
            });
            ge.show();
        });
        return false;
    });

    $(".weblog_comment").click(function () {
        var page_id = this.id.replace(/^comment_/,'');
        get_lightbox(function () {
            var ge = new GuiEdit({
                page_id: page_id,
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
    });


    $("#st-pagetools-delete").click(function () {
        if (confirm(loc("Are you sure you want to delete this page?"))) {
            var page = Socialtext.page_id;
            document.location = "index.cgi?action=delete_page;page_name=" + page;
        }
        return false;
    });

    $("#st-edit-button-link,#st-edit-actions-below-fold-edit")
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
                $('<link>')
                    .attr('href', nlw_make_s3_path('/css/wikiwyg.css'))
                    .attr('rel', 'stylesheet')
                    .attr('media', 'wikiwyg')
                    .attr('type', 'text/css')
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

    $('#st-pagetools-newspreadsheet')
        .one("click", function () {
            $('#bootstrap-loader').show();
            $.ajaxSettings.cache = true;
            $.getScript(socialcalc_uri, function () {
                jQuery("#st-all-footers, #st-display-mode-container").hide();
                jQuery("#st-edit-mode-container, #st-editing-tools-edit").show();
                Socialtext.render_spreadsheet_editor();
            });
            $.ajaxSettings.cache = false;
        });

    $('#st-listview-submit-pdfexport').click(function() {
        if (!$('.st-listview-selectpage-checkbox:checked').size()) {
            alert(loc("You must check at least one page in order to create a PDF."));
        }
        else {
            $('#st-listview-action').val('pdf_export')
            $('#st-listview-filename').val(Socialtext.wiki_id + '.pdf');
            $('#st-listview-form').submit();
        }
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
    });

    $('#st-listview-selectall').click(function () {
        $('input[type=checkbox]').attr('checked', this.checked);
    });

    $('#st-watchlist-indicator').click(function () {
        var self = this;
        if ($(this).hasClass('on')) {
            $.get(
                location.pathname + '?action=remove_from_watchlist'+
                ';page=' + Socialtext.page_id +
                ';_=' + (new Date()).getTime(),
                function () {
                    $(self).attr('title', loc('Watch this page'));
                    $(this).removeClass('on');
                }
            );
        }
        else {
            $.get(
                location.pathname + '?action=add_to_watchlist'+
                ';page=' + Socialtext.page_id +
                ';_=' + (new Date()).getTime(),
                function () {
                    $(self).attr('title', loc('Stop watching this page'));
                    $(this).addClass('on');
                }
            );
        }
    });

    if (Socialtext.new_page ||
        Socialtext.start_in_edit_mode ||
        location.hash.toLowerCase() == '#edit' ) {
        setTimeout(function() {
            $("#st-edit-button-link").click();
        }, 500);
    }
});

})(jQuery);
