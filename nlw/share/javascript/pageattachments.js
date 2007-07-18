if (typeof ST == 'undefined') {
    ST = {};
}

// ST.Attachments class
ST.Attachments = function (args) {
    this._uploaded_list = [];
    $H(args).each(this._applyArgument.bind(this));

    Event.observe(window, 'load', this._loadInterface.bind(this));
};

function sort_filesize(a,b) {
    var aunit = a.charAt(a.length-1);
    var bunit = b.charAt(b.length-1);
    if (aunit != bunit) {
        if (aunit < bunit) {
            return -1;
        } else if ( aunit > bunit ) {
            return 1;
        } else {
            return 0;
        }
    } else {
        var asize = parseFloat(a.slice(0,-1));
        var bsize = parseFloat(b.slice(0,-1));
        if (asize < bsize) {
            return -1;
        } else if ( asize > bsize ) {
            return 1;
        } else {
            return 0;
        }
    }
};

ST.Attachments.prototype = {
    attachments: null,
    _uploaded_list: [],
    _attachWaiter: '',
    _table_sorter: null,

    element: {
        attachmentInterface:   'st-attachments-attachinterface',
        manageInterface:       'st-attachments-manageinterface',

        listTemplate:          'st-attachments-listtemplate',
        manageTableTemplate:   'st-attachments-managetable',

        uploadButton:          'st-attachments-uploadbutton',
        manageButton:          'st-attachments-managebutton',

        attachForm:            'st-attachments-attach-form',
        attachSubmit:          'st-attachments-attach-submit',
        attachUnpackCheckbox:  'st-attachments-attach-unpackcheckbox',
        attachEmbedCheckbox:   'st-attachments-attach-embedcheckbox',
        attachUnpack:          'st-attachments-attach-unpackfield',
        attachEmbed:           'st-attachments-attach-embedfield',
        attachUnpackLabel:     'st-attachments-attach-unpacklabel',
        attachCloseButton:     'st-attachments-attach-closebutton',
        attachFilename:        'st-attachments-attach-filename',
        attachFileError:       'st-attachments-attach-error',
        attachFileList:        'st-attachments-attach-list',
        attachMessage:         'st-attachments-attach-message',
        attachUploadMessage:   'st-attachments-attach-uploadmessage',

        manageTableRows:       'st-attachments-manage-body',
        manageCloseButton:     'st-attachments-manage-closebutton',
        manageDeleteButton:    'st-attachments-manage-deletebutton',
        manageDeleteMessage:   'st-attachments-manage-deletemessage',
        manageSelectAll:       'st-attachments-manage-selectall',
        manageTable:           'st-attachments-manage-filelisting'
    },

    jst: {
        list: '',
        manageTable: ''
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _attach_status_check: function () {
        var text = null;
        Try.these(
            function () { text = $('st-attachments-attach-formtarget').contentWindow.document.body.innerHTML; },
            function () { text = $('st-attachments-attach-formtarget').contentDocument.body.innerHTML; }
        );
        if (text == null)
            return;
        clearInterval(this._attach_waiter);
        $(this.element.attachUploadMessage).style.display = 'none';
        Element.update(this.element.attachUploadMessage, '');
        $(this.element.attachSubmit).disabled = false;
        $(this.element.attachUnpackCheckbox).disabled = false;
        $(this.element.attachEmbedCheckbox).disabled = false;
        $(this.element.attachCloseButton).style.display = 'block';

        this._update_uploaded_list($(this.element.attachFilename).value);

        Element.update(this.element.attachMessage, 'Click "Browse" to find the file you want to upload. When you click "Upload another file" your file will be uploaded and added to the list of attachments for this page.');
        $(this.element.attachSubmit).value = 'Upload another file';
        if (text.match(/Request Entity Too Large/)) {
            text = 'File size exceeds maximum limit. File was not uploaded.';
        }
        else {
            this._pullAttachmentList();
            Page.refresh_page_content(true);
        }

        Try.these(
            (function() {
                $(this.element.attachFilename).value = '';
                if ($(this.element.attachFilename).value) {
                    throw new Error ("Failed to clear value");
                }
            }).bind(this),
            (function() {
                var input = document.createElement('input');
                var old   = $(this.element.attachFilename);
                input.type = old.type;
                input.name = old.name;
                input.size = old.size;
                old.parentNode.replaceChild(input, old);
                input.id = this.element.attachFilename;
                this._hook_filename_field();
            }).bind(this)
        );
        $(this.element.attachFilename).focus();
        setTimeout(this._hide_attach_error.bind(this), 5 * 1000);
    },

    _attach_file_form_submit: function () {
        var filenameField = $(this.element.attachFilename);
        if (! filenameField.value) {
            this._show_attach_error("Please click browse and select a file to upload.");
            return false;
        }

        this._update_ui_for_upload(filenameField.value);
        $(this.element.attachCloseButton).style.display = 'none';

        this._attach_waiter = setInterval(this._attach_status_check.bind(this), 3 * 1000);
        return true;
    },

    _update_ui_for_upload: function (filename) {
        Element.update(this.element.attachUploadMessage, 'Uploading ' + filename + '...');
        $(this.element.attachSubmit).disabled = true;

        var cb = $(this.element.attachUnpackCheckbox);
        $(this.element.attachUnpack).value = (cb.checked) ? '1' : '0';
        cb.disabled = true;

        var cb = $(this.element.attachEmbedCheckbox);
        $(this.element.attachEmbed).value = (cb.checked) ? '1' : '0';
        cb.disabled = true;

        $(this.element.attachUploadMessage).style.display = 'block';

        this._hide_attach_error();
    },

    _check_for_zip_file: function () {
        var filename = $(this.element.attachFilename).value;

        if (filename.match(/\.zip$/, 'i')) {
            this._enable_unpack();
        } else {
            this._disable_unpack();
        }
    },

    _clear_uploaded_list: function () {
        this._uploaded_list = [];
        this._refresh_uploaded_list();
    },

    _delete_selected_attachments: function () {
        var to_delete = [];
        $A($(this.element.manageTableRows).getElementsByTagName('tr')).each(function (node) {
            if (node.getElementsByTagName('input')[0].checked) {
                Element.hide(node);
                to_delete.push(node.getElementsByTagName('input')[0].value);
            }
        });
        if (to_delete.length == 0)
            return false;

        var j = 0;
        var i = 0;
        for (i = 0; i < to_delete.length; i++) {
//            var attachmentId = to_delete[i].match(/\,(.+)\,/)[1];
//            var uri = Wikiwyg.is_safari
//                ? Page.UriPageAttachmentDelete(attachmentId)
//                : Page.APIUriAttachmentDelete(attachmentId);

            var ar = new Ajax.Request (
                to_delete[i],
                {
                    method: 'post',
                    requestHeaders: ['X-Http-Method','DELETE'],
                    onComplete: function(xhr) {
                        if( Wikiwyg.is_safari) {
                            j++;
                            return;
                        }
                    }.bind(this)
                }
            );
        }

        //if ( Wikiwyg.is_safari ) {
        //    var intervalID = window.setInterval(
        //        function() {
        //            if ( j < to_delete.length ) {
        //                return;
        //            }
        //            var ar = new Ajax.Request(
        //                Page.APIUriPageAttachment(),
        //                {
        //                    method: 'get',
        //                    asynchronous: false,
        //                    requestHeaders: ['Accept', 'text/javascript']
        //                }
        //            );
        //            this.attachments = JSON.parse(ar.transport.responseText);
        //            this._refresh_attachment_list();
        //            clearInterval( intervalID );
        //        }.bind(this)
        //        , 5
        //    );
        //}

// TODO - Update message setTimeout(function () {Element.update(this.element.manageDeleteMessage, '')}, 2000);
//        this._pullAttachmentList();
//        Page.refresh_page_content();
        return false;
    },

    _disable_unpack: function () {
        var unpackCheckbox = $(this.element.attachUnpackCheckbox);
        unpackCheckbox.disabled = true;
        unpackCheckbox.checked = false;
        unpackCheckbox.style.display = 'none';

        var label = $(this.element.attachUnpackLabel);
        label.style.color = '#aaa';
        label.style.display = 'none';
    },

    _display_attach_interface: function () {
        field = $(this.element.attachFilename);
        Try.these(function () {
            field.value = '';
        });

        $(this.element.attachmentInterface).style.display = 'block';
        this._disable_scrollbar();

        $(this.element.attachSubmit).value = 'Upload file';
        Element.update(this.element.attachMessage, 'Click "Browse" to find the file you want to upload. When you click "Upload file" your file will be uploaded and added to the list of attachments for this page.');

        var overlayElement = $('st-attachments-attach-attachinterface-overlay');
        var element = $('st-attachments-attach-interface');
        this._center_lightbox(overlayElement, element, this.element.attachmentInterface);
        this._disable_unpack();
        this._check_for_zip_file();
        field.focus();
        return false;
    },

    _center_lightbox: function (overlayElement, element, parentElement) {
        var divs = {
            wrapper: $(parentElement),
            background: overlayElement,
            content: element,
            contentWrapper: element.parentNode
        };
        Widget.Lightbox.show({'divs':divs});

    },

    _display_manage_interface: function () {
        $(this.element.manageSelectAll).checked = false;
        this._refresh_manage_table();
        $(this.element.manageInterface).style.display = 'block';
        this._disable_scrollbar();
        var overlayElement = $('st-attachments-manage-manageinterface-overlay');
        var element = $('st-attachments-manage-interface');
        this._center_lightbox(overlayElement, element, this.element.manageInterface);

        this._table_sorter = new Widget.SortableTable( {
            "tableId": this.element.manageTable,
            "initialSortColumn": 1,
            "columnSpecs": [
              { skip: true },
              { sort: "text" },
              { sort: "text" },
              { sort: "date" },
              { sort: sort_filesize}
            ]
          } );
        return false;
    },

    _enable_scrollbar: function(){
        this._disable_scrollbar('auto','auto');
    },

    // This method has parameters because it could
    // be used to both enable and disable scrollbar. Caller
    // shouldn't give any arguments when calling it.
    _disable_scrollbar: function(height, overflow){
        if ( !height ) height = '100%';
        if ( !overflow ) overflow = 'hidden';

        var bod = document.getElementsByTagName('body')[0];
        bod.style.height = height;
        bod.style.overflow = overflow;

        var htm = document.getElementsByTagName('html')[0];
        htm.style.height = height;
        htm.style.overflow = overflow;
    },

    _enable_unpack: function () {
        var unpackCheckbox = $(this.element.attachUnpackCheckbox);
        unpackCheckbox.disabled = false;
        unpackCheckbox.checked = false;
        unpackCheckbox.style.display = '';

        var label = $(this.element.attachUnpackLabel);
        label.style.color = 'black';
        label.style.display = '';
    },

    _hide_attach_error: function () {
        $(this.element.attachFileError).style.display = 'none';
    },

    _hide_attach_file_interface: function () {
        if (!this._is_uploading_file()) {
            $(this.element.attachmentInterface).style.display = 'none';
            $(this.element.attachSubmit).value = 'Upload file';
            this._enable_scrollbar();
            this._clear_uploaded_list();
        }
        return false;
    },

    _hide_manage_file_interface: function () {
        this._pullAttachmentList();
        Page.refresh_page_content(true);

        $(this.element.manageInterface).style.display = 'none';
        this._enable_scrollbar();
        return false;
    },

    _hook_filename_field: function() {
        if (! $(this.element.attachFilename)) return;
        Event.observe(this.element.attachFilename,     'blur',   this._check_for_zip_file.bind(this));
        Event.observe(this.element.attachFilename,     'keyup',  this._check_for_zip_file.bind(this));
        Event.observe(this.element.attachFilename,     'change', this._check_for_zip_file.bind(this));
    },

    _is_uploading_file: function() {
        return $(this.element.attachSubmit).disabled;
    },

    _pullAttachmentList: function () {
        var ar = new Ajax.Request(
            Page.AttachmentListUri(),
            {
                method: 'get',
                requestHeaders: ['Accept', 'application/json'],
                onComplete: (function (req) {
                    this.attachments = JSON.parse(req.responseText);
                    this._refresh_attachment_list();
                }).bind(this)
            }
        );
    },

    _refresh_attachment_list: function () {
        if (this.attachments && this.attachments.length > 0) {
            var data = {};
            data.attachments = this.attachments;
            this.jst.list.update(data);
        } else {
            this.jst.list.clear();
        }
        return false;
    },

    _refresh_manage_table: function () {
        if (this.attachments && this.attachments.length > 0) {
            var data = {};
            data.attachments = this.attachments;
            var i;
            for (i=0; i< data.attachments.length; i++) {
                var filesize = data.attachments[i]['content-length'];
                var n = 0;
                var unit = '';
                if (filesize < 1024) {
                    unit = 'B';
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
                data.attachments[i].displaylength = n + unit;
            }
            data.page_name = Page.page_id;
            data.workspace = Page.wiki_id;
            Try.these(
                (function () {
                    this.jst.manageTable.update(data);
                }).bind(this),
                (function () { /* http://www.ericvasilik.com/2006/07/code-karma.html */
                    var temp = document.createElement('div');
                    temp.innerHTML = '<table><tbody id="' + this.element.manageTableRows + '-temp">' +
                                     this.jst.manageTable.html(data) + '</tbody></table>';
                    $(this.element.manageTableRows).parentNode.replaceChild(
                        temp.childNodes[0].childNodes[0],
                        $(this.element.manageTableRows)
                    );
                    $(this.element.manageTableRows + '-temp').id = this.element.manageTableRows;
                }).bind(this)
            );
        } else {
            Try.these(
                (function () {
                    this.jst.manageTable.clear();
                }).bind(this),
                (function () { /* http://www.ericvasilik.com/2006/07/code-karma.html */
                    var temp = document.createElement('div');
                    temp.innerHTML = '<table><tbody id="' + this.element.manageTableRows + '-temp"></tbody></table>';
                    $(this.element.manageTableRows).parentNode.replaceChild(
                        temp.childNodes[0].childNodes[0],
                        $(this.element.manageTableRows)
                    );
                    $(this.element.manageTableRows + '-temp').id = this.element.manageTableRows;
                }).bind(this)
            );
        }
        return false;
    },

    _refresh_uploaded_list: function () {
        if (this._uploaded_list.length > 0) {
            Element.update(this.element.attachFileList, '<span class="st-attachments-attach-listlabel">Uploaded files: </span>' + this._uploaded_list.join(', '));
            $(this.element.attachFileList).style.display = 'block';
        }
        else {
            $(this.element.attachFileList).style.display = 'none';
            Element.update(this.element.attachFileList, '');
        }
    },

    _show_attach_error: function (msg) {
        if (!msg)
            msg = '&nbsp;';
        Element.update(this.element.attachFileError, msg);
        $(this.element.attachFileError).style.display = 'block';
    },

    _toggle_all_attachments: function () {
        var checkbox = $(this.element.manageSelectAll);

        $A($(this.element.manageTableRows).getElementsByTagName('tr')).each(
            function (node) {
                node.getElementsByTagName('input')[0].checked = checkbox.checked;
            }
        );
    },

    _update_uploaded_list: function (filename) {
        filename = filename.match(/^.+[\\\/]([^\\\/]+)$/)[1];
        this._uploaded_list.push(filename);
        this._refresh_uploaded_list();
    },

    _loadInterface: function () {
        this.jst.list = new ST.TemplateField(this.element.listTemplate, 'st-attachments-listing');
        this.jst.manageTable = new ST.TemplateField(this.element.manageTableTemplate, this.element.manageTableRows);

       this._disable_unpack();

        if ($(this.element.uploadButton)) {
            Event.observe(this.element.uploadButton,       'click',  this._display_attach_interface.bind(this));
        }
        if ($(this.element.manageButton)) {
            Event.observe(this.element.manageButton,       'click',  this._display_manage_interface.bind(this));
        }
        if ($(this.element.manageCloseButton)) {
            Event.observe(this.element.manageCloseButton,  'click',  this._hide_manage_file_interface.bind(this));
        }
        if ($(this.element.manageDeleteButton)) {
            Event.observe(this.element.manageDeleteButton, 'click',  this._delete_selected_attachments.bind(this));
        }
        if ($(this.element.manageSelectAll)) {
            Event.observe(this.element.manageSelectAll,    'click',  this._toggle_all_attachments.bind(this));
        }
        if ($(this.element.attachCloseButton)) {
            Event.observe(this.element.attachCloseButton,  'click',  this._hide_attach_file_interface.bind(this));
        }
        if ($(this.element.attachForm)) {
            Event.observe(this.element.attachForm,         'submit', this._attach_file_form_submit.bind(this));
        }

        this._hook_filename_field();

        this._pullAttachmentList();
    }
};
