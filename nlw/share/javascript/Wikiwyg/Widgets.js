/*
To Do:
- Clicking on widget produces unwanted stretchy-handles.

Refactor:

*/

Wikiwyg.is_ie7 = (
    Wikiwyg.is_ie &&
    Wikiwyg.ua.indexOf("7.0") != -1
);
Wikiwyg.Widgets.resolve_synonyms = function(widget) {
    for (var ii in Wikiwyg.Widgets.synonyms) {
        widget = widget.replace( new RegExp("^" + ii), Wikiwyg.Widgets.synonyms[ii]);
    }
    return widget;
}

Wikiwyg.Widgets.isMultiple = function(widget_id) {
    var nameMatch = new RegExp(widget_id + '\\d+$');
    for (var i = 0; i < Wikiwyg.Widgets.widgets.length; i++)
        if (Wikiwyg.Widgets.widgets[i].match(nameMatch))
            return true;
    return false;
}

Wikiwyg.Widgets.getFirstMultiple = function(widget_id) {
    var nameMatch = new RegExp(widget_id + '\\d+$');
    for (var i = 0; i < Wikiwyg.Widgets.widgets.length; i++)
        if (Wikiwyg.Widgets.widgets[i].match(nameMatch))
            return Wikiwyg.Widgets.widgets[i];
    return widget_id;
}

Wikiwyg.Widgets.mapMultipleSameWidgets = function(widget_parse) {
    var id = widget_parse.id;
    var strippedId = id.replace(/\d+$/, '');
    var nameMatch = new RegExp(strippedId + '\\d+$');
    var widgets_list = Wikiwyg.Widgets.widgets;
    for (var i = 0; i < widgets_list.length; i++) {
        var widget_name = widgets_list[i];
        if (widget_name.match(nameMatch)) {
            if (widget_data[widget_name].select_if) {
                var match = true;
                if (widget_data[widget_name].select_if.defined) {
                    for (var k = 0; k < widget_data[widget_name].select_if.defined.length; k++) {
                        if (!widget_parse[widget_data[widget_name].select_if.defined[k]])
                            match = false;
                    }
                }
                if (widget_data[widget_name].select_if.blank) {
                    for (var k = 0; k < widget_data[widget_name].select_if.blank.length; k++) {
                        if (widget_parse[widget_data[widget_name].select_if.blank[k]])
                            match = false;
                    }
                }
                if (match) {
                    id = widget_name;
                    break;
                }
            }
        }
    }

    return id;
}

// Shortcut globals.
Wikiwyg.Toolbar.Socialtext.prototype.setup_widgets = function() {
    this.setup_widgets_pulldown('Insert...');
}

var widgets_list = Wikiwyg.Widgets.widgets;
var widget_data = Wikiwyg.Widgets.widget;

proto = eval(WW_SIMPLE_MODE).prototype;

proto.enableThis = function() {
    Wikiwyg.Mode.prototype.enableThis.call(this);
    this.edit_iframe.style.border = '1px black solid';
    this.edit_iframe.width = '100%';
    this.setHeightOf(this.edit_iframe);
    this.fix_up_relative_imgs();
    this.get_edit_document().designMode = 'on';
    this.apply_stylesheets();
    this.enable_keybindings();
    this.clear_inner_html();
}

proto.fromHtml = function(html) {
    Wikiwyg.Wysiwyg.prototype.fromHtml.call(this, html);
    try {
        setTimeout(this.setWidgetHandlers.bind(this), 200);
    } catch(e) { alert('bleh: ' + e) }
}

proto.toHtml = function(func) {
    Wikiwyg.Wysiwyg.prototype.toHtml.call(this, func);
    clearInterval( this._fixer_interval_id );
    delete this._fixer_interval_id;

    /*
    if (Wikiwyg.is_ie7) {
        clearInterval( this._white_page_fixer_interval_id );
        delete this._white_page_fixer_interval_id;
    }
    */
}

proto.setWidgetHandlers = function() {
    var imgs = this.get_edit_document().getElementsByTagName('img');
    for (var ii = 0; ii < imgs.length; ii++) {
        this.setWidgetHandler(imgs[ii]);
    }
    this.revert_widget_images();
}

proto.setWidgetHandler = function(img) {
    var widget = img.getAttribute('widget');
    if (! widget) return;
    this.currentWidget = this.parseWidgetElement(img);
    this.currentWidget = this.setTitleAndId(this.currentWidget);
    this.attachTooltip(img);
}

proto.need_to_revert_widet = function(img) {
    var style = img.getAttribute("style");
    var has_style_attr = (typeof style == 'string')

    if (   has_style_attr
        || (img.getAttribute("mousedown") == 1)
        || (img.getAttribute("mouseup") == 0)
        || (img.getAttribute("mouseout") == 1)
        || (img.getAttribute("mouseover") == 0)
        || (img.getAttribute("src").match(/^\.\./))
        ) {
        return true;
    }
    return false;
}

