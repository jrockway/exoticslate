if (typeof ST == 'undefined') {
    ST = {};
}

// ST.Page calls
ST.Page = function (args) {
    $H(args).each(this._applyArgument.bind(this));
    Event.observe(window, 'load', this._loadInterface.bind(this));
};

ST.Page.prototype = {
    page_id: null,
    wiki_id: null,
    wiki_title: null,
    page_title: null,
    revision_id: null,
    comment_form_window_height: null,
    element: {
        toggleLink: 'st-page-boxes-toggle-link',
        accessories: 'st-page-boxes',
        underlay: 'st-page-boxes-underlay',
        pageEditing: 'st-page-editing',
        content: 'st-content-page-display'
    },
    hideAttributes: {
        onclick: 'showAccessories',
        text: '&gt;'
    },
    showAttributes: {
        onclick: 'hideAccessories',
        text: 'V'
    },

    restApiUri: function () {
        return '/data/workspaces/' + this.wiki_id + '/pages/' + this.page_id;
    },

    APIUri: function () {
        return '/page/' + this.wiki_id + '/' + this.page_id;
    },

    APIUriPageTag: function (tag) {
        return this.APIUri() + '/tags/' + encodeURIComponent(tag);
    },

    APIUriPageTags: function () {
        return this.APIUri() + '/tags';
    },

    UriPageTagDelete: function (id) {
        return '?action=category_delete_from_page;page_id=' + encodeURIComponent(this.page_id) + ';category=' + encodeURIComponent(id);
    },

    UriPageAttachmentDelete: function (id) {
        return '?action=attachments_delete;selected=' + this.page_id + ',' + id;
    },

    APIUriPageAttachment: function (id) {
        return this.APIUri() + '/attachments/' + id;
    },

    ContentUri: function () {
        return '/' + this.wiki_id + '/index.cgi';
    },

    active_page_exists: function (page_name) {
        page_name = trim(page_name);
        var uri = this.ContentUri();
        uri = uri + '?action=page_info;page_name=' + encodeURIComponent(page_name);
        var ar = new Ajax.Request (
            uri,
            {
                method: 'get',
                asynchronous: false,
                requestHeaders: ['Accept','text/javascript'],
                onFailure: (function(req, jsonHeader) {
                    alert('Could not retrieve the latest revision of the page');
                }).bind(this)
            }
        );
        var page_info = JSON.parse(ar.transport.responseText);
        return page_info.is_active;
    },

    refresh_page_content: function (force_update) {
        var uri = Page.restApiUri();
        uri = uri + '?verbose=1;link_dictionary=s2';
        var date = new Date();
        uri += ';iecacheworkaround=' + date.toLocaleTimeString();
        var request = new Ajax.Request (
            uri,
            {
                method: 'get',
                asynchronous: false,
                requestHeaders: ['Accept','application/json'],
                onFailure: (function(req, jsonHeader) {
                    alert('Could not retrieve the latest revision of the page');
                }).bind(this)
            }
        );

        if (request.transport.status == 403) {
            window.location = "/challenge";
            return;
        }

        if (request.transport.status == 200) {
            var page_info = JSON.parse(request.transport.responseText);
            if (page_info) {
                if ((Page.revision_id < page_info.revision_id) || force_update) {
                    $('st-page-content').innerHTML = page_info.html;
                    $('st-page-editing-revisionid').value = page_info.revision_id;
                    Page.revision_id = page_info.revision_id;
                    if ($('st-raw-wikitext-textarea')) {
                        $('st-raw-wikitext-textarea').value = Wikiwyg.is_safari
                            ? Wikiwyg.htmlUnescape(page_info.wikitext)
                            : page_info.wikitext;
                    }
                    var revisionNode = $('st-rewind-revision-count');
                    if (revisionNode) {
                        Element.update('st-rewind-revision-count', '&nbsp;&nbsp;' + page_info.revision_count);
                        Element.update('st-page-stats-revisions', page_info.revision_count + ' revisions');
                    }
                }
            }
        }
    },

    hideAccessories: function () {
        Cookie.set('st-page-accessories', 'hide');
        Element.hide(this.element.accessories);
        Element.update(this.element.toggleLink, this.hideAttributes.text);
        $(this.element.toggleLink).onclick = this[this.hideAttributes.onclick].bind(this);
        Element.setStyle('st-page-maincontent', {marginRight: '0px'});
    },

    showAccessories: function (leaveMarginAlone) {
        Cookie.set('st-page-accessories', 'show');
        Element.show(this.element.accessories);
        Element.update(this.element.toggleLink, this.showAttributes.text);
        $(this.element.toggleLink).onclick = this[this.showAttributes.onclick].bind(this);
        if (! Element.visible('st-pagetools')) {
            Element.setStyle('st-page-maincontent', {marginRight: '240px'});
        }
    },

    orientAccessories: function () {
        var s_height = $(this.element.accessories).offsetHeight;
        var s_width = $(this.element.accessories).offsetWidth;
        Element.setStyle(this.element.underlay, {height: s_height + 'px'});
        Element.setStyle(this.element.underlay, {width: s_width + 'px'});

        if (document.all) {
            var c_height = (
                 $(this.element.accessories).offsetHeight + (
                       $(this.element.accessories).offsetTop
                     - $(this.element.content).offsetTop
                 )
            );
            if ($(this.element.content).offsetHeight < c_height) {
                if (c_height > 0) {
                    $(this.element.content).style.height = c_height + 'px';
                }
            }
        }
    },

    installUnderlayOrienter: function () {
        /* We want to call it for the first time ASAP since it may
         * change the existing page layout */
        this.orientAccessories();
        setInterval(this.orientAccessories.bind(this), 1000);
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _loadInterface: function () {
        var m = Cookie.get('st-page-accessories');
        if (m == null || m == 'show') {
            this.showAccessories();
        } else {
            this.hideAccessories();
        }
        this.installUnderlayOrienter();
    }
};

// ST.Attachments class
ST.Attachments = function (args) {
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
    _attachments: null,
    _uploaded_list: [],
    _attachWaiter: '',
    _table_sorter: null,

    element: {
        attachmentInterface:   'st-attachments-attachinterface',
        manageInterface:       'st-attachments-manageinterface',

        listTemplate:          'st-attachments-listtemplate',
        fileList:              'st-attachments-files',
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
        if (!text) return;
        clearInterval(this._attach_waiter);
        $(this.element.attachUploadMessage).style.display = 'none';
        Element.update(this.element.attachUploadMessage, '');
        $(this.element.attachSubmit).disabled = false;
        $(this.element.attachUnpackCheckbox).disabled = false;
        $(this.element.attachEmbedCheckbox).disabled = false;
        $(this.element.attachCloseButton).style.display = 'block';

        Element.update(this.element.attachMessage, 'Click "Browse" to find the file you want to upload. When you click "Upload another file" your file will be uploaded and added to the list of attachments for this page.');
        $(this.element.attachSubmit).value = 'Upload another file';
        this._refresh_uploaded_list();
        Page.refresh_page_content(true);
        var response = text.match(/({"attachments"\:.*}]})/, 'i');
        if (response) {
            this._attachments = JSON.parse(response[1]);
            this._refresh_attachment_list();
        } else {
            if (text.match(/Request Entity Too Large/)) {
                text = 'File size exceeds maximum limit. File was not uploaded.';
            }

            this._show_attach_error(text);
            this._uploaded_list.pop();
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

        this._update_uploaded_list(filename);
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
            var attachmentId = to_delete[i].match(/\,(.+)\,/)[1];
            var uri = Wikiwyg.is_safari
                ? Page.UriPageAttachmentDelete(attachmentId)
                : Page.APIUriPageAttachment(attachmentId);

            var ar = new Ajax.Request (
                uri,
                {
                    method: 'delete',
                    asynchronous: true,
                    requestHeaders: ['Accept','text/javascript'],
                    onComplete: function(xhr) {
                        if( Wikiwyg.is_safari) {
                            j++;
                            return;
                        }
                        this._attachments = JSON.parse(xhr.responseText);
                        this._refresh_attachment_list();
                    }.bind(this)
                }
            );
        }

        if ( Wikiwyg.is_safari ) {
            var intervalID = window.setInterval(
                function() {
                    if ( j < to_delete.length ) {
                        return;
                    }
                    var ar = new Ajax.Request(
                        Page.APIUriPageAttachment(),
                        {
                            method: 'get',
                            asynchronous: false,
                            requestHeaders: ['Accept', 'text/javascript']
                        }
                    );
                    this._attachments = JSON.parse(ar.transport.responseText);
                    this._refresh_attachment_list();
                    clearInterval( intervalID );
                }.bind(this)
                , 5
            );
        }

// TODO - Update message setTimeout(function () {Element.update(this.element.manageDeleteMessage, '')}, 2000);
        Page.refresh_page_content();
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
        parentElement = $(parentElement);
        var divs = {
            wrapper: parentElement,
            background: overlayElement,
            content: element,
            contentWrapper: element.parentNode
        }
        Widget.Lightbox.show({'divs':divs, 'effects':['RoundedCorners']});
        divs.contentWrapper.style.width="520px";
        divs.content.style.padding="10px";
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

    _refresh_attachment_list: function () {
        if (this._attachments.attachments && this._attachments.attachments.length > 0) {
            var data = this._attachments;
            data.page_name = Page.page_id;
            data.workspace = Page.wiki_id;
            this.jst.list.update(data);
        } else {
            this.jst.list.clear();
        }
        return false;
    },

    _refresh_manage_table: function () {
        if (this._attachments.attachments && this._attachments.attachments.length > 0) {
            var data = this._attachments;
            var i;
            for (i=0; i< data.attachments.length; i++) {
                var n = 0;
                var unit = 'X';
                if (data.attachments[i].filesize < 1024) {
                    unit = 'B';
                    n = data.attachments[i].filesize;
                } else if (data.attachments[i].filesize < 1024*1024) {
                    unit = 'K';
                    n = data.attachments[i].filesize/1024;
                    if (n < 10)
                        n = n.toPrecision(2);
                    else
                        n = n.toPrecision(3);
                } else {
                    unit = 'M';
                    n = data.attachments[i].filesize/(1024*1024);
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
    },

    _loadInterface: function () {
        this.jst.list = new ST.TemplateField(this.element.listTemplate, 'st-attachments-listing');
        this.jst.manageTable = new ST.TemplateField(this.element.manageTableTemplate, this.element.manageTableRows);

        this._attachments = JSON.parse($(this.element.fileList).value);
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

        this._refresh_attachment_list();
    }
};


// St.Tags Class

ST.Tags = function (args) {
    $H(args).each(this._applyArgument.bind(this));

    Event.observe(window, 'load', this._loadInterface.bind(this));
};


ST.Tags.prototype = {
    showTagField: false,
    workspaceTags: {},
    initialTags: {},
    suggestionRE: '',
    _deleted_tags: [],
    socialtextModifiers: {
        escapespecial : function(str) {
            var escapes = [
                { regex: /'/g, sub: "\\'" },
                { regex: /\n/g, sub: "\\n" },
                { regex: /\r/g, sub: "\\r" },
                { regex: /\t/g, sub: "\\t" },
                { regex: /</, sub: '&lt;' }
            ];
            for (var i=0; i < escapes.length; i++)
                str = str.replace(escapes[i].regex, escapes[i].sub);
            return str;
        },
        quoter: function (str) {
            return str.replace(/"/g, '&quot;');
        },
        tagescapespecial : function(t) {
            var escapes = [
                { regex: /'/g, sub: "\\'" },
                { regex: /\n/g, sub: "\\n" },
                { regex: /\r/g, sub: "\\r" },
                { regex: /\t/g, sub: "\\t" }
            ];
            s = t.tag;
            for (var i=0; i < escapes.length; i++)
                s = s.replace(escapes[i].regex, escapes[i].sub);
            return s;
        }
    },

    element: {
        workspaceTags: 'st-tags-workspace',
        tagName: 'st-tags-tagtemplate',
        tagSuggestion: 'st-tags-suggestiontemplate',
        addButton: 'st-tags-addbutton',
        displayAdd: 'st-tags-addlink',
        initialTags: 'st-tags-initial',
        tagField: 'st-tags-field',
        addInput: 'st-tags-addinput',
        addBlock: 'st-tags-addblock',
        message: 'st-tags-message',
        tagSuggestionList: 'st-tags-suggestionlist',
        suggestions: 'st-tags-suggestion',
        deleteTagsMessage: 'st-tags-deletemessage',
        noTagsPlaceholder: 'st-no-tags-placeholder'
    },

    jst: {
        name: '', // WAS TaglineTemplate
        suggestion: '' // WAS SuggestionFormat
    },

    displayListOfTags: function (tagfield_should_focus) {
        var tagList = this.initialTags;
        if (tagList.tags && tagList.tags.length > 0) {
            tagList._MODIFIERS = this.socialtextModifiers;
            this.initialTags = tagList;

            // Tags might have raw html.
            for(var ii = 0; ii < tagList.tags.length ; ii++) {
               tagList.tags[ii].tag = html_escape( tagList.tags[ii].tag )
            }

            this.computeTagLevels();
            this.jst.name.update(tagList);
        } else {
            this.jst.name.clear();
        }
        if (this.showTagField) {
            Element.setStyle('st-tags-addinput', {display: 'block'});
            if (tagfield_should_focus) {
                tagField = $(this.element.tagField).focus();
            }
        }
        if ($('st-tags-message')) {
            Element.hide('st-tags-message');
        }
    },

    _copy_page_tags_to_master_list: function () {
        for (var i=0; i < this.initialTags.tags.length; i++) {
            found = false;
            var tag = this.initialTags.tags[i];
            var lctag = tag.tag.toLowerCase();
            for (var j=0; j < this.workspaceTags.tags.length; j++) {
                if (this.workspaceTags.tags[j].tag.toLowerCase() == lctag) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                this.workspaceTags.tags.push(tag);
            }
        }
    },

    decodeTagNames: function () {
        var tagList = this.initialTags;
        for (i=0; i < tagList.tags.length; i++) {
            tagList.tags[i].tag = decodeURIComponent(tagList.tags[i].tag);
        }
    },

    computeTagLevels: function () {
        var tagList = this.initialTags;
        var i=0;
        var maxWeight = tagList.maxCount;

        if (maxWeight < 10) {
            for (i=0; i < tagList.tags.length; i++)
                tagList.tags[i].level = 'st-tags-level2';
        }
        else {
            for (i=0; i < tagList.tags.length; i++) {
                var tagWeight = tagList.tags[i].count / maxWeight;
                if (tagWeight > 0.8)
                    tagList.tags[i].level = 'st-tags-level5';
                else if (tagWeight > 0.6)
                    tagList.tags[i].level = 'st-tags-level4';
                else if (tagWeight > 0.4)
                    tagList.tags[i].level = 'st-tags-level3';
                else if (tagWeight > 0.2)
                    tagList.tags[i].level = 'st-tags-level2';
                else
                    tagList.tags[i].level = 'st-tags-level1';
            }
        }
        this.initialTags = tagList;
    },

    addTag: function (tagToAdd) {
        Element.hide(this.element.suggestions);
        tagToAdd = this._trim(tagToAdd);
        var tagField = $(this.element.tagField);
        if (tagToAdd.length == 0) {
            return;
        }
        //XXX tagToAdd = html_escape(tagToAdd);
        this.showTagMessage('Adding tag ' + html_escape(tagToAdd));
        var uri = Page.APIUriPageTag(encodeURIComponent(tagToAdd));
        new Ajax.Request (
            uri,
            {
                method: 'POST',
                requestHeaders: ['Accept','text/javascript'],
                onComplete: (function (req) {
                    this._remove_from_deleted_list(tagToAdd);
                    var data = JSON.parse(req.responseText);
                    this.initialTags = data;
                    this.decodeTagNames(); /* Thanks, IE */
                    this._copy_page_tags_to_master_list();
                    this.displayListOfTags(true);
                    Element.hide(this.element.noTagsPlaceholder);
                    Page.refresh_page_content();
                }).bind(this),
                onFailure: (function(req, jsonHeader) {
                    alert('Could not add tag');
                    this.resetDisplayOnError();
                }).bind(this)
            }
        );
        tagField.value = '';
    },

    addTagFromField: function () {
        this.addTag($(this.element.tagField).value);
    },

    displayAddTag: function () {
        this.showTagField = true;
        Element.setStyle(this.element.addInput, {display: 'block'});
        $(this.element.tagField).focus();
        Element.hide(this.element.addBlock);
    },

    _remove_from_deleted_list: function (tagToRemove) {
        this._deleted_tags.deleteElementIgnoreCase(tagToRemove);
        this._update_delete_list();
    },

    showTagMessage: function (msg) {
        Element.hide(this.element.addInput);
        Element.setStyle(this.element.message, {display: 'block'});
        Element.update(this.element.message, msg);
    },

    resetDisplayOnError: function() {
        if (this.showTagField) {
            Element.setStyle(this.element.addInput, {display: 'block'});
        }
        Element.hide(this.element.message);
        Element.update(this.element.message, '');
    },

    findSuggestions: function () {
        var field = $(this.element.tagField);

        if (field.value.length == 0) {
            Element.hide(this.element.suggestions);
        } else {
            if (this.workspaceTags.tags) {
                var expression = field.value.replace(/([.*+?|(){}[\]\\])/g,'\\$1');
                expression = '(^| )'+expression;
                this.suggestionRE = new RegExp(expression,'i');
                var suggestions = {
                    matches : this.workspaceTags.tags.grep(this.matchTag.bind(this))
                };
                Element.setStyle(this.element.suggestions, {display: 'block'});
                if (suggestions.matches.length > 0) {
                    suggestions._MODIFIERS = this.socialtextModifiers;
                    this.jst.suggestion.update(suggestions);
                } else {
                    var help = '<span class="st-tags-nomatch">No matches</span>';
                    this.jst.suggestion.set_text(help);
                }
            }
        }
    },

    matchTag: function (tag) {
        if (typeof tag.tag == 'number') {
            var s = tag.tag.toString();
            return s.search(this.suggestionRE) != -1;
        } else {
            return tag.tag.search(this.suggestionRE) != -1;
        }
    },

    tagFieldKeyHandler: function (event) {
        var key;
        if (window.event) {
            key = event.keyCode;
        } else if (event.which) {
            key = event.which;
        }

        if (key == Event.KEY_RETURN) {
            this.addTagFromField();
            return false;
        } else if (key == Event.KEY_TAB) {
            return this.setFirstMatchingSuggestion();
        }
    },

    setFirstMatchingSuggestion: function () {
        var field = $(this.element.tagField);

        if (field.value.length > 0) {
            var suggestions = this.workspaceTags.tags.grep(this.matchTag.bind(this));
            if ((suggestions.length >= 1) && (field.value != suggestions[0].tag)) {
                field.value = suggestions[0].tag;
                return false;
            }
        }
        return true;
    },

    fetchTags: function () {
        var uri = Page.APIUriPageTags();
        var ar = new Ajax.Request (
            uri,
            {
                method: 'get',
                requestHeaders: ['Accept','text/javascript'],
                onComplete: (function (req) {
                    this.initialTags = JSON.parse(req.responseText);
                    if (this.initialTags.tags.length == 0) {
                        Element.show(this.element.noTagsPlaceholder);
                    }
                    this.decodeTagNames(); /* Thanks, IE */
                    this.displayListOfTags(false);
                    $(this.element.tagField).focus();
                }).bind(this),
                onFailure: (function(req, jsonHeader) {
                    this._deleted_tags.pop();
                    alert('Could not remove tag');
                    this.resetDisplayOnError();
                }).bind(this)
            }
        );
    },

    viewTag: function (tag) {
        tag = encodeURIComponent(tag);
        var uri = "?action=category_display;category=" + tag + ";tag=/" + tag;
        document.location = uri;
    },

    deleteTag: function (tagToDelete) {
        this.showTagMessage('Removing tag ' + html_escape(tagToDelete));
        this._deleted_tags.push(tagToDelete);

        var uri = Page.UriPageTagDelete(tagToDelete);
        var ar = new Ajax.Request (
            uri,
            {
                method: 'get',
                requestHeaders: ['Accept','text/javascript'],
                onComplete: (function (req) {
                    this._update_delete_list();
                    Page.refresh_page_content();
                    this.fetchTags();
                }).bind(this),
                onFailure: (function(req, jsonHeader) {
                    this._deleted_tags.pop();
                    alert('Could not remove tag');
                    this.resetDisplayOnError();
                }).bind(this)
            }
        );
    },

    _update_delete_list: function () {
        if (this._deleted_tags.length > 0) {
            Element.update(this.element.deleteTagsMessage, html_escape('These tags have been removed: ' + this._deleted_tags.join(', ')));
            $(this.element.deleteTagsMessage).style.display = 'block';
        }
        else {
            Element.update(this.element.deleteTagsMessage, '');
            $(this.element.deleteTagsMessage).style.display = 'none';
        }
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _trim: function (value) {
        // XXX Belongs in Scalar Utils?
        var ltrim = /\s*((\s*\S+)*)/;
        var rtrim = /((\s*\S+)*)\s*/;
        return value.replace(rtrim, "$1").replace(ltrim, "$1");
    },

    _loadInterface: function () {
        this.jst.name = new ST.TemplateField(this.element.tagName, 'st-tags-listing');
        this.jst.suggestion = new ST.TemplateField(this.element.tagSuggestion, this.element.tagSuggestionList);

        this.workspaceTags  = JSON.parse($(this.element.workspaceTags).value);
        this.initialTags = JSON.parse($(this.element.initialTags).value);

        if ($(this.element.addButton)) {
            Event.observe(this.element.addButton,  'click', this.addTagFromField.bind(this));
        }
        if ($(this.element.displayAdd)) {
            Event.observe(this.element.displayAdd, 'click', this.displayAddTag.bind(this));
        }
        if ($(this.element.tagField)) {
            Event.observe(this.element.tagField, 'keyup', this.findSuggestions.bind(this));
            Event.observe(this.element.tagField, 'keydown', this.tagFieldKeyHandler.bind(this));
        }

        this.displayListOfTags(false);
    }

};

// ST.Page calls
ST.NavBar = function (args) {
    $H(args).each(this._applyArgument.bind(this));
    Event.observe(window, 'load', this._loadInterface.bind(this));
};

ST.NavBar.prototype = {
    element: {
        searchForm: 'st-search-form',
        searchButton: 'st-search-submit',
        searchField: 'st-search-term'
    },

    submit_search: function (arg) {
        $(this.element.searchForm).submit();
    },

    clear_search: function(arg) {
        if( $(this.element.searchField).value.match(/New\s*search/i) ) {
            $(this.element.searchField).value = "";
        }
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _loadInterface: function () {
        var element = $(this.element.searchButton);
        if (! element) return;
        Event.observe(element, 'click', this.submit_search.bind(this));
        if (! $(this.element.searchField) ) return;
        Event.observe(this.element.searchField, 'click', this.clear_search.bind(this));
        Event.observe(this.element.searchField, 'focus', this.clear_search.bind(this));
    }
};

// main
if (Socialtext.box_javascript) {
    window.Tags = new ST.Tags ();
    window.Attachments = new ST.Attachments ();
}

window.NavBar = new ST.NavBar ();
