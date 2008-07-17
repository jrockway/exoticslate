Page = {
    pageUrl: function () {
        return '/data/workspaces/' + Socialtext.wiki_id +
               '/pages/' + Socialtext.page_id;
    },

    refreshPageContent: function () {
        jQuery.get(this.pageUrl(), function (html) {
            jQuery('#st-page-content').html(html);
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
        jQuery.getJSON( this.pageUrl() + '/tags', function (tags) {
            jQuery('#st-tags-listing').html('');
            for (var i=0; i< tags.length; i++) {
                var tag = tags[i];
                jQuery('#st-tags-listing').append(
                    jQuery('<li>').append(
                        jQuery('<a>')
                            .html(tag.name)
                            .attr('href', tag_url + tag.name),
                        ' ',
                        jQuery('<a href="#">')
                            .html('[x]')
                            .attr('name', tag.name)
                            .bind('click', function () {
                                Page.delTag(this.name);
                            })
                    )
                )
            }
        });
    },

    refreshAttachments: function () {
        jQuery.getJSON( this.pageUrl() + '/attachments', function (list) {
            jQuery('#st-attachment-listing').html('');
            for (var i=0; i< list.length; i++) {
                var item = list[i];
                jQuery('#st-attachment-listing').append(
                    jQuery('<li>').append(
                        jQuery('<a>')
                            .html(item.name)
                            .attr('href', item.uri),
                        ' ',
                        jQuery('<a href="#">')
                            .html('[x]')
                            .attr('name', item.uri)
                            .bind('click', function () {
                                Page.delAttachment(this.name)
                            })
                    )
                )
            }
        });
    },

    delTag: function (tag) {
        jQuery.ajax({
            type: "DELETE",
            url: this.tagUrl(tag),
            complete: function () {
                Page.refreshTags();
            }
        });
    },

    delAttachment: function (url) {
        jQuery.ajax({
            type: "DELETE",
            url: url,
            complete: function () {
                Page.refreshAttachments();
                Page.refreshPageContent();
            }
        });
    },

    addTag: function (tag) {
        jQuery.ajax({
            type: "PUT",
            url: this.tagUrl(tag),
            complete: function () {
                Page.refreshTags();
                jQuery('#st-tags-field').val('');
            }
        });
    }
};

var load_script = function(script_url) {
    var script = jQuery("<script>").attr({
        type: 'text/javascript',
        src: script_url
    }).get(0);

    console.log('loading ' + script_url);

    if (jQuery.browser.msie)
        jQuery(script).appendTo('head');
    else
        document.getElementsByTagName('head')[0].appendChild(script);
};

var load_ui = function(cb) {
    var script_url =
        nlw_make_s3_path("/javascript/socialtext-editor.js.gz")
        .replace(/(\d+\.\d+\.\d+\.\d+)/, '$1.' + Socialtext.make_time) ;

    load_script( script_url ); 
    var self = this;
    var loader = function() {
        // Test if it's fully loaded.
        if (Socialtext.boostrap_ui_finished != true)  {
            setTimeout(arguments.callee, 500);
            return;
        }
        cb.call(self);
    }
    setTimeout(loader, 500);
};

jQuery(function() {
    jQuery('#st-page-boxes-toggle-link')
        .bind('click', function() {
            jQuery('#st-page-boxes').toggle();
            var hidden = jQuery('#st-page-boxes').is(':hidden');
            this.innerHTML = hidden ? 'show' : 'hide';
            Cookie.set('st-page-accessories', hidden ? 'hide' : 'show');
        });

    jQuery('#st-tags-addlink')
        .bind('click', function () {
            jQuery(this).hide();
            jQuery('#st-tags-field')
                .val('')
                .show()
                .trigger('focus');
        })

    jQuery('#st-tags-field')
        .bind('blur', function () {
            jQuery(this).hide();
            jQuery('#st-tags-addlink').show()
        });
            

    jQuery('#st-tags-form')
        .bind('submit', function () {
            var tag = jQuery('#st-tags-field').val();
            Page.addTag(tag);
        });

    jQuery('#st-attachments-uploadbutton')
        .lightbox({
            content:'#st-attachments-attachinterface',
            close:'#st-attachments-attach-closebutton'
        });

    jQuery('#st-attachments-attach-filename')
        .val('')
        .bind('change', function () {
            var filename = jQuery(this).val();
            if (!filename) {
                jQuery('#st-attachments-attach-uploadmessage').html(
                    loc("Please click browse and select a file to upload.")
                );
                return false;
            }

            var filename = filename.replace(/^.*\\|\/:/, '');

            if (encodeURIComponent(filename).length > 255 ) {
                jQuery('#st-attachments-attach-uploadmessage').html(
                    loc("Filename is too long after URL encoding.")
                );
                return false;
            }

            jQuery('#st-attachments-attach-uploadmessage').html(
                loc('Uploading [_1]...', filename.match(/[^\\\/]+jQuery/))
            );

            jQuery('#st-attachments-attach-formtarget')
                .bind('load', function () {
                    jQuery('#st-attachments-attach-uploadmessage').html(
                        loc('Upload Complete')
                    );
                    jQuery('#st-attachments-attach-filename').attr(
                        'disabled', false
                    );
                    jQuery('#st-attachments-attach-closebutton').attr(
                        'disabled', false
                    );
                    Page.refreshAttachments();
                    Page.refreshPageContent();
                });

            jQuery('#st-attachments-attach-form').submit();
            jQuery('#st-attachments-attach-closebutton').attr('disabled', true);
            jQuery(this).attr('disabled', true);

            return false;
        });


    var editor_uri = nlw_make_s3_path('/javascript/socialtext-editor.js')
        .replace(/(\d+\.\d+\.\d+\.\d+)/,'$1.'+Socialtext.make_time);

    jQuery("#st-comment-button-link")
        .click(function () { 
            var display_width = (window.offsetWidth ||
                                 document.body.clientWidth ||
                                 600
                                );
            window.open(
                'index.cgi?action=enter_comment;page_name=' +
                Socialtext.page_id + ';caller_action=display',
                '_blank',
                'toolbar=no, location=no, directories=no, status=no, ' +
                'menubar=no, titlebar=no, scrollbars=yes, resizable=yes, ' +
                'width=' + display_width + ', height=200, left=50, top=200'
            );

            if ( navigator.userAgent.toLowerCase().indexOf("safari") != -1 ) {
                window.location.reload();
            }
        });

    jQuery("#st-edit-button-link,#st-edit-actions-below-fold-edit")
        .one("click", function () {
            jQuery('#bootstrap-loader').show();
            jQuery.ajaxSettings.cache = true;
            jQuery('<script>')
                .attr('src', editor_uri)
                .attr('language', 'javascript')
                .appendTo('head');
        });
});