proto.revert_widget_images = function() {
    if ( this._fixer_interval_id ) {
        return;
    }
    var self = this;
    var fixer = function() {
        var imgs = self.get_edit_document().getElementsByTagName('img');
        for (var i=0; i < imgs.length; i++) {
            var img = imgs[i];
            if (!img.getAttribute("widget")) { continue; }
            if (self.need_to_revert_widet(img)) {
                /*
                  This two height and width conditions is majorly for IE to revert
                  the image size correctly.
                */
                if ( img.getAttribute("height") ) { img.style.height = img.getAttribute("height") }
                if ( img.getAttribute("width") ) { img.removeAttribute("width"); }

                img.removeAttribute("style");
                img.removeAttribute("mouseup");
                img.removeAttribute("mousedown");
                img.removeAttribute("mouseover");
                img.removeAttribute("mouseout");

                self.attachWidgetHandlers(img);
            }
        }
        self.reclaim_element_registry_space();
    };
    this._fixer_interval_id = setInterval(fixer, 500);

    /*
    if (Wikiwyg.is_ie7) {
        this._white_page_fixer_interval_id = setInterval( function() {
            self.get_edit_document().body.style.display="";
            self.get_edit_document().body.style.display="block";
        }, 10);
    }
    */
}

proto.sanitize_dom = function(dom) {
    Wikiwyg.Wysiwyg.prototype.sanitize_dom.call(this, dom);
    this.widget_walk(dom);
}

proto.attachTooltip = function(elem) {
    if (elem.getAttribute("title"))
        return;

    var title = (typeof widget_data[this.currentWidget.id].title == "object")
      ? this.currentWidget.full
        ? widget_data[this.currentWidget.id].title.full
        : widget_data[this.currentWidget.id].title['default']
      : widget_data[this.currentWidget.id].title;

    var self = this;
    title = title.replace(/\$(\w+)/g, function() {
        var text = self.currentWidget[arguments[1]];
        if (text == '') {
            if (arguments[1] == 'page_title')
                text = Page.page_title;
            else if (arguments[1] == 'workspace_id')
                text = Page.wiki_title;
        }
        return text;
    });
    elem.setAttribute("title", title);

    this.attachWidgetHandlers(elem);
}

proto.attachWidgetHandlers = function(elem) {
    if ( !this.element_registry_push(elem) ) {
        return;
    }

    var self = this;
    DOM.Events.addListener(elem, 'mouseover', function(e) {
        e.target.setAttribute("mouseover", 1);
        e.target.setAttribute("mouseout", 0);
    });
    DOM.Events.addListener(elem, 'mouseout', function(e) {
        e.target.setAttribute("mouseover", 0);
        e.target.setAttribute("mouseout", 1);
    });

    DOM.Events.addListener(elem, 'mousedown', function(e) {
        e.target.setAttribute("mousedown", 1);
        e.target.setAttribute("mouseup", 0);
    });

    var id = this.currentWidget.id;
    if (widget_data[id] && widget_data[id].uneditable) {
        DOM.Events.addListener(elem, 'mouseup', function(e) {
            e.target.setAttribute("mousedown", 0);
            if ( e.target.getAttribute("mouseup") == 0 ) {
                if ( Wikiwyg.Widgets.widget_editing > 0 )
                    return;
                alert("This is not an editable widget. Please edit it in advanced mode.")
            }
            e.target.setAttribute("mouseup", 1);
        });
    }
    else {
        DOM.Events.addListener(elem, 'mouseup', function(e) {
            e.target.setAttribute("mousedown", 0);
            if ( e.target.getAttribute("mouseup") == 0 ) {
                if ( Wikiwyg.Widgets.widget_editing > 0 )
                    return;
                self.getWidgetInput(e.target, false, false);
            }
            e.target.setAttribute("mouseup", 1);
        });
    }
}

var wikiwyg_widgets_element_registry = new Array();
proto.reclaim_element_registry_space = function() {
    var imgs = this.get_edit_document().getElementsByTagName('img');
    for(var i = 0; i < wikiwyg_widgets_element_registry.length; i++ ) {
        var found = false;
        for (var j = 0; j < imgs.length; j++) {
            var img = imgs[j];
            if (!img.getAttribute("widget")) { continue; }
            if (wikiwyg_widgets_element_registry[i] == img) {
                found = true;
                break;
            }
        }
        if ( !found ) {
            delete wikiwyg_widgets_element_registry[i]
        }
    }
    wikiwyg_widgets_element_registry = wikiwyg_widgets_element_registry.compact();
}

proto.element_registry_push = function(elem) {
    var flag = 0;
    wikiwyg_widgets_element_registry.each(function(i) {
        if (i == elem) {
            flag++;
        }
    });
    if ( flag > 0 ) { return false; }
    wikiwyg_widgets_element_registry.push(elem)
    return true;
}

