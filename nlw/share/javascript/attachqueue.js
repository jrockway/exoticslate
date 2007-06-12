if (typeof ST == 'undefined') {
    ST = {};
}

// ST.Attachments class
ST.AttachmentQueue = function (args) {
    $H(args).each(this._applyArgument.bind(this));

    Event.observe(window, 'load', this._loadInterface.bind(this));
};


ST.AttachmentQueue.prototype = {
    _queued_files: [],
    _sequence: 0,

    element: {
        queueInterface:   'st-attachmentsqueue-interface',

        listTemplate:     'st-attachmentsqueue-listtemplate',
        editUploadButton: 'st-edit-mode-uploadbutton',

        inputContainer:   'st-attachmentsqueue-fileprompt',
        holder:           'st-attachmentsqueue-holder',

        submitButton:     'st-attachmentsqueue-submitbutton',
        unpackCheckbox:   'st-attachmentsqueue-unpackcheckbox',
        unpackMessage:    'st-attachmentsqueue-unpackmessage',
        embedCheckbox:    'st-attachmentsqueue-embedcheckbox',
        embedMessage:     'st-attachmentsqueue-embedmessage',
        unpack:           'st-attachmentsqueue-unpackfield',
        embed:            'st-attachmentsqueue-embedfield',
        unpackLabel:      'st-attachmentsqueue-unpacklabel',
        closeButton:      'st-attachmentsqueue-closebutton',
        filename:         'st-attachmentsqueue-filename',
        fileError:        'st-attachmentsqueue-error',
        fileList:         'st-attachmentsqueue-list',
        message:          'st-attachmentsqueue-message',
        uploadMessage:    'st-attachmentsqueue-uploadmessage'
    },

    jst: {
        list: ''
    },

    _add_new_input: function () {
        var new_input = document.createElement( 'input' );
        new_input.type = 'file';
        new_input.name = 'file';
        new_input.id = 'st-attachmentsqueue-filename';
        new_input.size = 60;
        var container = $(this.element.inputContainer);
        container.appendChild(new_input);
        this._set_handlers_for_input();
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _check_for_zip_file: function () {
        var filename = $(this.element.filename).value;

        var has_zip = false;
        if (filename.match(/\.zip$/, 'i')) {
            has_zip = true;
        } else {
            has_zip = this._has_zip_file();
        }

        if (has_zip) {
            this._enable_unpack();
        }
        else {
            this._disable_unpack();
        }
    },

    clear_list: function () {
        this._queued_files = [];
        this._refresh_queue_list();
    },

    _disable_unpack: function () {
        var unpackCheckbox = $(this.element.unpackCheckbox);
//        unpackCheckbox.checked = false;
        unpackCheckbox.disabled = true;
        unpackCheckbox.style.display = 'none';

        var label = $(this.element.unpackLabel);
        label.style.color = '#aaa';
        label.style.display = 'none';
    },

    _display_interface: function () {
        field = $(this.element.filename);
        Try.these(function () {
            field.value = '';
        });

        $(this.element.queueInterface).style.display = 'block';
        this._center_lightbox(this.element.queueInterface);
        this._refresh_queue_list();
        field.focus();
        return false;
    },

    _center_lightbox: function (parentElement) {
        var overlayElement = $('st-attachmentsqueue-overlay');
        var element = $('st-attachmentsqueue-dialog');
        return (new ST.Lightbox).center(overlayElement, element, parentElement);
    },

    count: function () {
        return this._queued_files.length;
    },

    _enable_unpack: function () {
        var unpackCheckbox = $(this.element.unpackCheckbox);
        unpackCheckbox.disabled = false;
        unpackCheckbox.style.display = '';

        var label = $(this.element.unpackLabel);
        label.style.color = 'black';
        label.style.display = '';
    },

    file: function (index) {
        return this._queued_files[index];
    },

    _has_zip_file: function() {
        for (var i=0; i < this._queued_files.length; i++)
            if (this._queued_files[i].filename.match(/\.zip$/,'i'))
                return true;

        return false;
    },

    _hide_error: function () {
        $(this.element.fileError).style.display = 'none';
    },

    _hide_interface: function () {
        $(this.element.queueInterface).style.display = 'none';
        return false;
    },

    is_embed_checked: function() {
        return $(this.element.embedCheckbox).checked;
    },

    is_unpack_checked: function() {
        if (this._has_zip_file()) {
            return $(this.element.unpackCheckbox).checked;
        }
        else {
            return false;
        }
    },

    _queue_file: function () {
        var filenameField = $(this.element.filename);
        if (! filenameField.value) {
            this._show_error('Plese click "Browse" and select a file to upload.');
            return false;
        }

        var unpackCheckbox = $(this.element.unpackCheckbox);
        var embedCheckbox = $(this.element.embedCheckbox);
        var entry = {
            filename: filenameField.value,
            embed: embedCheckbox.checked,
            unpack: unpackCheckbox.checked,
            field: filenameField
        };

        this._queued_files.push(entry);
        filenameField.id = filenameField.id + '-' + this._sequence;
        this._sequence = this._sequence + 1;

        this._add_new_input();

        var holder = $(this.element.holder);
        holder.appendChild(filenameField);
        this._refresh_queue_list();
        return false;
    },

    _refresh_queue_list: function () {
        if (this._queued_files.length > 0) {
            var data = { queue: [] };
            for (var i=0; i < this._queued_files.length; i++)
                data.queue.push(this._queued_files[i].filename);
            this.jst.list.update(data);
            this.jst.list.show();
            Element.update(this.element.submitButton, 'Add another file');
            Element.update(this.element.embedMessage, 'Add links to these attachments at the top of the page? Images will appear in the page.');
            Element.update(this.element.unpackMessage, 'Expand zip archives and attach individual files to the page?');
            Element.update(this.element.message, 'Click "Browse" to find the file you want to upload. When you click "Add another file," these files will be added to the list of attachments for this page, and uploaded when you save the page.');
        }
        else {
            this.jst.list.clear();
            this.jst.list.hide();
            Element.update(this.element.submitButton, 'Add file');
            Element.update(this.element.embedMessage, 'Add a link to this attachment at the top of the page? Images will appear in the page.');
            Element.update(this.element.unpackMessage, 'Expand zip archive and attach individual files to the page?');
            Element.update(this.element.message, 'Click "Browse" to find the file you want to upload. When you click "Add file," this file will be added to the list of attachments for this page, and uploaded when you save the page.');
        }
        this._check_for_zip_file();
        return false;
    },

    remove_index: function (index) {
        this._queued_files.splice(index,1);
        this._refresh_queue_list();
    },

    reset_dialog: function () {
        this.clear_list();
        var embedCheckbox = $(this.element.embedCheckbox);
        embedCheckbox.checked = true;

    },

    _set_handlers_for_input: function () {
        if (! $(this.element.filename)) return;
        Event.observe(this.element.filename, 'blur',   this._check_for_zip_file.bind(this));
        Event.observe(this.element.filename, 'keyup',  this._check_for_zip_file.bind(this));
        Event.observe(this.element.filename, 'change', this._check_for_zip_file.bind(this));
    },

    _show_error: function (msg) {
        if (!msg)
            msg = '&nbsp;';
        Element.update(this.element.fileError, msg);
        $(this.element.fileError).style.display = 'block';
    },

    _update_uploaded_list: function (filename) {
        filename = filename.match(/^.+[\\\/]([^\\\/]+)$/)[1];
        this._uploaded_list.push(filename);
    },

    _loadInterface: function () {
        this.jst.list = new ST.TemplateField(this.element.listTemplate, this.element.fileList);

        if ($(this.element.editUploadButton)) {
            Event.observe(this.element.editUploadButton, 'click',  this._display_interface.bind(this));
        }
        if ($(this.element.closeButton)) {
            Event.observe(this.element.closeButton,      'click',  this._hide_interface.bind(this));
        }
        if ($(this.element.submitButton)) {
            Event.observe(this.element.submitButton,     'click',  this._queue_file.bind(this));
        }

        this._set_handlers_for_input();

        this._refresh_queue_list();
    }
};

// main
if (Socialtext.box_javascript) {
    window.EditQueue = new ST.AttachmentQueue ();
}
