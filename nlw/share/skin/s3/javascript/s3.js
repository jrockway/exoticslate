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

var bootstrap2 = function(cb) {
    if (Socialtext.boostrap_ui_finished == true)  {
        cb.call(this);
        return;
    }

    jQuery(window).trigger("boostrapping");

    load_ui.call(this, function() {
        console.log('load_ui cb');
        if (Socialtext.page_type == 'spreadsheet') {
            load_socialcalc.call(this, function() {
                cb.call(this);
                jQuery(window).trigger("bootstrapped");
            });
        }
        else {
            window.setup_wikiwyg();
            cb.call(this);
            jQuery(window).trigger("bootstrapped");
        }
    });
};

var bootstrap = function(cb) {
    return function() { bootstrap2.call(this, cb); };
};

var start_editor = function() {
    // This setTimeout is required to get around of 
    // some simple mode bug in IE and FF.
    setTimeout(function() {
        if (Socialtext.page_type == 'spreadsheet' && Socialtext.wikiwyg_variables.hub.current_workspace.enable_spreadsheet) {
            jQuery("#st-all-footers, #st-display-mode-container").hide();
            jQuery("#st-edit-mode-container, #st-editing-tools-edit").show();
            Socialtext.render_spreadsheet_editor();

            return false;
        }

        window.wikiwyg.start_nlw_wikiwyg();
    }, 0);
}

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

    jQuery("#st-edit-button-link,#st-edit-actions-below-fold-edit")
        .addClass("bootstrapper")
        .one("click", bootstrap(start_editor));
});