var wikiwyg_widgets_title_lookup = {
};

proto.titleInLoopup = function (field, id) {
    if (field in wikiwyg_widgets_title_lookup)
        if (id in wikiwyg_widgets_title_lookup[field])
            return wikiwyg_widgets_title_lookup[field][id];
    return '';
}

proto.pullTitleFromServer = function (field, id, data) {
    var uri = Wikiwyg.Widgets.api_for_title[field];
    uri = uri.replace(new RegExp(":" + field), id);

    var request = new Ajax.Request (
        uri,
        {
            method: 'GET',
            asynchronous: false,
            requestHeaders: ['Accept','application/json']
        }
    );
    if (request.transport.status == 404)
        return id;
    else {
        var details = JSON.parse(request.transport.responseText);
        if (!(field in wikiwyg_widgets_title_lookup))
            wikiwyg_widgets_title_lookup[field] = {};
        wikiwyg_widgets_title_lookup[field][id] = details.title;

        return details.title;
    }
}

proto.setTitleAndId = function (widget) {
    var widgetDefinition = widget_data[widget.id];
    var fields = widgetDefinition.fields || [widgetDefinition.field];

    for (var i=0; i < fields.length; i++) {
        var field = fields[i];
        if (Wikiwyg.Widgets.api_for_title[field]) {
            if (!widget.title_and_id) {
                widget.title_and_id = {};
            }
            if (!widget.title_and_id[field]) {
                widget.title_and_id[field] = {id: '', title: ''};
            }
            if (widget[field]) {
                var title = this.titleInLoopup(field, widget[field]);
                if (!title)
                    title = this.pullTitleFromServer(field, widget[field]);
                widget.title_and_id[field].id = widget[field];
                widget.title_and_id[field].title = title;
            }
        }
    }

    return widget;
}

proto.parseWidgetElement = function(element) {
    return this.parseWidget(element.getAttribute('widget'));
}

