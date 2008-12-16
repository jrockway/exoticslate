var ST = ST || {};
ST.Attachments = function () {}
var proto = ST.Attachments.prototype = {};
proto._newAttachmentList = [];
proto._attachmentList = [];

proto.resetNewAttachments = function () {
    this._newAttachmentList = Socialtext.new_attachments || [];
};

proto.addNewAttachment = function (file) {
    this._newAttachmentList.push(file);
    if (window.wikiwyg && wikiwyg.is_editing) {
        var type = file["content-type"].match(/image/) ? 'image' : 'file';
        var widget_text = type + ': ' + file.name;
        var widget_string = '{' + widget_text + '}';
        wikiwyg.current_mode.insert_widget(widget_string);
    }
};

proto.getNewAttachments = function () {
    return this._newAttachmentList;
};

proto.attachmentList = function () {
    return $.map(
        this._newAttachmentList,
        function (item) { return item.name }
    ).join(', ')
};

proto.deleteAttachments = function (list) {
    var file;
    while (file = list.pop()) {
        this.delAttachment(file.uri);
    }
    Page.refreshPageContent(true);
    this.refreshAttachments();
};

proto.deleteAllAttachments = function () {
    this.deleteAttachments(this._attachmentList);
};

proto.deleteNewAttachments = function (cb) {
    this.deleteAttachments(this._newAttachmentList);
};

proto.refreshAttachments = function (cb) {
    var self = this;
    $.ajax({
        url: Page.pageUrl() + '/attachments',
        cache: false,
        dataType: 'json',
        success: function (list) {
            jQuery('#st-attachment-listing').html('');
            for (var i=0; i< list.length; i++) {
                var item = list[i];
                self._attachmentList.push(item);
                var extractLink = '';
                if (item.name.match(/\.(zip|tar|tar.gz|tgz)$/)) {
                    var attach_id = item.id;
                    extractLink = jQuery('<a href="#" />')
                        .html('<img src="/static/skin/common/images/extract.png" width="16" height="16" border="0" />')
                        .attr('name', item.uri)
                        .attr('alt', loc('Extract this attachment'))
                        .attr('title', loc('Extract this attachment'))
                        .bind('click', function () {
                            jQuery(this).children('img').attr('src', '/static/skin/common/images/ajax-loader.gif');
                            self.extractAttachment(attach_id);
                            return false;
                        });
                }
                jQuery('#st-attachment-listing').append(
                    jQuery('<li />').append(
                        jQuery('<a />')
                            .html(item.name)
                            .attr('title', loc("Uploaded by [_1] on [_2]. ([_3] bytes)", item.uploader, item.date, Page._format_bytes(item['content-length'])))
                            .attr('href', item.uri),
                        ' ',
                        extractLink,
                        ' ',
                        jQuery('<a href="#" />')
                            .html('<img src="'+nlw_make_s3_path('/images/delete.png')+'"width="16" height="16" border="0" />')
                            .attr('name', item.uri)
                            .attr('alt', loc('Delete this attachment'))
                            .attr('title', loc('Delete this attachment'))
                            .bind('click', function () {
                                jQuery(this).children('img').attr('src', '/static/skin/common/images/ajax-loader.gif');
                                self.delAttachment(this.name, true);
                                return false;
                            })
                    )
                )
            }
            if (cb) cb(list);
        }
    });
};

proto.extractAttachment = function (attach_id) {
    var self = this;
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
            self.refreshAttachments();
            Page.refreshPageContent();
        }
    });
};

proto.delAttachment = function (url, refresh) {
    $.ajax({
        type: "DELETE",
        url: url,
        async: false
    });
    if (refresh) {
        this.refreshAttachments();
        Page.refreshPageContent(true);
    }
};

proto.onTargetLoad = function () {
    var self = this;

    jQuery('#st-attachments-attach-uploadmessage').html(loc('Upload Complete'));
    jQuery('#st-attachments-attach-filename').attr('disabled', false).val('');
    jQuery('#st-attachments-attach-closebutton').attr('disabled', false);

    this.refreshAttachments(function (list) {
        // Add the freshly-uploaded file to the
        // newAttachmentList queue.

        for (var i=0; i< list.length; i++) {
            var item = list[i];

            // Compare basename, because FF2 would use the
            // full pathname but item.name is basename-only.
            if (basename == item.name) {
                self.addNewAttachment(item);
            }
        }

        jQuery('#st-attachments-attach-list')
            .show()
            .html('')
            .append(
                jQuery('<span />')
                    .attr('class', 'st-attachments-attach-listlabel')
                    .html(loc('Uploaded files:') + 
                        '&nbsp;' + self.attachmentList()
                    )
            );
    });
    Page.refreshPageContent();
}

proto.onChangeFilename = function () {
    var self = this;
    var filename = jQuery('#st-attachments-attach-filename').val();
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

    var basename = filename.match(/[^\\\/]+$/);

    jQuery('#st-attachments-attach-uploadmessage').html(
        loc('Uploading [_1]...', basename)
    );

    jQuery('#st-attachments-attach-formtarget')
        .one('load', function () { self.onTargetLoad() });

    jQuery('#st-attachments-attach-form').submit();
    jQuery('#st-attachments-attach-closebutton').attr('disabled', true);
    jQuery(this).attr('disabled', true);
}

proto.process = function (template) {
    Socialtext.loc = loc;
    jQuery('body').append(
        Jemplate.process(template, Socialtext)
    );
}

proto.showUploadInterface = function () {
    var self = this;
    if (!jQuery('#st-attachments-attachinterface').size()) {
        this.process('attachment_lightbox.tt2');
        jQuery('#st-attachments-attach-filename')
            .val('')
            .unbind('change')
            .bind('change', function () {
                self.onChangeFilename(this);
                return false;
            });
    }
    $.showLightbox({
        content:'#st-attachments-attachinterface',
        close:'#st-attachments-attach-closebutton'
    });
};

// Backwards compat
proto.delete_new_attachments = proto.deleteNewAttachments;
proto.delete_all_attachments = proto.deleteAllAttachments;
proto.reset_new_attachments = proto.resetNewAttachments;
proto.get_new_attachments = proto.getNewAttachments;

window.Attachments = window.Attachments || new ST.Attachments;
