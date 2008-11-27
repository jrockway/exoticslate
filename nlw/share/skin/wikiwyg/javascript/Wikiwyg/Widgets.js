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
    if (! (
        action.match(/^do_widget_link2/)
        &&
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
        html = this.assert_padding_around_block_elements(html);
        html = this.assert_padding_between_block_elements(html);

        var dom = document.createElement('div');
        dom.innerHTML = html;
        this.sanitize_dom(dom);
        this.set_inner_html(dom.innerHTML);
    }
    else {
        html = this.replace_p_with_br(html);
        Wikiwyg.Wysiwyg.prototype.fromHtml.call(this, html);
    }

    this.setWidgetHandlers();
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

proto.assert_padding_around_block_elements = function(html) {
    var doc = jQuery('<div />').append(
        html.replace(/<div\b/g, '<span tmp="div"')
            .replace(/<\/div>/g, '</span>')
    );

    var el;
    while (el = doc.find('span[tmp=div]:first')[0]) {
        var span = jQuery(el);
        var div = jQuery('<div />')
            .append( span.clone().removeAttr('tmp') )
            .html()
            .replace(/^<span/, '<div')
            .replace(/<\/span>$/, '</div>');

        var parent_el = span.parent('p').get(0);
        if (!parent_el) {
            span.replaceWith(div);
            continue;
        }

        var p = jQuery(parent_el);
        var p_html = p.html();
        var p_before = p_html.replace(
            /[ \t]*<span[^>]*tmp="div"[\s\S]*/i, ''
        );

        span.remove();

        p.html(
            p.html().substr(p_before.length)
                    .replace(/^[ \t]*/, '')
        );
        p.before(jQuery('<p />').html(p_before));
        p.before(div);
    }

    return doc.html();
}

proto.replace_p_with_br = function(html) {
    var br = "<br class=\"p\"/>";
    var doc = document.createElement("div");
    doc.innerHTML = this.assert_padding_around_block_elements(html);
    var p_tags = jQuery(doc).find("p").get();
    for(var i=0;i<p_tags.length;i++) {
        var html = p_tags[i].innerHTML;
        var prev = p_tags[i].previousSibling;
        var prev_tag = null;
        if (prev && prev.tagName) {
            prev_tag = prev.tagName.toLowerCase();
        }

        html = html.replace(/(<br>)?\s*$/, br + br);
        if (prev && prev_tag && (prev_tag == 'div' || (prev_tag == 'span' && prev.firstChild && prev.firstChild.tagName && prev.firstChild.tagName.toLowerCase() == 'div'))) {
            html = html.replace(/^\n?[ \t]*/,br + br)
        }
        else if (prev && prev_tag && prev_tag != 'br' && prev_tag != 'p') {
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
                jQuery(prev).remove();
            }
        }
        else {
            html = html.replace(/^\n?/,'')
        }

        if (prev && prev.nodeType == 3) {
            prev.nodeValue = prev.nodeValue.replace(/\n*$/,'')
        }

        jQuery(p_tags[i]).replaceWith(html);
    }
    return doc.innerHTML;
}