proto.parseWidget = function(widget) {
    var matches;

    if ((matches = widget.match(/^(aim|yahoo|ymsgr|skype|callme|callto|http|asap|irc|file|ftp|https):([\s\S]*?)\s*$/)) ||
        (matches = widget.match(/^\{(\{(.+)\})\}$/)) || // AS-IS
        (matches = widget.match(/^"(.+?)"<(.+?)>$/)) || // Named Links
        (matches = widget.match(/^(?:"(.*)")?\{(\w+):?\s*([\s\S]*?)\s*\}$/)) ||
        (matches = widget.match(/^\.(\w+)\s*?\n([\s\S]*?)\1\s*?$/))
    ) {
        var widget_id = matches[1];
        var full = false;
        var args = matches[2];

        var widget_label;
        if ( matches.length == 4 ) {
            widget_label = matches[1];
            widget_id = matches[2];
            args = matches[3];
        }

        if ( widget_id.match(/^\{/) ) {
            widget_id = "asis";
        }

        widget_id = Wikiwyg.Widgets.resolve_synonyms(widget_id);

        if (widget_id.match(/^(.*)_full$/)) {
            var widget_id = RegExp.$1;
            var full = true;
        }

        // Since multiple versions of the same widget have the same wafl
        // structure we can use the parser for any version. Might as well be the first.
        var isAMultipleWidget = Wikiwyg.Widgets.isMultiple(widget_id);
        if (isAMultipleWidget) {
            widget_id = Wikiwyg.Widgets.getFirstMultiple(widget_id);
        }

        var widget_parse;
        if (this['parse_widget_' + widget_id]) {
            widget_parse = this['parse_widget_' + widget_id](args);
            widget_parse.id = widget_id;
        }
        else if (widget_data[widget_id]) {
            widget_parse = {};
            widget_parse.id = widget_id;
        }
        else {
            widget_parse = {};
            widget_parse.id = 'unknown';
            widget_parse.unknown_id = widget_id;
        }

        widget_parse.full = full;
        widget_parse.widget = widget;
        if (widget_label)
            widget_parse.label = widget_label;

        if (isAMultipleWidget) {
            var previousId = widget_parse.id;
            widget_parse.id = Wikiwyg.Widgets.mapMultipleSameWidgets(widget_parse);
            if (widget_parse.id != previousId && this['parse_widget_' + widget_parse.widget_id]) {
                widget_parse = this['parse_widget_' + widget_parse.id](args);
                widget_parse.id = widget_id;
            }
        }

        return widget_parse;
    }
    else
        throw('Unexpected Widget >>' + widget + '<< in parseWidget');
}

for (var i = 0; i < widgets_list.length; i++) {
    var gen_widget_parser = function(data) {
        return function(widget_args) {
            var widget_parse = {};
            if (data.fields) {
                for (var i = 0; i < data.fields.length; i++) {
                    widget_parse[ data.fields[i] ] = '';
                }
            }
            else if (data.field) {
                widget_parse[ data.field ] = '';
            }
            if (! widget_args.match(/\S/)) {
                return widget_parse;
            }

            if (! (data.field || data.parse)) {
                data.field = data.fields[0];
            }

            if (data.field) {
                widget_parse[ data.field ] = widget_args;
                return widget_parse;
            }

            var widgetFields = data.parse.fields || data.fields;
            var regexp = data.parse.regexp;
            var regexp2 = regexp.replace(/^\?/, '');
            if (regexp != regexp2)
                regexp = Wikiwyg.Widgets.regexps[regexp2];
            var tokens = widget_args.match(regexp);
            if (tokens) {
                for (var i = 0; i < widgetFields.length; i++)
                    widget_parse[ widgetFields[i] ] = tokens[i+1];
            }
            else {
                if (data.parse.no_match)
                    widget_parse[ data.parse.no_match ] = widget_args;
            }
            if (widget_parse.search_term) {
                var term = widget_parse.search_term;
                var term2 = term.replace(/^(tag|category|title):/, '');
                if (term == term2) {
                    widget_parse.search_type = 'text';
                }
                else {
                    widget_parse.search_type = RegExp.$1;
                    if (widget_parse.search_type == 'tag')
                        widget_parse.search_type = 'category';
                    widget_parse.search_term = term2;
                }
            }
            return widget_parse;
        }
    }

    var gen_do_widget = function(w) {
        return function() {
            try {
                this.currentWidget = this.parseWidget('{' + w + ': }');
                this.currentWidget = this.setTitleAndId(this.currentWidget);
                var selection = this.get_selection_text();
                selection = selection.replace(/\\s+$/,'');
                this.getWidgetInput(this.currentWidget, selection, true);
            } catch (E) {
                // ignore error from parseWidget
            }
        }
    };

    var widget = widgets_list[i];
    proto['parse_widget_' + widget] = gen_widget_parser(widget_data[widget]);
    proto['do_widget_' + widget] = gen_do_widget(widget);
}

proto.widget_walk = function(elem) {
    for (var part = elem.firstChild; part; part = part.nextSibling) {
        if (part.nodeType != 1) continue;
        if (part.nodeName == 'SPAN' || part.nodeName == 'DIV') {
            var name = part.className;
            if (name && name.match(/(nlw_phrase|wafl_block)/)) {
                part = this.replace_widget(part);
            }
        }
        this.widget_walk(part);
    }
}

proto.replace_widget = function(elem) {
    var comment = elem.lastChild;
    if (comment.nodeType != 8) return;
    if (! comment.nodeValue.match(/^\s*wiki:/)) return;
    var widget = comment.nodeValue.replace(/^\s*wiki:\s*([\s\S]*?)\s*$/, '$1');
    widget = widget.replace(/-=/g, '-');

    var widget_image = Wikiwyg.createElementWithAttrs('img',
        {
            'src': this.getWidgetImageUrl(widget),
            'widget': widget
        }
    );
    elem.parentNode.replaceChild(widget_image, elem);
    return widget_image;
}

proto.insert_widget = function(widget, widget_element) {
    var html = '<img src="' + this.getWidgetImageUrl(widget) +
        '" widget="' + widget.replace(/"/g,"&quot;") + '" />';

    var self = this;
    var docbody = this.get_edit_document().body;

    var changer = function() {
        try {
            if ( widget_element ) {
                if ( widget_element.parentNode ) {
                    var div = self.get_edit_document().createElement("div");
                    div.innerHTML = html;
                    widget_element.parentNode.replaceChild(div.firstChild, widget_element);
                }
                else {
                    self.insert_html(html);
                }
            }
            else {
                self.insert_html(html);
            }
            self.setWidgetHandlers();
        }
        catch(e) {
            setTimeout(changer, 100);
        }
    }

    this.get_edit_window().focus();
    docbody.focus();
    changer();
}

proto.getWidgetImageText = function(widget_text) {
    var text = widget_text;
    try {
        var widget = this.parseWidget(widget_text);

        // XXX Hack for html block. Should key off of 'uneditable' flag.
        if (widget_text.match(/^\.html/))
            text = widget_data.html.title;
        else if (widget.id && widget_data[widget.id].image_text) {
            for (var i=0; i < widget_data[widget.id].image_text.length; i++) {
                if (widget_data[widget.id].image_text[i].field == 'default') {
                    text = widget_data[widget.id].image_text[i].text;
                    break;
                }
                else if (widget[widget_data[widget.id].image_text[i].field]) {
                    text = widget_data[widget.id].image_text[i].text;
                    break;
                }
            }
        }

        var fields = text.match(new RegExp('%\\S+', 'g'));
        if (fields)
            for (var i=0; i < fields.length; i++) {
                var field = fields[i].slice(1);
                if (widget[field])
                    text = text.replace(new RegExp('%' + field), widget[field]);
                else
                    text = text.replace(new RegExp('%' + field), '');
            }
    }
    catch (E) {
        // parseWidget can throw an error
        // Just ignore and set the text to be the widget text
    }

    return text;
}

proto.getWidgetImageUrl = function(widget_text) {
    var md5 = MD5(this.getWidgetImageText(widget_text));
    var url = nlw_make_static_path('/images/widgets/' + md5 + '.png');
    return url;
}

proto.create_wafl_string = function(widget, form) {
    var data = widget_data[widget];
    var result = data.pattern || '{' + widget + ': %s}';

    var fields =
        data.field ? [ data.field ] :
        data.fields ? data.fields :
        [];
    var values = this.form_values(widget, form);
    for (var j = 0; j < fields.length; j++) {
        var token = new RegExp('%' + fields[j]);
        result = result.replace(token, values[fields[j]]);
    }

    result = result.
        replace(/^\"\s*\"/, '').
        replace(/\[\s*\]/, '').
        replace(/\<\s*\>/, '').
        replace(/\s;\s/, ' ').
        replace(/\s\s+/g, ' ').
        replace(/^\{(\w+)\: \}$/,'{$1}');
    if (values.full)
        result = result.replace(/^(\{\w+)/, '$1_full');
    return result;
}

for (var i = 0; i < widgets_list.length; i++) {
    var widget = widgets_list[i];
    var gen_handle = function(widget) {
        return function(form) {
            var values = this.form_values(widget, form);
            this.validate_fields(widget, values);
            return this.create_wafl_string(widget, form);
        };
    };
    proto['handle_widget_' + widget] = gen_handle(widget);
}

proto.form_values = function(widget, form) {
    var data = widget_data[widget];
    var fields =
        data.field ? [ data.field ] :
        data.fields ? data.fields :
        [];
    var values = {};

    for (var i = 0; i < fields.length; i++) {
        var value = '';

        if (this.currentWidget.title_and_id && this.currentWidget.title_and_id[fields[i]] && this.currentWidget.title_and_id[fields[i]].id)
            value = this.currentWidget.title_and_id[fields[i]].id;
        else
            value = form[fields[i]].value.
                replace(/^\s*/, '').
                replace(/\s*$/, '');
        if (form['st-widget-' + fields[i] + '-rb']) {
            var whichValue = ST.getRadioValue('st-widget-' + fields[i] + '-rb');
            if (whichValue == 'current') {
                value = '';
            }
        }
        values[fields[i]] = value;
    }
    if (values.label) {
        values.label = values.label.replace(/^"*/, '').replace(/"*$/, '');
    }
    if (values.search_term) {
        var type = this.get_radio(form.search_type);
        if (type && type.value != 'text')
            values.search_term = type.value + ':' + values.search_term;
    }
    values.full = (form.full && form.full.checked);

    return values;
}

proto.get_radio = function(elem) {
    if (!(elem && elem.length)) return;
    for (var i = 0; i <= elem.length; i++) {
        if (elem[i].checked)
            return elem[i];
    }
}

proto.validate_fields = function(widget, values) {
    var data = widget_data[widget];
    var required = data.required || (data.field ? [data.field] : null);
    if (required) {
        for (var i = 0; i < required.length; i++) {
            var field = required[i];
            if (! values[field].length) {
                var label = Wikiwyg.Widgets.fields[field];
                throw("'" + label + "' is a required field");
            }
        }
    }

    var require = data.require_one;
    if (require) {
        var found = 0;
        labels = [];
        for (var i = 0; i < require.length; i++) {
            var field = require[i];
            labels.push(Wikiwyg.Widgets.fields[field]);
            if (values[field].length)
                found++;
        }
        if (! found)
            throw("Requires one of: " + labels.join(', '));
    }

    for (var field in values) {
        var regexp = Wikiwyg.Widgets.match[field];
        if (! regexp) continue;
        if (! values[field].length) continue;
        var fieldOk = true;
        if (this.currentWidget.title_and_id && this.currentWidget.title_and_id[field])
            fieldOk = this.currentWidget.title_and_id[field].id.match(regexp);
        else
            fieldOk = values[field].match(regexp);

        if (!fieldOk) {
            var label = Wikiwyg.Widgets.fields[field];
            throw("'" + label + "' has an invalid value");
        }
    }

    var checks = data.checks;
    if (checks) {
        for (var i = 0; i < checks.length; i++) {
            var check = checks[i];
            this[check].call(this, values);
        }
    }
}

proto.require_page_if_workspace = function(values) {
    if (values.workspace_id.length && ! values.page_title.length)
        throw("Page Title required if Workspace Id specified");
}

proto.hookLookaheads = function(dialog) {
    var cssSugestionWindow = 'st-widget-lookaheadsuggestionwindow';
    var cssSuggestionBlock = 'st-widget-lookaheadsuggestionblock';
    var cssSuggestionText = 'st-widget-lookaheadsuggestion';

    if ($('st-widget-workspace_id')) {
        window.workspaceLookahead = new WorkspaceLookahead(
            dialog,
            'st-widget-workspace_id',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'workspaceLookahead',
            this.currentWidget
        );
    }

    if ($('st-widget-page_title')) {
        window.pageLookahead = new PageNameLookahead(
            dialog,
            'st-widget-page_title',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'pageLookahead',
            this.currentWidget
        );
        window.pageLookahead.defaultWorkspace = Socialtext.wiki_id;
    }

    if ($('st-widget-tag_name')) {
        window.tagLookahead = new TagLookahead(
            dialog,
            'st-widget-tag_name',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'tagLookahead',
            this.currentWidget
        );
        window.tagLookahead.defaultWorkspace = Socialtext.wiki_id;
    }

    if ($('st-widget-weblog_name')) {
        window.weblogLookahead = new WeblogLookahead(
            dialog,
            'st-widget-weblog_name',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'weblogLookahead',
            this.currentWidget
        );
        window.weblogLookahead.defaultWorkspace = Socialtext.wiki_id;
    }

    if ($('st-widget-section_name')) {
        window.sectionNameLookahead = new PageSectionLookahead(
            dialog,
            'st-widget-section_name',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'sectionNameLookahead',
            this.currentWidget,
            'st-widget-page_title'
        );
        window.sectionNameLookahead.defaultWorkspace = Socialtext.wiki_id;
        window.sectionNameLookahead.defaultPagename = $('st-page-editing-pagename').value;
    }

    if ($('st-widget-image_name')) {
        window.imageNameLookahead = new PageAttachmentLookahead(
            dialog,
            'st-widget-image_name',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'imageNameLookahead',
            widget,
            'st-widget-page_title'
        );
        window.imageNameLookahead.defaultWorkspace = Socialtext.wiki_id;
        window.imageNameLookahead.defaultPagename = $('st-page-editing-pagename').value;
    }

    if ($('st-widget-file_name')) {
        window.fileNameLookahead = new PageAttachmentLookahead(
            dialog,
            'st-widget-file_name',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'fileNameLookahead',
            widget,
            'st-widget-page_title'
        );
        window.fileNameLookahead.defaultWorkspace = Socialtext.wiki_id;
        window.fileNameLookahead.defaultPagename = $('st-page-editing-pagename').value;
    }
}

Wikiwyg.Widgets.widget_editing = 0;

proto.getWidgetInput = function(widget_element, selection, new_widget) {
    if ( Wikiwyg.Widgets.widget_editing > 0 )
        return;
    Wikiwyg.Widgets.widget_editing++;

    if ( widget_element.nodeName ) {
        this.currentWidget = this.parseWidgetElement(widget_element);
        this.currentWidget = this.setTitleAndId(this.currentWidget);
        this.currentWidget.element = widget_element;
    }
    else {
        this.currentWidget = widget_element;
    }

    var widget = this.currentWidget.id;

    var template = 'widget_' + widget + '_edit.html';
    var html = Jemplate.process(template, this.currentWidget);

    var box = new Widget.Lightbox({contentClassName: 'jsan-widget-lightbox-content-wrapper', wrapperClassName: 'st-lightbox-dialog'});
    box.content( html );
    box.effects('RoundedCorners');
    box.create();

    this.hookLookaheads(box.divs.contentWrapper);

    var self = this;
    // XXX - Had to resort to this because we couldn't figure out how to
    // inspect which button got clicked. Possibly refactor.
    var callback = function(element) {
        if (Wikiwyg.is_ie) {
            wikiwyg.toolbarObject.styleSelect.style.display="none"
        }

        var form = element.getElementsByTagName('form')[0];

        var onreset = function() {
            clearInterval(intervalId);
            box.releaseFocus();
            box.release();
            Wikiwyg.Widgets.widget_editing--;
            return false;
        }
        var onsubmit = function() {
            var error = null;
            try {
                var widget_string = self['handle_widget_' + widget](form);
                var widget_text = self.getWidgetImageText(widget_string);
                clearInterval(intervalId);
                Ajax.post(
                    location.pathname,
                    'action=wikiwyg_generate_widget_image;' +
                    'widget=' + encodeURIComponent(widget_text) +
                    ';widget_string=' + encodeURIComponent(widget_string),
                    function() {
                        self.insert_widget(widget_string, widget_element);
                        box.release();
                        if (Wikiwyg.is_ie)
                            wikiwyg.toolbarObject.styleSelect.style.display = "";
                    }
                );
            }
            catch(e) {
                error = String(e);
                var div = document.getElementById(
                    widget + '_widget_edit_error_msg'
                );
                if (div) {
                    div.style.display = 'block';
                    div.innerHTML = '<span>' + error + '</span>';
                }
                else {
                    alert(error);
                }
                if (Wikiwyg.is_ie)
                    wikiwyg.toolbarObject.styleSelect.style.display = "";
                Wikiwyg.Widgets.widget_editing--;
                return false;
            }
            Wikiwyg.Widgets.widget_editing--;
            return false;
        }
        var i = 0;
        var set_wafl_text = function() {
            var td = document.getElementById(widget + '_wafl_text');
            if (td) {
                var t =
                    ' <span>' +
                    self.create_wafl_string(widget, form).
                        replace(/</g, '&lt;') +
                    '</span> ';
                td.innerHTML = t;
            }
        }

        form.onreset = onreset;
        form.onsubmit = onsubmit;

        box.restrictFocus(form);

        var data = widget_data[widget];
        var primary_field =
            data.primary_field ||
            data.field ||
            (data.required && data.required[0]) ||
            data.fields[data.fields.length - 1];
        if (new_widget && selection) {
            selection = selection.replace(
                /^<DIV class=wiki>([^\n]*?)(?:&nbsp;)*<\/DIV>$/mg, '$1'
            ).replace(
                /<DIV class=wiki>\r?\n<P><\/P><BR>([\s\S]*?)<\/DIV>/g, '$1'
            ).replace(/<BR>/g,'');

            form[primary_field].value = selection;
        }

        setTimeout(function() {try {form[primary_field].focus()} catch(e) {}}, 100);
        var intervalId = setInterval(set_wafl_text.bind(this), 500);
    }

    box.show(callback);
}

Widget.Lightbox.prototype.restrictFocus = function(form) {
    this._focusd_form = form;

    // Need to get a list of any tag that can get focus: e.g. input and anchors
    var inputs = new Array(form.getElementsByTagName("input"));
    inputs.concat(form.getElementsByTagName("a"));

    var focused = false ;
    var total_fields = inputs.length;

    for( var ii=0; ii < inputs.length; ii++ ) {
        inputs[ii].onfocus = function() {
            focused = true;
        };
        inputs[ii].onblur = function(idx) {
            return function(e) {
                focused = false;
                setTimeout( function() {
                    // XXX Need to check for visible fields
                    if ( !focused ) {
                        inputs[idx].focus();
                    }
                }, 30);
            }
        }(ii);
    }
}

Widget.Lightbox.prototype.releaseFocus = function(form){
    if ( !form ) form = this._focusd_form;
    if ( !form ) return;
    var inputs = form.getElementsByTagName("input");
    for( var ii=0; ii < inputs.length; ii++ ) {
        var _ = inputs[ii];
        _.onfocus = function() {};
        _.onblur  = function() {};
    }
}

Widget.Lightbox.prototype.applyHandlers = function(){
    if(!this.div)
        return;

    var self = this;
    if (Widget.Lightbox.is_ie) {
        DOM.Events.addListener(window, "resize", function () {
            self.applyStyle();
        });
    }

    if ($('st-widgets-moreoptions')) {
        DOM.Events.addListener(document.getElementById('st-widgets-moreoptions'), 'click', function () {
            self.toggleOptions();
        });
    }
}

Widget.Lightbox.prototype.toggleOptions = function() {
    var link = document.getElementById('st-widgets-moreoptions');
    var panel = document.getElementById('st-widgets-moreoptionspanel');
    var icon = document.getElementById('st-widgets-optionsicon');
    if (panel) {
        if (link.innerHTML == 'More options') {
            panel.style.display = "block";
            link.innerHTML = 'Fewer options';
            icon.src = nlw_make_static_path('/images/st/hide_more.gif');
        }
        else {
            panel.style.display = "none";
            link.innerHTML = 'More options';
            icon.src = nlw_make_static_path('/images/st/show_more.gif');
        }
    }
}

Widget.Lightbox.prototype.release = function() {
    /**
     * What we would prefer to do is remove the entire lighbox from the DOM
     * but IE does not handle the delete well. So, instead, we delete everything
     * inside the wrapper. That way we get rid of the controls that- have unique
     * IDs so the rest of the code will work properly.
     */
    this.div.removeChild(this.divs.contentWrapper);
    this.div.removeChild(this.divs.background);
    this.hide();
}

Widget.Lightbox.prototype.hide = function() {
    if (!this.div.parentNode) return;
    this.div.style.display="none";
    if (Widget.Lightbox.is_ie) {
        document.body.scroll="yes"
    }
    this.releaseFocus();

    if (Wikiwyg.is_ie) {
        wikiwyg.toolbarObject.styleSelect.style.display=""
    }
}

eval(WW_ADVANCED_MODE).prototype.setup_widgets = function() {
    var widgets_list = Wikiwyg.Widgets.widgets;
    var widget_data = Wikiwyg.Widgets.widget;
    var p = eval(this.classname).prototype;
    for (var i = 0; i < widgets_list.length; i++) {
        var widget = widgets_list[i];
        p.markupRules['widget_' + widget] =
            widget_data[widget].markup ||
            ['bound_phrase', '{' + widget + ': ', '}'];
        p['do_widget_' + widget] = Wikiwyg.Wikitext.make_do('widget_' + widget);
    }
}

proto = eval(WW_ADVANCED_MODE).prototype;

proto.format_img = function(element) {
    var widget = element.getAttribute('widget');
    if (! widget) {
        return Wikiwyg.Wikitext.prototype.format_img.call(this, element);
    }

    if ( widget.match(/^\{include/) ) {
        this.treat_include_wafl(element);
    } else if ( widget.match(/^\.\w+\n/) ) {
        this.assert_blank_line();
    } else {
        this.assert_space_or_newline();
    }

    widget = widget.replace(/-=/g, '-').replace(/==/g,'=').replace(/&quot;/g,'"').replace(/&lt;/g,'<').replace(/&gt;/g,'>');
    this.appendOutput(widget);
    this.smart_trailing_space(element);
}

proto.format_a = function(element) {
    if (this.is_opaque(element))
        return this.handle_wafl_block(element);

    Wikiwyg.Wikitext.prototype.format_a.call(this, element);
}

proto.format_div = function(element) {
    if (this.is_opaque(element))
        return this.handle_wafl_block(element);

    Wikiwyg.Wikitext.prototype.format_div.call(this, element);
}

proto.destroyPhraseMarkup = function(element) {
    if (this.contain_widget_image(element))
        return false;
    if (this.start_is_no_good(element) || this.end_is_no_good(element)) {
        return this.destroyElement(element);
    }
    return false;
}

proto.contain_widget_image = function(element) {
    for(var ii = 0; ii < element.childNodes.length; ii++ ) {
        var e = element.childNodes[ii]
        if ( e.nodeType == 1 ) {
            if ( e.nodeName == 'IMG' ) {
                if ( e.getAttribute("widget") )
                    return true;
            }
        }
    }
}

proto.treat_include_wafl = function(element) {
    // Note: element should be a <span> or an <img>

    if ( element.nodeType != 1 )
        return;

    if ( element.nodeName == 'SPAN' ) {
        var inner = element.innerHTML;
        if(!inner.match(/<!-- wiki: \{include: \[.+\]\} -->/)) {
            return;
        }
    }
    else if ( element.nodeName == 'IMG' ) {
        var widget = element.getAttribute("widget");
        if (!widget.match(/^\{include/))
            return;
    }

    // If this is a {include} widget, we squeeze
    // whitepsaces before and after it. Becuase
    // {include} is supposed to be in a <p> of it's own.
    // If user type "{include: Page} Bar", that leaves
    // an extra space in <p>.

    var next = element.nextSibling;
    if (next && next.tagName &&
            next.tagName.toLowerCase() == 'p') {
        next.innerHTML = next.innerHTML.replace(/^ +/,"");
    }

    var prev = element.previousSibling;
    if (prev
        && prev.tagName
        && prev.tagName.toLowerCase() == 'p') {
        if (prev.innerHTML.match(/^[ \n\t]+$/)) {
            // format_p is already called, so it's too late
            // to do this:
            //     prev.parentNode.removeChild( prev );

            // Remove two blank lines for it's the output
            // of an empty <p>
            var line1 = this.output.pop();
            var line2 = this.output.pop();
            // But if they are not newline, put them back
            // beause we don't want to mass around there.
            if ( line1 != "\n" || line2 != "\n" ) {
                this.output.push(line2);
                this.output.push(line1);
            }
        }
    }
}

proto.handle_bound_phrase = function(element, markup) {
    if (! this.element_has_only_image_content(element) )
        if (! this.element_has_text_content(element))
            return;

    if (element.innerHTML.match(/^\s*<br\s*\/?\s*>/)) {
        this.appendOutput("\n");
        element.innerHTML = element.innerHTML.replace(/^\s*<br\s*\/?\s*>/, '');
    }
    this.appendOutput(markup[1]);
    this.no_following_whitespace();
    this.walk(element);
    this.appendOutput(markup[2]);
}

proto.markup_bound_phrase = function(markup_array) {
    var markup_start = markup_array[1];
    markup_start = markup_start.replace(/\d+: $/, ': ');
    var markup_finish = markup_array[2];
    var scroll_top = this.area.scrollTop;
    if (markup_finish == 'undefined')
        markup_finish = markup_start;
    if (this.get_words())
        this.add_markup_words(markup_start, markup_finish, null);
    this.area.scrollTop = scroll_top;
}
