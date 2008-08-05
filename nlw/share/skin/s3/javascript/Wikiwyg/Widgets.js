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
proto = Wikiwyg.Toolbar.Socialtext.prototype;

proto.setup_widgets = function() {
    this.setup_widgets_menu(loc('Insert'));
}

proto.setup_widgets_menu = function(title) {
    jQuery("#st-editing-insert-menu > li")
        .find("li:has('ul') > a")
        .addClass('daddy');
    if (jQuery.browser.msie) {
        jQuery("#st-editing-insert-menu li")
            .hover(
                function () { jQuery(this).addClass('sfhover') }, 
                function () { jQuery(this).removeClass('sfhover') }
            );
    }

    var self = this;
    jQuery("#st-editing-insert-menu > li > ul a").click(
        function(e) {
            var action = jQuery(this).attr("do");
            if (action == null) {
                return false;
            }

            if (jQuery.isFunction( self.wikiwyg.current_mode[action] ) ) {
                if (jQuery.browser.msie &&
                    self.wikiwyg.current_mode.get_editable_div
                ) {
                    jQuery( self.wikiwyg.current_mode.get_editable_div() )
                        .focus();
                }

                self.wikiwyg.current_mode[action]
                    .apply(self.wikiwyg.current_mode);

                self.focus_link_menu(action, e.target.innerHTML)

                return false;
            }

            var self2 = this;
            setTimeout(function() {
                alert("'" +
                    jQuery(self2).text() +
                    "' is not supported in this mode"
                );
            }, 50);
            return false;
        }
    );
}

proto.focus_link_menu = function(action, label) {
    if (! (action == 'do_widget_link2' &&
        label.match(/^(Wiki|Web|Section)/)
    )) return;

    type = RegExp.$1.toLowerCase();
    jQuery("#add-" + type + "-link")
        .attr("checked", "checked");
    jQuery("#add-" + type + "-link-section")
        .find('input[type="text"]:eq(0)').focus().end()
        .find('input[type="text"][value]:eq(0)').focus().select();
}

var widgets_list = Wikiwyg.Widgets.widgets;
var widget_data = Wikiwyg.Widgets.widget;

proto = eval(WW_SIMPLE_MODE).prototype;

proto.fromHtml = function(html) {
    // TODO Move this to Wikiwyg.Wysiwyg
    if (Wikiwyg.is_ie) {
        html = html.replace(/<DIV class=wiki>([\s\S]*)<\/DIV>/gi, "$1");

        var br_at_the_end = new RegExp("(\n?<br ?/>)+$", "i");
        if(html.match(br_at_the_end)) {
            html = html.replace(br_at_the_end, "")
            html += "<p> </p>"
        }
        html = this.assert_padding_between_block_elements(html);
    }
    else {
        html = this.replace_p_with_br(html);
    }

    Wikiwyg.Wysiwyg.prototype.fromHtml.call(this, html);
    try {
        setTimeout(this.setWidgetHandlers.bind(this), 200);
    } catch(e) { alert('bleh: ' + e) }
}

proto.assert_padding_between_block_elements = function(html) {
    var doc = document.createElement("div");
    doc.innerHTML = html;
    if (doc.childNodes.length == 1) {
        var h = doc.childNodes[0].innerHTML
        doc.innerHTML = h
    }

    var node_is_a_block = function(node) {
        if (node.nodeType == 1) {
            var tag = node.tagName.toLowerCase();
            if (tag.match(/^(ul|ol|table|blockquote|p)$/)) return true;
            if (tag == 'span' && node.className == 'nlw_phrase') {
                if (!(node.lastChild.nodeValue||"").match("include:")) {
                    return true;
                }
            }
        }
        return false;
    };

    for(var i = 1; i < doc.childNodes.length; i++) {
        if ( node_is_a_block(doc.childNodes[i]) ) {
            if ( node_is_a_block(doc.childNodes[i-1]) ) {
                var padding = document.createElement("p");
                padding.setAttribute("class", "padding");
                padding.innerHTML='&nbsp;';
                doc.insertBefore(padding, doc.childNodes[i]);
                i++;
            }
        }
    }

    return doc.innerHTML;
}

