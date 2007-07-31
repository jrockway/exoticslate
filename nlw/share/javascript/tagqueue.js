if (typeof ST == 'undefined') {
    ST = {};
}

// ST.Attachments class
ST.TagQueue = function (args) {
    $H(args).each(this._applyArgument.bind(this));

    Event.observe(window, 'load', this._loadInterface.bind(this));
};


ST.TagQueue.prototype = {
    _queued_tags: [],
    suggestionRE: '',
    workspaceTags: [],

    element: {
        workspaceTags:      'st-tags-workspace',
        queueInterface:     'st-tagqueue-interface',

        editTagButton:      'st-edit-mode-tagbutton',
        submitButton:       'st-tagqueue-submitbutton',
        closeButton:        'st-tagqueue-closebutton',

        tagList:            'st-tagqueue-list',
        listTemplate:       'st-tagqueue-listtemplate',

        suggestions:        'st-tagqueue-suggestion',
        suggestionList:     'st-tagqueue-suggestionlist',
        suggestionTemplate: 'st-tagqueue-suggestiontemplate',

        holder:             'st-tagqueue-holder',

        tagField:           'st-tagqueue-field',
        message:            'st-tagqueue-message',
        error:              'st-tagqueue-error'
    },

    socialtextModifiers: {
        escapespecial : function(str) {
            var escapes = [
                { regex: /'/g, sub: "\\'" },
                { regex: /\n/g, sub: "\\n" },
                { regex: /\r/g, sub: "\\r" },
                { regex: /\t/g, sub: "\\t" }
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
            s = t.name;
            for (var i=0; i < escapes.length; i++)
                s = s.replace(escapes[i].regex, escapes[i].sub);
            return s;
        }
    },

    jst: {
        list: '',
        suggestion: ''
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _hide_error: function () {
        Element.update(this.element.error, '&nbsp;');
        Element.hide(this.element.error);
    },

    clear_list: function () {
        this._queued_tags = [];
        this._refresh_queue_list();
    },

    _display_interface: function () {
        field = $(this.element.tagField);
        Try.these(function () {
            field.value = '';
        });

        this.workspaceTags  = JSON.parse($(this.element.workspaceTags).value);

        $(this.element.queueInterface).style.display = 'block';
        this._center_lightbox(this.element.queueInterface);
        this._refresh_queue_list();
        field.focus();
        return false;
    },

    _center_lightbox: function (parentElement) {
        var overlayElement = $('st-tagqueue-overlay');
        var element = $('st-tagqueue-dialog');
        Widget.Lightbox.show({
            divs: {
                wrapper: $(parentElement),
                background: overlayElement,
                contentWrapper: element.parentNode,
                content: element
            },
            effects: ['RoundedCorners']
        });
    },

    count: function () {
        return this._queued_tags.length;
    },

    tag: function (index) {
        return this._queued_tags[index];
    },

    _find_suggestions: function () {
        var field = $(this.element.tagField);

        if (field.value.length == 0) {
            Element.hide(this.element.suggestions);
        } else {
            if (this.workspaceTags.tags) {
                var expression = field.value;
                if (field.value.search(/ /) == -1) {
                    expression = '\\b'+expression;
                }
                this.suggestionRE = new RegExp(expression,'i');
                var suggestions = {
                    matches : this.workspaceTags.tags.grep(this.matchTag.bind(this))
                };
                Element.setStyle(this.element.suggestions, {display: 'block'});
                if (suggestions.matches.length > 0) {
                    suggestions._MODIFIERS = this.socialtextModifiers;
                    this.jst.suggestion.update(suggestions);
                } else {
                    var help = '<span class="st-tagqueue-nomatch">' + loc("No matches") + '</span>';
                    this.jst.suggestion.set_text(help);
                }
            }
        }
    },

    _hide_interface: function () {
        $(this.element.queueInterface).style.display = 'none';
        return false;
    },

    _clear_field: function () {
        var tag_field = $(this.element.tagField);
        tag_field.value = '';
        this._refresh_queue_list();
        Element.hide(this.element.suggestions);
        tag_field.focus();
        return false;
    },

    queue_tag: function (tag) {
        if (! tag) {
            this._show_error(loc('No tag entered'));
            return false;
        }
        this._queued_tags.push(tag);

        return this._clear_field();
    },

    _queue_tag: function () {
        var tag_field = $(this.element.tagField);
        return this.queue_tag(tag_field.value);
    },

    _refresh_queue_list: function () {
        if (this._queued_tags.length > 0) {
            var data = { queue: [] };
            for (var i=0; i < this._queued_tags.length; i++)
                data.queue.push(this._queued_tags[i]);
            this.jst.list.update(data);
            this.jst.list.show();
            Element.update(this.element.submitButton, loc('Add another tag'));
            Element.update(this.element.message, loc('Enter a tag and click "Add another tag". The tag will be saved when you save the page.'));
        }
        else {
            this.jst.list.clear();
            this.jst.list.hide();
            Element.update(this.element.submitButton, loc('Add tag'));
            Element.update(this.element.message, loc('Enter a tag and click "Add tag". The tag will be saved when you save the page.'));
        }
        this._hide_error();
        return false;
    },

    remove_index: function (index) {
        this._queued_tags.splice(index,1);
        this._refresh_queue_list();
    },

    reset_dialog: function () {
        this.clear_list();
    },

    matchTag: function (tag) {
        if (typeof tag.name == 'number') {
            var s = tag.name.toString();
            return s.search(this.suggestionRE) != -1;
        } else {
            return tag.name.search(this.suggestionRE) != -1;
        }
    },

    _set_first_matching_suggestion: function () {
        var field = $(this.element.tagField);

        if (field.value.length > 0) {
            var suggestions = this.workspaceTags.tags.grep(this.matchTag.bind(this));
            if ((suggestions.length >= 1) && (field.value != suggestions[0].name)) {
                field.value = suggestions[0].name;
                return false;
            }
        }
        return true;
    },

    tagFieldKeyHandler: function (event) {
        var e = event || window.event;
        var key = e.charCode || e.keyCode;

        if (key == Event.KEY_RETURN) {
            this._queue_tag();
            return false;
        }
        else if (key == Event.KEY_TAB) {
            var ret = this._set_first_matching_suggestion();
            try {
                event.preventDefault();
            }
            catch(e) {
            }
            try {
                event.stopPropagation();
            }
            catch(e) {
            }
            return ret;
        }
    },

    _show_error: function (msg) {
        if (!msg)
            msg = '&nbsp;';
        Element.update(this.element.error, msg);
        $(this.element.error).style.display = 'block';
    },

    _loadInterface: function () {
        this.jst.list = new ST.TemplateField(this.element.listTemplate, this.element.tagList);
        this.jst.suggestion = new ST.TemplateField(this.element.suggestionTemplate, this.element.suggestionList);

        if ($(this.element.editTagButton)) {
            Event.observe(this.element.editTagButton, 'click', this._display_interface.bind(this));
        }
        if ($(this.element.closeButton)) {
            Event.observe(this.element.closeButton, 'click', this._hide_interface.bind(this));
        }
        if ($(this.element.submitButton)) {
            Event.observe(this.element.submitButton, 'click', this._queue_tag.bind(this));
        }

        if ($(this.element.tagField)) {
            Event.observe(this.element.tagField, 'keyup', this._find_suggestions.bind(this));
            Event.observe(this.element.tagField, 'keydown', this.tagFieldKeyHandler.bind(this));
        }

        this._refresh_queue_list();
   }

};