proto.toHtml = function(func) {
    if (Wikiwyg.is_ie) {
        var html = this.get_inner_html();
        var br = "<br class=\"p\"/>";

        html = this.remove_padding_material(html);
        html = html
            .replace(/\n*<p>\n?/ig, "")
            .replace(/<\/p>/ig, br)

        func(html);
    }
    else {
        Wikiwyg.Wysiwyg.prototype.toHtml.call(this, func);
    }

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
    var self = this;
    var doc = this.get_edit_document();
    if (Wikiwyg.is_ie) {
        if (! (doc && doc.body && doc.body.innerHTML) ){
            setTimeout(function() { self.setWidgetHandlers() }, 500);
            return;
        }
    }
    var imgs = this.get_edit_document().getElementsByTagName('img');
    for (var ii = 0; ii < imgs.length; ii++) {
        this.setWidgetHandler(imgs[ii]);
    }

    if (jQuery.browser.msie)
        this.revert_widget_images();

    var self = this;
    var win = this.get_edit_window();
    var doc = this.get_edit_document();

    jQuery(doc, win)
    .bind("mouseup", function(e) {
        if (!jQuery(e.target).is("img[widget]")) return true;
        self.currentWidget = self.parseWidgetElement(e.target);
        var id = self.currentWidget.id;  
        if (widget_data[id] && widget_data[id].uneditable) {
            alert(loc("This is not an editable widget. Please edit it in Wiki Text mode."))  
        }
        else {
            self.getWidgetInput(e.target, false, false);
        }
    });
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
    var width = img.getAttribute("width");
    var height = img.getAttribute("height");
    var has_style_attr = (typeof style == 'string');
    var has_width_attr = (typeof width != 'undefined' );
    var has_height_attr = (typeof height != 'undefined');

    if (
        has_style_attr ||
        img.getAttribute("src").match(/^\.\./) ||
        ( has_width_attr && has_height_attr )
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
    var fixing = false;

    var fixer = function() {
        if (fixing) return;
        fixing = true;

        var imgs = self.get_edit_document().getElementsByTagName('img');
        for (var i=0, l = imgs.length; i < l; i++) {
            var img = imgs[i];

            if (!img.getAttribute("widget")) { continue; }
            if (!self.need_to_revert_widet(img)) { continue; }

            img.removeAttribute("style");
            img.removeAttribute("width");
            img.removeAttribute("height");
        }
        self.reclaim_element_registry_space();

        fixing = false;
    };
    this._fixer_interval_id = setInterval(fixer, 500);
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
    wikiwyg_widgets_element_registry = 
        jQuery.grep(wikiwyg_widgets_element_registry, function (i) {
            return i != undefined ? true : false
        });
}

proto.element_registry_push = function(elem) {
    var flag = 0;
    jQuery.each(wikiwyg_widgets_element_registry, function() {
        if (this == elem) {
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
    var title = this.titleInLookup(field, id);
    if (!title) {
        title = this.pullTitleFromServer(field, id);
    }
    return title;
}

proto.titleInLookup = function (field, id) {
    if (field in wikiwyg_widgets_title_lookup)
        if (id in wikiwyg_widgets_title_lookup[field])
            return wikiwyg_widgets_title_lookup[field][id];
    return '';
}

proto.pullTitleFromServer = function (field, id, data) {
    var uri = Wikiwyg.Widgets.api_for_title[field];
    uri = uri.replace(new RegExp(":" + field), id);

    var details;
    jQuery.ajax({
        url: uri,
        async: false,
        dataType: 'json',
        success: function (data) {
            details = data;
        }
    });
    if (!(field in wikiwyg_widgets_title_lookup))
        wikiwyg_widgets_title_lookup[field] = {};

    if (details) {
        wikiwyg_widgets_title_lookup[field][id] = details.title;
        return details.title;
    }
    else {
        return null;
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

    if ((matches = widget.match(/^(aim|yahoo|ymsgr|skype|callme|callto|http|irc|file|ftp|https):([\s\S]*?)\s*$/)) ||
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
    jQuery.post(
        location.pathname,
        { action: 'wikiwyg_generate_widget_image'
        , widget: widget_text
        , widget_string: widget_string
        },
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
    jQuery.get(
        location.pathname,
        'action=preview' +
        ';wiki_text=' + encodeURIComponent(widget) +
        ';page_name=' + encodeURIComponent(Socialtext.page_id),
        function(dom) {
            var src = jQuery(dom.firstChild).children('img').attr('src');
            if (src) {
                self.insert_image(src, widget, elem, cb);
            }
            else {
                self.insert_generated_image(widget,elem, cb);
            }
        },
        'xml'
    );
}

proto.insert_image = function (src, widget, widget_element, cb) {
    var html = '<img src="' + src +
        '" widget="' + widget.replace(/&/g,"&amp;").replace(/"/g,"&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;") + '" />';
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
            setTimeout(changer, 300);
        }
    }

    // These lines caused the IE only bug {bz: 1506}.
    // Not running them in IE seems to make widget insertion ok in IE.
    if (! jQuery.browser.msie) {
        this.get_edit_window().focus();
        this.get_edit_document().body.focus();
    }

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
        jQuery.each(data.other_fields, function (){ fields.push(this) });
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


proto.hookLookaheads = function() {
    var currentWidget = this.currentWidget;
    jQuery('#st-widget-workspace_id')
        .lookahead({
            filterName: 'title_filter',
            url: '/data/workspaces',
            linkText: function (i) {
                return [ i.title + ' (' + i.name + ')', i.name ];
            },
            onAccept: function () {
                currentWidget.title_and_id.workspace_id.id = this.value;
            }
        })
        .keyup( function () {
            var which = this.value ? 'other' : 'current';
            jQuery('*[name='+this.id+'-rb][value='+which+']')
                .attr('checked', true);
            currentWidget.title_and_id.workspace_id.id = this.value;
        });

    jQuery('#st-widget-page_title')
        .lookahead({
            url: function () {
                var ws = jQuery('#st-widget-workspace_id').val() ||
                         Socialtext.wiki_id;
                return '/data/workspaces/' + ws + '/pages';
            },
            args: {
                pageType: 'wiki'
            },
            linkText: function (i) { return i.name }
        });

    jQuery("#st-widget-spreadsheet_title")
        .lookahead({
            url: function () {
                var ws = jQuery('#st-widget-workspace_id').val() ||
                         Socialtext.wiki_id;
                return '/data/workspaces/' + ws + '/pages';
            },
            args: {
                pageType: 'spreadsheet'
            },
            linkText: function (i) { return i.name }
        });

    jQuery('#st-widget-tag_name')
        .lookahead({
            url: function () {
                var ws = jQuery('#st-widget-workspace_id').val() ||
                         Socialtext.wiki_id;
                return '/data/workspaces/' + ws + '/tags';
            },
            linkText: function (i) { return i.name }
        });

    jQuery('#st-widget-weblog_name')
        .lookahead({
            url: function () {
                var ws = jQuery('#st-widget-workspace_id').val() ||
                         Socialtext.wiki_id;
                return '/data/workspaces/' + ws + '/tags';
            },
            filterValue: function (val) {
                return val + '.*(We)?blog$';
            },
            linkText: function (i) { return i.name }
        });

    jQuery('#st-widget-section_name')
        .lookahead({
            url: function () {
                var ws = jQuery('#st-widget-workspace_id').val() || Socialtext.wiki_id;
                var pg = jQuery('#st-widget-page_name').val() || Socialtext.page_id;
                pg = nlw_name_to_id(pg || '');
                return '/data/workspaces/' + ws + '/pages/' + pg + '/sections';
            },
            linkText: function (i) { return i.name }
        });

    jQuery('#st-widget-image_name, #st-widget-file_name')
        .lookahead({
            url: function () {
                var ws = jQuery('#st-widget-workspace_id').val() || Socialtext.wiki_id;
                var pg = jQuery('#st-widget-page_name').val() || Socialtext.page_id;
                pg = nlw_name_to_id(pg || '');
                return '/data/workspaces/' + ws + '/pages/' + pg +
                       '/attachments';
            },
            linkText: function (i) { return i.name }
        });
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
    // This should not be needed after new Jemplate release...
    this.currentWidget.loc = loc;

    var widget = this.currentWidget.id;

    if (widget == 'link2') {
        this.do_link(widget_element);
        jQuery('#wiki-link-text').focus();
        return;
    }
    else if (widget == 'link2_section') {
        this.do_link(widget_element);
        jQuery('#add-section-link').select();
        jQuery('#section-link-text').focus();
        return;
    }
    else if (widget == 'link2_hyperlink') {
        this.do_link(widget_element);
        jQuery('#add-web-link').select();
        jQuery('#web-link-text').focus();
        return;
    }

    var template = 'widget_' + widget + '_edit.html';
    var html = Jemplate.process(template, this.currentWidget);

    jQuery('<div />')
        .attr('id', 'widget-' + widget)
        .attr('class', 'lightbox')
        .html(html)
        .appendTo('body');

    var self = this;
    jQuery.showLightbox({
        content: '#widget-' + widget,
        callback: function() {
            var config = Wikiwyg.Widgets.widget[ widget ];
            var fields =
                (config.focus && [ config.focus ]) ||
                config.required ||
                config.fields ||
                [ config.field ];

            var field = fields[0];
            if (field) {
                var selector =
                    field.match(/^[\#\.]/)
                    ? field
                    : '#st-widget-' + field;
                jQuery(selector).select().focus();
            }
        }
    });

    // When the lightbox is closed, decrement widget_editing so lightbox can pop up again. 
    jQuery('#lightbox').unload(function(){
        Wikiwyg.Widgets.widget_editing--;
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

    jQuery('#st-widgets-moreoptions').unbind('click').toggle(
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
        .unbind('click')
        .click(function() {
            var error = null;
            jQuery('#lightbox .buttons input').attr('disabled', 'disabled');
            try {
                var widget_string = self['handle_widget_' + widget](form);
                clearInterval(intervalId);
                self.insert_widget(widget_string, widget_element, function () {
                    jQuery('#lightbox .buttons input').attr('disabled', '');
                    jQuery.hideLightbox();
                });
            }
            catch(e) {
                error = String(e);
                jQuery('#'+widget+'_widget_edit_error_msg')
                    .show()
                    .html('<span>'+error+'</span>');
                jQuery('#lightbox .buttons input').attr('disabled', '');
                return false;
            }
            return false;
        });

    jQuery('#st-widget-cancelbutton')
        .unbind('click')
        .click(function () {
            clearInterval(intervalId);
            jQuery.hideLightbox();
            if (wikiwyg.current_mode.set_focus) {
                wikiwyg.current_mode.set_focus();
            }
        });

    this.hookLookaheads();

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