proto.replace_p_with_br = function(html) {
    var br = "<br class=\"p\"/>";
    var doc = document.createElement("div");
    doc.innerHTML = html;
    var p_tags = doc.getElementsByTagName("p");
    for(var i=0;i<p_tags.length;i++) {
        var html = p_tags[i].innerHTML;
        var prev = p_tags[i].previousSibling;
        if (prev && prev.tagName) {
            var prev_tag = prev.tagName.toLowerCase();
        }

        html = html.replace(/(<br>)?\s*$/, br + br);
        if (prev && prev_tag && prev_tag != 'br' && prev_tag != 'p') {
            html = html.replace(/^\n?/,br)
        }
        else if (prev && prev_tag && prev_tag == 'br') {
            html = html.replace(/^\n?/,'')

            var remove_br = function() {
                var ps = prev.previousSibling;
                while (ps && ps.nodeType == 3) {
                    ps = ps.previousSibling;
                }
                if (ps && ps.tagName &&
                    ps.tagName.toLowerCase() == 'blockquote') {
                    return true;
                }
                return false;
            }();

            if (remove_br) {
                prev.parentNode.removeChild(prev);
            }
        }
        else {
            html = html.replace(/^\n?/,'')
        }

        if (prev && prev.nodeType == 3) {
            prev.nodeValue = prev.nodeValue.replace(/\n*$/,'')
        }

        jQuery(p_tags[i]).before(html);
        p_tags[i].parentNode.removeChild(p_tags[i]);
    }
    return doc.innerHTML;
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

    var params = title.match(/\$(\w+)/g);
    var newtitle = title; 
    var newtitle_args = "";
    if ( params != null ){
        for ( i = 0; i < params.length; i++) {
            params[i] = params[i].replace(/^\$/, "");
            var text = this.currentWidget[params[i]];
            if (typeof(text) != 'undefined') {
                if (text == '') {
                    if (params[i] == 'page_title')
                        text = Page.page_title;
                    else if (params[i] == 'workspace_id')
                        text = Page.wiki_title;
                }
                else {
                    newtitle = newtitle.replace("$" + params[i], "[_" + ( i + 1 ) + "]");
                    newtitle_args += ", \"" + text.replace(/"/g, '\\"') + "\"";
                }
            }
            else {
                newtitle_args += ", \"\"";
            }
            newtitle = newtitle.replace("$" + params[i], "");
        }
    }
    if (newtitle_args != "") {
        newtitle = eval("loc(\"" + newtitle + "\"" + newtitle_args + ")");
        if ( newtitle == 'undefined' ){
            newtitle = title;
        }
    }else{
        newtitle = eval("loc(\"" + newtitle + "\")");
        if ( newtitle == 'undefined' ){
            newtitle = title;
        }
    }
    elem.setAttribute("title", newtitle);

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

    if (! this.currentWidget) return;
    var id = this.currentWidget.id;
    if (widget_data[id] && widget_data[id].uneditable) {
        DOM.Events.addListener(elem, 'mouseup', function(e) {
            e.target.setAttribute("mousedown", 0);
            if ( e.target.getAttribute("mouseup") == 0 ) {
                if ( Wikiwyg.Widgets.widget_editing > 0 )
                    return;
                alert(loc("This is not an editable widget. Please edit it in advanced mode."))
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

proto.lookupTitle = function(field, id) {
    var title = this.titleInLoopup(field, id);
    if (!title) {
        title = this.pullTitleFromServer(field, id);
    }
    return title;
}

proto.titleInLoopup = function (field, id) {
    if (field in wikiwyg_widgets_title_lookup)
        if (id in wikiwyg_widgets_title_lookup[field])
            return wikiwyg_widgets_title_lookup[field][id];
    return '';
}

proto.pullTitleFromServer = function (field, id, data) {
    var uri = Wikiwyg.Widgets.api_for_title[field];
    uri = uri.replace(new RegExp(":" + field), id);

    var details = jQuery.getJSON(uri);
    if (!(field in wikiwyg_widgets_title_lookup))
        wikiwyg_widgets_title_lookup[field] = {};
    wikiwyg_widgets_title_lookup[field][id] = details.title;

    return details.title;
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
                var title = this.lookupTitle(field, widget[field]) || widget[field];
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

    widget = widget.replace(/-=/g, '-').replace(/==/g, '=');

    if ((matches = widget.match(/^(aim|yahoo|ymsgr|skype|callme|callto|http|asap|irc|file|ftp|https):([\s\S]*?)\s*$/)) ||
        (matches = widget.match(/^\{(\{([\s\S]+)\})\}$/)) || // AS-IS
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
        throw(loc('Unexpected Widget >>[_1]<< in parseWidget', widget));
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

            // Grab extra args (things like size=medium) from the end
            var all_args = widget_args.match(/(.*?)\s+((?:\S+=+\S+,?)+)$/);
            if (all_args) {
                widget_args = all_args[1];
                var extra_args = all_args[2].split(',');
                for (var i=0; i < extra_args.length; i++) {
                    var keyval = extra_args[i].split(/=+/);
                    widget_parse[keyval[0]] = keyval[1];
                }
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
            if (widget_parse.size) {
                if (widget_parse.size.match(/^(\d+)(?:x(\d+))?$/)) {
                    widget_parse.width = RegExp.$1 || '';
                    widget_parse.height = RegExp.$2 || '';
                }
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

            // HALGHALGHAHG - Horrible fix for horrendous IE bug.
            if (part.nextSibling && part.nextSibling.nodeType == 8)
                part.appendChild(part.nextSibling);

            if (name && name.match(/(nlw_phrase|wafl_block)/)) {
                part = this.replace_widget(part);
            }
        }
        this.widget_walk(part);
    }
}

proto.replace_widget = function(elem) {
    var comment = elem.lastChild;
    if (!comment || comment.nodeType != 8) return elem;
    if (! comment.nodeValue.match(/^\s*wiki:/)) return elem;
    var widget = comment.nodeValue.replace(/^\s*wiki:\s*([\s\S]*?)\s*$/, '$1');
    widget = widget.replace(/-=/g, '-');
    var widget_image;
    var src;

    if (widget.match(/^{image:/)) {
        var orig = elem.firstChild;
        if (orig.src) src = orig.src;
    }

    if (!src)
        src = this.getWidgetImageUrl(widget);

    widget_image = Wikiwyg.createElementWithAttrs('img',
        {
            'src': src,
            'widget': widget
        }
    );
    elem.parentNode.replaceChild(widget_image, elem);
    return widget_image;
}

proto.insert_generated_image = function (widget_string, elem, cb) {
    var self = this;
    var widget_text = self.getWidgetImageText(widget_string);
    Jemplate.Ajax.post(
        location.pathname,
        'action=wikiwyg_generate_widget_image;' +
        'widget=' + encodeURIComponent(widget_text) +
        ';widget_string=' + encodeURIComponent(widget_string),
        function() {
            self.insert_image(
                self.getWidgetImageUrl(widget_string),
                widget_string,
                elem,
                cb
            );
        }
    );
}

proto.insert_real_image = function(widget, elem, cb) {
    var self = this;
    Jemplate.Ajax.post(
         location.pathname,
        'action=preview' +
        ';wiki_text=' + encodeURIComponent(widget) +
        ';page_name=' + encodeURIComponent(Page.page_id),
        function(widget_html) {
            var div = document.createElement("div");
            div.innerHTML = widget_html;
            var img = div.getElementsByTagName("img")[0];
            if (img && img.src) {
                self.insert_image(img.src, widget, elem, cb);
            }
            else {
                self.insert_generated_image(widget,elem, cb);
            }
        }
    )
}

proto.insert_image = function (src, widget, widget_element, cb) {
    var html = '<img src="' + src +
        '" widget="' + widget.replace(/"/g,"&quot;") + '" />';
    if ( widget_element ) {
        if ( widget_element.parentNode ) {
            var div = this.get_edit_document().createElement("div");
            div.innerHTML = html;

            var new_widget_element = div.firstChild;
            widget_element.parentNode.replaceChild(new_widget_element, widget_element);
        }
        else {
            this.insert_html(html);
        }
    }
    else {
        this.insert_html(html);
    }
    this.setWidgetHandlers();
    if (cb)
        cb();
}

proto.insert_widget = function(widget, widget_element, cb) {
    var self = this;

    var changer = function() {
        try {
            if (widget.match(/^{image:/)) {
                self.insert_real_image(widget, widget_element, cb);
            }
            else {
                self.insert_generated_image(widget, widget_element, cb);
            }
        }
        catch(e) {
            setTimeout(changer, 100);
        }
    }

    this.get_edit_window().focus();
    this.get_edit_document().body.focus();
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
        text = this.getWidgetImageLocalizeText(widget, text);
    }
    catch (E) {
        // parseWidget can throw an error
        // Just ignore and set the text to be the widget text
    }

    return text;
}

proto.getWidgetImageLocalizeText = function(widget, text) {
    var params = text.match(/%(\w+)/g);
    var newtext = text; 
    var newtext_args = "";
    if (params != null) {
        for (i = 0; i < params.length; i++) {
            params[i] = params[i].replace(/^%/, "");
            var mytext = widget[params[i]] || "";
            newtext = newtext.replace("%" + params[i], "[_" + ( i + 1 ) + "]");
            newtext_args += ", \"" + mytext.replace(/"/g, '\\"') + "\"";
        }
    }
    if (newtext_args != "") {
        newtext = eval("loc(\"" + newtext + "\"" + newtext_args + ")");
        if (newtext == 'undefined'){
            newtext = text;
        }
    }
    else {
        newtext = eval("loc(\"" + newtext + "\")");
        if (newtext == 'undefined') {
            newtext = text;
        }
    }
    return newtext;
}

proto.getWidgetImageUrl = function(widget_text) {
    var md5 = MD5(this.getWidgetImageText(widget_text));
    var url = nlw_make_static_path('/widgets/' + md5 + '.png');
    return url;
}

proto.create_wafl_string = function(widget, form) {
    var data = widget_data[widget];
    var result = data.pattern || '{' + widget + ': %s}';

    var values = this.form_values(widget, form);
    var fields =
        data.field ? [ data.field ] :
        data.fields ? data.fields :
        [];
    if (data.other_fields) {
        data.other_fields.each(
            function (field){ fields.push(field) }
        );
    }
    for (var j = 0; j < fields.length; j++) {
        var token = new RegExp('%' + fields[j]);
        result = result.replace(token, values[fields[j]]);
    }

    result = result.
        replace(/^\"\s*\"/, '').
        replace(/\[\s*\]/, '').
        replace(/\<\s*\>/, '').
        replace(/\(\s*\)/, '').
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
        var field = fields[i];

        if (this.currentWidget.title_and_id && this.currentWidget.title_and_id[field] && this.currentWidget.title_and_id[field].id)
            value = this.currentWidget.title_and_id[field].id;
        else if (form[field].length > 1)
            value = jQuery('*[name='+field+']:checked', form).val();
        else
            value = form[field].value.
                replace(/^\s*/, '').
                replace(/\s*$/, '');
        var cb = jQuery('*[name=st-widget-'+field+'-rb]:checked', form);
        if (cb.size()) {
            var whichValue = cb.val();
            if (whichValue == 'current') {
                value = '';
            }
        }
        values[field] = value;
    }
    if (values.label) {
        values.label = values.label.replace(/^"*/, '').replace(/"*$/, '');
    }
    if (values.size) {
        if (values.size == 'custom') {
            values.size = form.width.value || 0 + 'x' + form.height.value || 0;
        }
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
                throw(loc("'[_1]' is a required field", label));
            }
        }
    }

    var require = data.require_one;
    if (require) {
        var found = 0;
        labels = [];
        for (var i = 0; i < require.length; i++) {
            var field = require[i];
            var label = loc(Wikiwyg.Widgets.fields[field]);
            labels.push(label);
            if (values[field].length)
                found++;
        }
        if (! found)
            throw(loc("Requires one of: [_1]", labels.join(', ')));
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
            throw(loc("'[_1]' has an invalid value", label));
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
    if (values.spreadsheet_title) {
        return this.require_spreadsheet_if_workspace(values);
    }

    if (values.workspace_id.length && ! values.page_title.length)
        throw(loc("Page Title required if Workspace Id specified"));
}

proto.require_spreadsheet_if_workspace = function(values) {
    if (values.workspace_id.length && ! values.spreadsheet_title.length)
        throw(loc("Spreadsheet Title required if Workspace Id specified"));
}


proto.hookLookaheads = function(dialog, widget) {
    var cssSugestionWindow = 'st-widget-lookaheadsuggestionwindow';
    var cssSuggestionBlock = 'st-widget-lookaheadsuggestionblock';
    var cssSuggestionText = 'st-widget-lookaheadsuggestion';

    widget = widget || this.currentWidget;

    if ($('st-widget-workspace_id')) {
        window.workspaceLookahead = new WorkspaceLookahead(
            dialog,
            'st-widget-workspace_id',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'workspaceLookahead',
            widget
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
            widget
        );
        window.pageLookahead.pageType = "wiki";
        window.pageLookahead.defaultWorkspace = Socialtext.wiki_id;
    }

    jQuery("#st-widget-spreadsheet_title").each(function() {
        window.pageLookahead = new PageNameLookahead(
            dialog,
            'st-widget-spreadsheet_title',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'pageLookahead',
            widget
        );
        window.pageLookahead.pageType = "spreadsheet";
        window.pageLookahead.defaultWorkspace = Socialtext.wiki_id;
    });

    if ($('st-widget-tag_name')) {
        window.tagLookahead = new TagLookahead(
            dialog,
            'st-widget-tag_name',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'tagLookahead',
            widget
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
            widget
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
            widget,
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

    this.currentWidget.skin_path = nlw_make_s2_path('');

    // Give the templates direct access to loc()
    this.currentWidget.loc = loc;

    var widget = this.currentWidget.id;

    if (widget == 'link2') {
        return this.do_link(widget_element);
    }

    var template = 'widget_' + widget + '_edit.html';
    var html = Jemplate.process(template, this.currentWidget);

    jQuery('<div>')
        .attr('id', 'widget-' + widget)
            .attr('class', 'lightbox')
            .html(html)
            .appendTo('body');

        jQuery.showLightbox({
            content: '#widget-' + widget
        });

        var self = this;
        var form = jQuery('#widget-' + widget + ' form').get(0);

        var intervalId = setInterval(function () {
            jQuery('#'+widget+'_wafl_text')
                .html(
                    ' <span>' +
                    self.create_wafl_string(widget, form).
                        replace(/</g, '&lt;') +
                    '</span> '
                );
        }, 500);

        jQuery('#st-widgets-moreoptions').toggle(
            function () {
                jQuery('#st-widgets-moreoptions')
                    .html(loc('Fewer options'))
                jQuery('#st-widgets-optionsicon')
                    .attr('src', nlw_make_s2_path('/images/st/hide_more.gif'));
                jQuery('#st-widgets-moreoptionspanel').show();
            },
            function () {
                jQuery('#st-widgets-moreoptions')
                    .html(loc('More options'))
                jQuery('#st-widgets-optionsicon')
                    .attr('src', nlw_make_s2_path('/images/st/show_more.gif'));
                jQuery('#st-widgets-moreoptionspanel').hide();
            }
        );

        jQuery('#st-widget-savebutton')
            .click(function() {
                var error = null;
                try {
                    var widget_string = self['handle_widget_' + widget](form);
                    clearInterval(intervalId);
                    self.insert_widget(widget_string, widget_element, function () {
                        jQuery.hideLightbox();
                    });
                }
                catch(e) {
                    error = String(e);
                    jQuery('#'+widget+'_widget_edit_error_msg')
                        .show()
                        .html('<span>'+error+'</span>');
                    Wikiwyg.Widgets.widget_editing--;
                    return false;
                }
                Wikiwyg.Widgets.widget_editing--;
                return false;
            });

        jQuery('#st-widget-cancelbutton')
            .click(function () {
                clearInterval(intervalId);
                jQuery.hideLightbox();
            })

        // Grab the current selection and set it in the lightbox. uck
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

    function disable (elem) {
        if (Number(elem.value))
            elem.stored_value = elem.value;
        elem.value = '';
        elem.style.backgroundColor = '#ddd'
        elem.pretend_disabled = true;
    }

    function enable (elem) {
        // Re-enable the width
        if (elem.pretend_disabled) {
            elem.value = elem.stored_value || '';
            elem.style.backgroundColor = '#fff'
            elem.pretend_disabled = false;
        }
    }

    if (form.size) {
        jQuery(form.width).click(function (){
            form.size[4].checked = true;
            disable(form.height);
            enable(form.width);
        });
        jQuery(form.height).click(function () {
            form.size[4].checked = true;
            disable(form.width);
            enable(form.height);
        });
        if (!Number(form.height.value))
            disable(form.height);
        else if (!Number(form.width.value))
            disable(form.width);
    }
}

