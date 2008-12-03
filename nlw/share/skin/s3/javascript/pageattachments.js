(function ($) {

Attachments = {
    _newAttachmentList: [],
    _attachmentList: [],

    resetNewAttachments: function () {
        this._newAttachmentList = [];
    },

    addNewAttachment: function (file) {
        this._newAttachmentList.push(file);
        if (window.wikiwyg && wikiwyg.is_editing) {
            var type = file["content-type"].match(/image/) ? 'image' : 'file';
            var widget_text = type + ': ' + file.name;
            var widget_string = '{' + widget_text + '}';
            wikiwyg.current_mode.insert_widget(widget_string);
        }
    },

    getNewAttachments: function () {
        return this._newAttachmentList;
    },

    attachmentList: function () {
        return $.map(
            this._newAttachmentList,
            function (item) { return item.name }
        ).join(', ')
    },

    deleteAttachments: function (list) {
        var file;
        while (file = list.pop()) {
            this.delAttachment(file.uri);
        }
        Page.refreshPageContent(true);
        this.refreshAttachments();
    },

    deleteAllAttachments: function () {
        this.deleteAttachments(this._attachmentList);
    },

    deleteNewAttachments: function (cb) {
        this.deleteAttachments(this._newAttachmentList);
    },

    refreshAttachments: function (cb) {
        var self = this;
        $.ajax({
            url: Page.pageUrl() + '/attachments',
            cache: false,
            dataType: 'json',
            success: function (list) {
                $('#st-attachment-listing').html('');
                for (var i=0; i< list.length; i++) {
                    var item = list[i];
                    self._attachmentList.push(item);
                    var extractLink = '';
                    if (item.name.match(/\.(zip|tar|tar.gz|tgz)$/)) {
                        var attach_id = item.id;
                        extractLink = $('<a href="#" />')
                            .html('<img src="/static/skin/common/images/extract.png" width="16" height="16" border="0" />')
                            .attr('name', item.uri)
                            .attr('alt', loc('Extract this attachment'))
                            .attr('title', loc('Extract this attachment'))
                            .bind('click', function () {
                                $(this).children('img').attr('src', '/static/skin/common/images/ajax-loader.gif');
                                Attachments.extractAttachment(attach_id);
                                return false;
                            });
                    }
                    $('#st-attachment-listing').append(
                        $('<li />').append(
                            $('<a />')
                                .html(item.name)
                                .attr('title', loc("Uploaded by [_1] on [_2]. ([_3] bytes)", item.uploader, item.date, Page._format_bytes(item['content-length'])))
                                .attr('href', item.uri),
                            ' ',
                            extractLink,
                            ' ',
                            $('<a href="#" />')
                                .html('<img src="'+nlw_make_s3_path('/images/delete.png')+'"width="16" height="16" border="0" />')
                                .attr('name', item.uri)
                                .attr('alt', loc('Delete this attachment'))
                                .attr('title', loc('Delete this attachment'))
                                .bind('click', function () {
                                    $(this).children('img').attr('src', '/static/skin/common/images/ajax-loader.gif');
                                    Attachments.delAttachment(this.name, true);
                                    return false;
                                })
                        )
                    )
                }
                if (cb) cb(list);
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
                Attachments.refreshAttachments();
                Page.refreshPageContent();
            }
        });
    },

    delAttachment: function (url, refresh) {
        $.ajax({
            type: "DELETE",
            url: url,
            async: false
        });
        if (refresh) {
            this.refreshAttachments();
            Page.refreshPageContent(true);
        }
    }
};

// Backwards compat
Attachments.delete_new_attachments = Attachments.deleteNewAttachments;
Attachments.delete_all_attachments = Attachments.deleteAllAttachments;
Attachments.reset_new_attachments = Attachments.resetNewAttachments;
Attachments.get_new_attachments = Attachments.getNewAttachments;

})(jQuery);
