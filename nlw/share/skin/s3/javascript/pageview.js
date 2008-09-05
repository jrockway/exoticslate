(function ($) {

Page = {
    active_page_exists: function (page_name) {
        page_name = trim(page_name);
        var data = jQuery.ajax({
            url: Page.pageUrl(page_name),
            async: false
        });
        return data.status == '200';
    },

    restApiUri: function () {
        return Page.pageUrl.apply(this, arguments);
    },

    workspaceUrl: function (wiki_id) {
        return '/data/workspaces/' + (wiki_id || Socialtext.wiki_id);
    },

    pageUrl: function () {
        var args = $.makeArray(arguments);
        var page_name = args.pop() || Socialtext.page_id;
        var wiki_id = args.pop() || Socialtext.wiki_id;
        return Page.workspaceUrl(wiki_id) + '/pages/' + page_name;
    },

    cgiUrl: function () {
        return '/' + Socialtext.wiki_id + '/index.cgi';
    },

    setPageContent: function(html) {
        $('#st-page-content').html(html);

        var iframe = $('iframe#st-page-editing-wysiwyg').get(0);
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.document.body.innerHTML = html;
        }

        $('#st-page-content').html(html);

        // For MSIE, force browser reflow of the bottom buttons to avoid {bz: 966}.
        if ($.browser.msie) {
            var repaintBottomButtons = function () {
                $('#bottomButtons').html($('#bottomButtons').html());
            };
            repaintBottomButtons();

            // Repaint after each image finishes loading since the height
            // would've been changed.
            $('#st-page-content img').load(repaintBottomButtons);
        }
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
                        success: Page.setPageContent
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
                        $('<li />').append(
                            $('<a />')
                                .html(tag.name)
                                .attr('href', tag_url + tag.name),

                            ' ',
                            $('<a href="#" />')
                                .html('<img src="/static/skin/common/images/delete.png" width="16" height="16" border="0" />')
                                .attr('name', tag.name)
                                .attr('alt', loc('Delete this tag'))
                                .attr('title', loc('Delete this tag'))
                                .bind('click', function () {
                                    Page.delTag(this.name);
                                    return false;
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

    delTag: function (tag) {
        $.ajax({
            type: "DELETE",
            url: this.tagUrl(tag),
            complete: function () {
                Page.refreshTags();
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

})(jQuery);
