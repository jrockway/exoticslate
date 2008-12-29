
proto = new Subclass('Wikiwyg.Wikitext', 'Wikiwyg.Mode');
klass = Wikiwyg.Wikitext;

proto.classtype = 'wikitext';
proto.modeDescription = 'Wikitext';

proto.config = {
    textareaId: null,
    supportCamelCaseLinks: false,
    javascriptLocation: null,
    clearRegex: null,
    editHeightMinimum: 10,
    editHeightAdjustment: 1.3,
    markupRules: {
        link: ['bound_phrase', '[', ']'],
        bold: ['bound_phrase', '*', '*'],
        code: ['bound_phrase', '`', '`'],
        italic: ['bound_phrase', '/', '/'],
        underline: ['bound_phrase', '_', '_'],
        strike: ['bound_phrase', '-', '-'],
        p: ['start_lines', ''],
        pre: ['start_lines', '    '],
        h1: ['start_line', '= '],
        h2: ['start_line', '== '],
        h3: ['start_line', '=== '],
        h4: ['start_line', '==== '],
        h5: ['start_line', '===== '],
        h6: ['start_line', '====== '],
        ordered: ['start_lines', '#'],
        unordered: ['start_lines', '*'],
        indent: ['start_lines', '>'],
        hr: ['line_alone', '----'],
        table: ['line_alone', '| A | B | C |\n|   |   |   |\n|   |   |   |'],
        www: ['bound_phrase', '[', ']']
    }
}

proto.initializeObject = function() { // See IE
    this.initialize_object();
}

proto.initialize_object = function() {
    this.div = document.createElement('div');
    if (this.config.textareaId)
        this.textarea = document.getElementById(this.config.textareaId);
    else
        this.textarea = document.createElement('textarea');
    this.textarea.setAttribute('id', 'wikiwyg_wikitext_textarea');
    this.div.appendChild(this.textarea);
    this.area = this.textarea;
    this.clear_inner_text();
}

proto.clear_inner_text = function() {
    var self = this;
    this.area.onclick = function() {
        var inner_text = self.area.value;
        var clear = self.config.clearRegex;
        if (clear && inner_text.match(clear))
            self.area.value = '';
    }
}

proto.enableThis = function() {
    Wikiwyg.Mode.prototype.enableThis.call(this);
    this.textarea.style.width = Wikiwyg.is_ie ? '98%' : '99%';
    this.setHeightOfEditor();
    this.enable_keybindings();
    this.textarea.focus();

    if (Wikiwyg.is_gecko) {
        this.textarea.selectionStart = 0;
        this.textarea.selectionEnd = 0;
    }
}

proto.enableStarted = function() {
    jQuery(".table_buttons").addClass("disabled");
}

proto.setHeightOfEditor = function() {
    var config = this.config;
    var adjust = config.editHeightAdjustment;
    var area   = this.textarea;

    if ( Wikiwyg.is_safari) return area.setAttribute('rows', 25);

    var text   = this.getTextArea() ;
    var rows   = text.split(/\n/).length;

    var height = parseInt(rows * adjust);
    if (height < config.editHeightMinimum)
        height = config.editHeightMinimum;

    area.setAttribute('rows', height);
}

proto.toWikitext = function() {
    return this.getTextArea();
}

proto.toHtml = function(func) {
    var wikitext = this.canonicalText();
    this.convertWikitextToHtml(wikitext, func);
}

proto.canonicalText = function() {
    var wikitext = this.getTextArea();
    if (wikitext[wikitext.length - 1] != '\n')
        wikitext += '\n';
    return wikitext;
}

proto.fromHtml = function(html) {
    this.setTextArea('Loading...');
    var self = this;
    this.convertHtmlToWikitext(
        html,
        function(value) { self.setTextArea(value) }
    );
}

proto.getTextArea = function() {
    return this.textarea.value;
}

proto.setTextArea = function(text) {
    this.textarea.value = text;
}

proto.convertWikitextToHtml = function(wikitext, func) {
    alert('Wikitext changes cannot be converted to HTML\nWikiwyg.Wikitext.convertWikitextToHtml is not implemented here');
    func(this.copyhtml);
}

proto.convertHtmlToWikitext = function(html, func) {
    func(this.convert_html_to_wikitext(html));
}

proto.get_keybinding_area = function() {
    return this.textarea;
}

/*==============================================================================
Code to markup wikitext
 =============================================================================*/
Wikiwyg.Wikitext.phrase_end_re = /[\s\.\:\;\,\!\?\(\)\"]/;

proto.find_left = function(t, selection_start, matcher) {
    var substring = t.substr(selection_start - 1, 1);
    var nextstring = t.substr(selection_start - 2, 1);
    if (selection_start == 0)
        return selection_start;
    if (substring.match(matcher)) {
        // special case for word.word
        if ((substring != '.') || (nextstring.match(/\s/)))
            return selection_start;
    }
    return this.find_left(t, selection_start - 1, matcher);
}

proto.find_right = function(t, selection_end, matcher) {
    // Guard against IE's strange behaviour of returning -1 as selection_start.
    if (selection_end < 0) return 0;

    var substring = t.substr(selection_end, 1);
    var nextstring = t.substr(selection_end + 1, 1);
    if (selection_end >= t.length)
        return selection_end;
    if (substring.match(matcher)) {
        // special case for word.word
        if ((substring != '.') || (nextstring.match(/\s/)))
            return selection_end;
    }
    return this.find_right(t, selection_end + 1, matcher);
}

proto.get_lines = function() {
    var t = this.area;
    var selection_start = t.selectionStart;
    var selection_end = t.selectionEnd;

    if (selection_start == null) {
        selection_start = selection_end;
        if (selection_start == null) {
            return false
        }
        selection_start = selection_end =
            t.value.substr(0, selection_start).replace(/\r/g, '').length;
    }

    var our_text = t.value.replace(/\r/g, '');
    selection = our_text.substr(selection_start,
        selection_end - selection_start);

    selection_start = this.find_right(our_text, selection_start, /[^\r\n]/);

    if (selection_start > selection_end)
        selection_start = selection_end;

    selection_end = this.find_left(our_text, selection_end, /[^\r\n]/);

    if (selection_end < selection_start)
        selection_end = selection_start;

    this.selection_start = this.find_left(our_text, selection_start, /[\r\n]/);
    this.selection_end = this.find_right(our_text, selection_end, /[\r\n]/);
    t.setSelectionRange(selection_start, selection_end);
    t.focus();

    this.start = our_text.substr(0,this.selection_start);
    this.sel = our_text.substr(this.selection_start, this.selection_end -
        this.selection_start);
    this.finish = our_text.substr(this.selection_end, our_text.length);

    return true;
}

proto.alarm_on = function() {
    var area = this.area;
    var background = area.style.background;
    area.style.background = '#f88';

    function alarm_off() {
        area.style.background = background;
    }

    window.setTimeout(alarm_off, 250);
    area.focus()
}

proto.get_words = function() {
    function is_insane(selection) {
        return selection.match(/\r?\n(\r?\n|\*+ |\#+ |\=+ )/);
    }

    t = this.area; // XXX needs "var"?
    var selection_start = t.selectionStart;
    var selection_end = t.selectionEnd;

    if (selection_start == null) {
        selection_start = selection_end;
        if (selection_start == null) {
            return false
        }
        selection_start = selection_end =
            t.value.substr(0, selection_start).replace(/\r/g, '').length;
    }

    var our_text = t.value.replace(/\r/g, '');
    selection = our_text.substr(selection_start,
        selection_end - selection_start);

    selection_start = this.find_right(our_text, selection_start, /(\S|\r?\n)/);
    if (selection_start > selection_end)
        selection_start = selection_end;
    selection_end = this.find_left(our_text, selection_end, /(\S|\r?\n)/);
    if (selection_end < selection_start)
        selection_end = selection_start;

    if (is_insane(selection)) {
        this.alarm_on();
        return false;
    }

    this.selection_start =
        this.find_left(our_text, selection_start, Wikiwyg.Wikitext.phrase_end_re);
    this.selection_end =
        this.find_right(our_text, selection_end, Wikiwyg.Wikitext.phrase_end_re);

    t.setSelectionRange(this.selection_start, this.selection_end);
    t.focus();

    this.start = our_text.substr(0,this.selection_start);
    this.sel = our_text.substr(this.selection_start, this.selection_end -
        this.selection_start);
    this.finish = our_text.substr(this.selection_end, our_text.length);

    return true;
}

proto.markup_is_on = function(start, finish) {
    return (this.sel.match(start) && this.sel.match(finish));
}

proto.clean_selection = function(start, finish) {
    this.sel = this.sel.replace(start, '');
    this.sel = this.sel.replace(finish, '');
}

proto.toggle_same_format = function(start, finish) {
    start = this.clean_regexp(start);
    finish = this.clean_regexp(finish);
    var start_re = new RegExp('^' + start);
    var finish_re = new RegExp(finish + '$');
    if (this.markup_is_on(start_re, finish_re)) {
        this.clean_selection(start_re, finish_re);
        return true;
    }
    return false;
}

proto.clean_regexp = function(string) {
    string = string.replace(/([\^\$\*\+\.\?\[\]\{\}])/g, '\\$1');
    return string;
}

proto.insert_widget = function (widget_string) {
    /* This is currently only used for post-file-upload insertion of {file:}
     * and {image:} wafls; other widgets call insert_text_at_cursor directly.
     * Also see {bz: 1116}: For file uploads, Wafl is inserted on its own line.
     */
    this.insert_text_at_cursor('\n' + widget_string + '\n');
}

proto.insert_text_at_cursor = function(text) {
    var t = this.area;

    if (this.old_range) {
        this.old_range.text = text;
        return;
    }

    if (Wikiwyg.is_ie && typeof(this.start) != 'undefined' && typeof(this.finish) != 'undefined') {
        t.value = this.start + text + this.finish;
        return false;
    }

    var selection_start = t.selectionStart;
    var selection_end = t.selectionEnd;

    if (selection_start == null) {
        selection_start = selection_end;
        if (selection_start == null) {
            return false
        }
    }

    var before = t.value.substr(0, selection_start);
    var after = t.value.substr(selection_end, t.value.length);
    t.value = before + text + after;
}

proto.insert_text = function (text) {
    this.area.value = text + this.area.value;
}

proto.set_text_and_selection = function(text, start, end) {
    this.area.value = text;
    this.area.setSelectionRange(start, end);
}

proto.add_markup_words = function(markup_start, markup_finish, example) {
    if (this.toggle_same_format(markup_start, markup_finish)) {
        this.selection_end = this.selection_end -
            (markup_start.length + markup_finish.length);
        markup_start = '';
        markup_finish = '';
    }
    if (this.sel.length == 0) {
        if (example)
            this.sel = example;
        var text = this.start + markup_start + this.sel +
            markup_finish + this.finish;
        var start = this.selection_start + markup_start.length;
        var end = this.selection_end + markup_start.length + this.sel.length;
        this.set_text_and_selection(text, start, end);
    } else {
        var text = this.start + markup_start + this.sel +
            markup_finish + this.finish;
        var start = this.selection_start;
        var end = this.selection_end + markup_start.length +
            markup_finish.length;
        this.set_text_and_selection(text, start, end);
    }
    this.area.focus();
}

// XXX - A lot of this is hardcoded.
proto.add_markup_lines = function(markup_start) {
    var already_set_re = new RegExp( '^' + this.clean_regexp(markup_start), 'gm');
    var other_markup_re = /^(\^+|\=+|\*+|#+|>+|    )/gm;

    var match;
    // if paragraph, reduce everything.
    if (! markup_start.length) {
        this.sel = this.sel.replace(other_markup_re, '');
        this.sel = this.sel.replace(/^\ +/gm, '');
    }
    // if pre and not all indented, indent
    else if ((markup_start == '    ') && this.sel.match(/^\S/m))
        this.sel = this.sel.replace(/^/gm, markup_start);
    // if not requesting heading and already this style, kill this style
    else if (
        (! markup_start.match(/[\=\^]/)) &&
        this.sel.match(already_set_re)
    ) {
        this.sel = this.sel.replace(already_set_re, '');
        if (markup_start != '    ')
            this.sel = this.sel.replace(/^ */gm, '');
    }
    // if some other style, switch to new style
    else if (match = this.sel.match(other_markup_re))
        // if pre, just indent
        if (markup_start == '    ')
            this.sel = this.sel.replace(/^/gm, markup_start);
        // if heading, just change it
        else if (markup_start.match(/[\=\^]/))
            this.sel = this.sel.replace(other_markup_re, markup_start);
        // else try to change based on level
        else
            this.sel = this.sel.replace(
                other_markup_re,
                function(match) {
                    return markup_start.times(match.length);
                }
            );
    // if something selected, use this style
    else if (this.sel.length > 0)
        this.sel = this.sel.replace(/^(.*\S+)/gm, markup_start + ' $1');
    // just add the markup
    else
        this.sel = markup_start + ' ';

    var text = this.start + this.sel + this.finish;
    var start = this.selection_start;
    var end = this.selection_start + this.sel.length;
    this.set_text_and_selection(text, start, end);

    // Here we cancel the selection and allow the user to keep typing
    // (instead of replacing the freshly-inserted-markup by typing.)
    this.area.selectionStart = this.area.selectionEnd;

    this.area.focus();
}

// XXX - A lot of this is hardcoded.
proto.bound_markup_lines = function(markup_array) {
    var markup_start = markup_array[1];
    var markup_finish = markup_array[2];
    var already_start = new RegExp('^' + this.clean_regexp(markup_start), 'gm');
    var already_finish = new RegExp(this.clean_regexp(markup_finish) + '$', 'gm');
    var other_start = /^(\^+|\=+|\*+|#+|>+) */gm;
    var other_finish = /( +(\^+|\=+))?$/gm;

    var match;
    if (this.sel.match(already_start)) {
        this.sel = this.sel.replace(already_start, '');
        this.sel = this.sel.replace(already_finish, '');
    }
    else if (match = this.sel.match(other_start)) {
        this.sel = this.sel.replace(other_start, markup_start);
        this.sel = this.sel.replace(other_finish, markup_finish);
    }
    // if something selected, use this style
    else if (this.sel.length > 0) {
        this.sel = this.sel.replace(
            /^(.*\S+)/gm,
            markup_start + '$1' + markup_finish
        );
    }
    // just add the markup
    else
        this.sel = markup_start + markup_finish;

    var text = this.start + this.sel + this.finish;
    var start = this.selection_start;
    var end = this.selection_start + this.sel.length;
    this.set_text_and_selection(text, start, end);

    // Here we cancel the selection and allow the user to keep typing
    // (instead of replacing the freshly-inserted-markup by typing.)
    this.area.selectionStart = this.area.selectionEnd;

    this.area.focus();
}

proto.markup_bound_line = function(markup_array) {
    var scroll_top = this.area.scrollTop;
    if (this.get_lines())
        this.bound_markup_lines(markup_array);
    this.area.scrollTop = scroll_top;
}

proto.markup_start_line = function(markup_array) {
    var markup_start = markup_array[1];
    markup_start = markup_start.replace(/ +/, '');
    var scroll_top = this.area.scrollTop;
    if (this.get_lines())
        this.add_markup_lines(markup_start);
    this.area.scrollTop = scroll_top;
}

proto.markup_start_lines = function(markup_array) {
    var markup_start = markup_array[1];
    var scroll_top = this.area.scrollTop;
    if (this.get_lines())
        this.add_markup_lines(markup_start);
    this.area.scrollTop = scroll_top;
}

klass.make_do = function(style) {
    return function() {
        var markup = this.config.markupRules[style];
        var handler = markup[0];
        if (! this['markup_' + handler])
            die('No handler for markup: "' + handler + '"');
        this['markup_' + handler](markup);
    }
}

proto.do_bold = klass.make_do('bold');
proto.do_code = klass.make_do('code');
proto.do_italic = klass.make_do('italic');
proto.do_underline = klass.make_do('underline');
proto.do_strike = klass.make_do('strike');
proto.do_p = klass.make_do('p');
proto.do_pre = klass.make_do('pre');
proto.do_h1 = klass.make_do('h1');
proto.do_h2 = klass.make_do('h2');
proto.do_h3 = klass.make_do('h3');
proto.do_h4 = klass.make_do('h4');
proto.do_h5 = klass.make_do('h5');
proto.do_h6 = klass.make_do('h6');
proto.do_ordered = klass.make_do('ordered');
proto.do_unordered = klass.make_do('unordered');
proto.do_hr = klass.make_do('hr');
proto.do_table = klass.make_do('table');
proto.do_link = klass.make_do('link');

proto.add_section_link = function() {
    var section = jQuery('#section-link-text').val();

    if (!section) {
        this.set_add_a_link_error( "Please fill in the section field for section links." );
        return false;
    } 

    var wafl = this.create_link_wafl(false, false, false, section);
    this.insert_text_at_cursor(wafl);

    return true;
}

proto.add_wiki_link = function(widget_element, dummy_widget) {
    var label     = jQuery('#wiki-link-text').val(); 
    var workspace = jQuery('#st-widget-workspace_id').val() || "";
    var page_name = jQuery('#st-widget-page_title').val();
    var section   = jQuery('#wiki-link-section').val();
    var workspace_id = dummy_widget.title_and_id.workspace_id.id || workspace.replace(/\s+/g, '');

    if (!page_name) {
        this.set_add_a_link_error( "Please fill in the Page field for wiki links." );
        return false;
    }

    var wikitext = "";
    if (!section && (!workspace || workspace == Socialtext.wiki_id)) {  // simple wikitext
        wikitext = "[" + page_name + "]";
        if (label) {
            wikitext = "\"" + label + "\"" + wikitext;
        }
    } else { // wafl
        wikitext = this.create_link_wafl(label, workspace_id, page_name , section);
    }
    this.insert_text_at_cursor(wikitext);

    return true;
}

proto.add_web_link = function() {
    var url       = jQuery('#web-link-destination').val();
    var url_text  = jQuery('#web-link-text').val();

    if (!url || !url.match(/^(http|https|ftp|irc|mailto|file):/)) {
        this.set_add_a_link_error("Please fill in a Link destination for web links.");
        return false;
    }

    var wikitext;
    if (url_text) {
        wikitext = "\"" + url_text + "\"<" + url + ">";
    } else {
        wikitext = url;
    }
    this.insert_text_at_cursor(wikitext);

    return true;
}

proto.get_selection_text = function() {
    if (Wikiwyg.is_ie) {
        return this.sel;
    }

    var t = this.area;
    var selection_start = t.selectionStart;
    var selection_end   = t.selectionEnd;

    if (selection_start != null) {
        return t.value.substr(selection_start, selection_end - selection_start);
    } else {
        return "";
    }
}

proto.do_www = function() {
    var  url =  prompt("Please enter a link", "Type in your link here");
    var old = this.config.markupRules.www[1];
    this.config.markupRules.www[1] += url + " ";

    // do the transformation
    var markup = this.config.markupRules['www'];
    var handler = markup[0];
    if (! this['markup_' + handler])
        die('No handler for markup: "' + handler + '"');
    this['markup_' + handler](markup);

    // reset
    this.config.markupRules.www[1] = old;
}

proto.selection_mangle = function(method) {
    var scroll_top = this.area.scrollTop;
    if (! this.get_lines()) {
        this.area.scrollTop = scroll_top;
        return;
    }

    if (method(this)) {
        var text = this.start + this.sel + this.finish;
        var start = this.selection_start;
        var end = this.selection_start + this.sel.length;
        this.set_text_and_selection(text, start, end);
    }
    this.area.focus();
}

proto.do_indent = function() {
    this.selection_mangle(
        function(that) {
            if (that.sel == '') return false;
            that.sel = that.sel.replace(/^(([\*\-\#])+(?=\s))/gm, '$2$1');
            that.sel = that.sel.replace(/^([\>\=])/gm, '$1$1');
            that.sel = that.sel.replace(/^([^\>\*\-\#\=\r\n])/gm, '> $1');
            that.sel = that.sel.replace(/^\={7,}/gm, '======');
            return true;
        }
    )
}

proto.do_outdent = function() {
    this.selection_mangle(
        function(that) {
            if (that.sel == '') return false;
            that.sel = that.sel.replace(/^([\>\*\-\#\=] ?)/gm, '');
            return true;
        }
    )
}

proto.do_unlink = function() {
    this.selection_mangle(
        function(that) {
            that.sel = that.kill_linkedness(that.sel);
            return true;
        }
    );
}

// TODO - generalize this to allow Wikitext dialects that don't use "[foo]"
proto.kill_linkedness = function(str) {
    while (str.match(/\[.*\]/))
        str = str.replace(/\[(.*?)\]/, '$1');
    str = str.replace(/^(.*)\]/, '] $1');
    str = str.replace(/\[(.*)$/, '$1 [');
    return str;
}

proto.markup_line_alone = function(markup_array) {
    var t = this.area;
    var scroll_top = t.scrollTop;
    var selection_start = t.selectionStart;
    var selection_end = t.selectionEnd;
    if (selection_start == null) {
        selection_start = selection_end;
    }

    var text = t.value;
    this.selection_start = this.find_right(text, selection_start, /\r?\n/);
    this.selection_end = this.selection_start;
    t.setSelectionRange(this.selection_start, this.selection_start);
    t.focus();

    var markup = markup_array[1];
    this.start = t.value.substr(0, this.selection_start);
    this.finish = t.value.substr(this.selection_end, t.value.length);
    var text = this.start + '\n' + markup + this.finish;
    var start = this.selection_start + markup.length + 1;
    var end = this.selection_end + markup.length + 1;
    this.set_text_and_selection(text, start, end);
    t.scrollTop = scroll_top;
}

// Adapted from http://tim.mackey.ie/CleanWordHTMLUsingRegularExpressions.aspx
proto.strip_msword_gunk = function(html) {
    return html.
        replace(
            /<(span|\w:\w+)[^>]*>(\s*&nbsp;\s*)+<\/\1>/gi,
            function(m) {
                return m.match(/ugly-ie-css-hack/) ? m : '';
            }
        ).
        replace(/<\/?(xml|st\d+:\w+|[ovwxp]:\w+)[^>]*>/gi, '');
}

proto.normalizeDomStructure = function(dom) {
    this.normalize_styled_blocks(dom, 'p');
    this.normalize_styled_lists(dom, 'ol');
    this.normalize_styled_lists(dom, 'ul');
    this.normalize_styled_blocks(dom, 'li');
    this.normalize_span_whitespace(dom, 'span');
    this.normalize_empty_link_tags(dom);
}

proto.normalize_empty_link_tags = function(dom) {
    // Remove <a ...><!-- wiki-rename-link ... --></a>
    jQuery('a', dom).each(function () {
        if( this.childNodes.length == 1 &&
            this.childNodes[0].nodeType == 8 // comment node
            ) {
            this.parentNode.removeChild(this)
        }
    });
}

proto.normalize_span_whitespace = function(dom,tag ) {
    var grep = function(element) {
        return Boolean(element.getAttribute('style'));
    }

    var elements = this.array_elements_by_tag_name(dom, tag, grep);
    for (var i = 0; i < elements.length; i++) {
        var element = elements[i];
        var node = element.firstChild;
        while (node) {
            if (node.nodeType == 3) {
                node.nodeValue = node.nodeValue.replace(/^\n+/,"");
                break;
            }
            node = node.nextSibling;
        }
        var node = element.lastChild;
        while (node) {
            if (node.nodeType == 3) {
                node.nodeValue = node.nodeValue.replace(/\n+$/,"");
                break;
            }
            node = node.previousSibling;
        }
    }
}

proto.normalize_styled_blocks = function(dom, tag) {
    var elements = this.array_elements_by_tag_name(dom, tag);
    for (var i = 0; i < elements.length; i++) {
        var element = elements[i];
        var style = element.getAttribute('style');
        if (!style || this.style_is_bogus(style)) continue;
        element.removeAttribute('style');
        element.innerHTML =
            '<span style="' + style + '">' + element.innerHTML + '</span>';
    }
}

proto.style_is_bogus = function(style) {
    var attributes = [ 'line-through', 'bold', 'italic', 'underline' ];
    for (var i = 0; i < attributes.length; i++) {
        if (this.check_style_for_attribute(style, attributes[i]))
            return false;
    }
    return true;
}

proto.normalize_styled_lists = function(dom, tag) {
    var elements = this.array_elements_by_tag_name(dom, tag);
    for (var i = 0; i < elements.length; i++) {
        var element = elements[i];
        var style = element.getAttribute('style');
        if (!style) continue;
        element.removeAttribute('style');

        var items = element.getElementsByTagName('li');
        for (var j = 0; j < items.length; j++) {
            items[j].innerHTML =
                '<span style="' + style + '">' + items[j].innerHTML + '</span>';
        }
    }
}

proto.array_elements_by_tag_name = function(dom, tag, grep) {
    var result = dom.getElementsByTagName(tag);
    var elements = [];
    for (var i = 0; i < result.length; i++) {
        if (grep && ! grep(result[i]))
            continue;
        elements.push(result[i]);
    }
    return elements;
}

proto.normalizeDomWhitespace = function(dom) {
    var tags = ['span', 'strong', 'em', 'strike', 'del', 'tt'];
    for (var ii = 0; ii < tags.length; ii++) {
        var elements = dom.getElementsByTagName(tags[ii]);
        for (var i = 0; i < elements.length; i++) {
            this.normalizePhraseWhitespace(elements[i]);
        }
    }
    this.normalizeNewlines(dom, ['br', 'blockquote'], 'nextSibling');
    this.normalizeNewlines(dom, ['p', 'div', 'blockquote'], 'firstChild');
}

proto.normalizeNewlines = function(dom, tags, relation) {
    for (var ii = 0; ii < tags.length; ii++) {
        var nodes = dom.getElementsByTagName(tags[ii]);
        for (var jj = 0; jj < nodes.length; jj++) {
            var next_node = nodes[jj][relation];
            if (next_node && next_node.nodeType == '3') {
                next_node.nodeValue = next_node.nodeValue.replace(/^\n/, '');
            }
        }
    }
}

proto.normalizePhraseWhitespace = function(element) {
    if (this.elementHasComment(element)) return;

    if (element.innerHTML == '') {
        /* An empty phrase markup should not cause whitespaces: {bz: 1690} */
        element.parentNode.removeChild(element);
        return;
    }

    var first_node = this.getFirstTextNode(element);
    var prev_node = this.getPreviousTextNode(element);
    var last_node = this.getLastTextNode(element);
    var next_node = this.getNextTextNode(element);

    // This if() here is for a special condition on firefox.
    // When a bold span is the last visible thing in the dom,
    // Firefox puts an extra <br> in right before </span> when user
    // press space, while normally it put &nbsp;.

    if(Wikiwyg.is_gecko && element.tagName == 'SPAN') {
        var tmp = element.innerHTML;
        element.innerHTML = tmp.replace(/<br>$/i, '');
    }

    if (this.destroyPhraseMarkup(element)) return;

    if (first_node && first_node.nodeValue.match(/^ /)) {
        first_node.nodeValue = first_node.nodeValue.replace(/^ +/, '');
        if (prev_node && ! prev_node.nodeValue.match(/ $/))
            prev_node.nodeValue = prev_node.nodeValue + ' ';
    }

    if (last_node && last_node.nodeValue.match(/ $/)) {
        last_node.nodeValue = last_node.nodeValue.replace(/ $/, '');
        if (next_node && ! next_node.nodeValue.match(/^ /))
            next_node.nodeValue = ' ' + next_node.nodeValue;
    }
}

proto.elementHasComment = function(element) {
    var node = element.lastChild;
    return node && (node.nodeType == 8);
}

proto.end_is_no_good = function(element) {
    var last_node = this.getLastTextNode(element);
    var next_node = this.getNextTextNode(element);

    for (var n = element; n && n.nodeType != 3; n = n.lastChild) {
        if (n.nodeType == 8) return false;
    }

    if (! last_node) return true;
    if (last_node.nodeValue.match(/ $/)) return false;
    if (! next_node || next_node.nodeValue == '\n') return false;
    return ! next_node.nodeValue.match(Wikiwyg.Wikitext.phrase_end_re);
}

proto.destroyElement = function(element) {
    try {
        var range = element.ownerDocument.createRange();
        range.selectNode(element);
        var docfrag = range.createContextualFragment( element.innerHTML );
        element.parentNode.replaceChild(docfrag, element);
        return true;
    }
    catch (e) {
        return false;
    }
}

proto.getFirstTextNode = function(element) {
    for (node = element; node && node.nodeType != 3; node = node.firstChild) {
    }
    return node;
}

proto.getLastTextNode = function(element) {
    for (node = element; node && node.nodeType != 3; node = node.lastChild) {
    }
    return node;
}

proto.getPreviousTextNode = function(element) {
    var node = element.previousSibling;
    if (node && node.nodeType != 3)
        node = null;
    return node;
}

proto.getNextTextNode = function(element) {
    var node = element.nextSibling;
    if (node && node.nodeType != 3)
        node = null;
    return node;
}

proto.skip = function() { return ''; }
proto.pass = function(element) {
    return element.wikitext;
}
proto.handle_undefined = proto.skip;

proto.format_abbr = proto.pass;
proto.format_acronym = proto.pass;
proto.format_address = proto.pass;
proto.format_applet = proto.skip;
proto.format_area = proto.skip;
proto.format_basefont = proto.skip;
proto.format_base = proto.skip;
proto.format_bgsound = proto.skip;
proto.format_big = proto.pass;
proto.format_blink = proto.pass;
proto.format_body = proto.pass;
proto.format_br = proto.skip;
proto.format_button = proto.skip;
proto.format_caption = proto.pass;
proto.format_center = proto.pass;
proto.format_cite = proto.pass;
proto.format_col = proto.pass;
proto.format_colgroup = proto.pass;
proto.format_dd = proto.pass;
proto.format_dfn = proto.pass;
proto.format_dl = proto.pass;
proto.format_dt = proto.pass;
proto.format_embed = proto.skip;
proto.format_field = proto.skip;
proto.format_fieldset = proto.skip;
proto.format_font = proto.pass;
proto.format_form = proto.skip;
proto.format_frame = proto.skip;
proto.format_frameset = proto.skip;
proto.format_head = proto.skip;
proto.format_html = proto.pass;
proto.format_iframe = proto.pass;
proto.format_input = proto.skip;
proto.format_ins = proto.pass;
proto.format_isindex = proto.skip;
proto.format_label = proto.skip;
proto.format_legend = proto.skip;
proto.format_link = proto.skip;
proto.format_map = proto.skip;
proto.format_marquee = proto.skip;
proto.format_meta = proto.skip;
proto.format_multicol = proto.pass;
proto.format_nobr = proto.skip;
proto.format_noembed = proto.skip;
proto.format_noframes = proto.skip;
proto.format_nolayer = proto.skip;
proto.format_noscript = proto.skip;
proto.format_nowrap = proto.skip;
proto.format_object = proto.skip;
proto.format_optgroup = proto.skip;
proto.format_option = proto.skip;
proto.format_param = proto.skip;
proto.format_select = proto.skip;
proto.format_small = proto.pass;
proto.format_spacer = proto.skip;
proto.format_style = proto.skip;
proto.format_script = proto.skip;
proto.format_sub = proto.pass;
proto.format_submit = proto.skip;
proto.format_sup = proto.pass;
proto.format_tbody = proto.pass;
proto.format_textarea = proto.skip;
proto.format_tfoot = proto.pass;
proto.format_thead = proto.pass;
proto.format_wiki = proto.pass;
proto.format_www = proto.skip;

proto.check_style_for_attribute = function(style, attribute) {
    var string = this.squish_style_object_into_string(style);
    return string.match("\\b" + attribute + "\\b");
}

proto.squish_style_object_into_string = function(style) {
    if (! style) return;
    if ((style.constructor+'').match('String'))
        return style;
    var interesting_attributes = [
        [ 'font', 'weight' ],
        [ 'font', 'style' ],
        [ 'text', 'decoration' ]
    ];
    var string = '';
    for (var i = 0; i < interesting_attributes.length; i++) {
        var pair = interesting_attributes[i];
        var css = pair[0] + '-' + pair[1];
        var js = pair[0] + pair[1].ucFirst();
        if (style[js])
            string += css + ': ' + style[js] + '; ';
    }
    return string;
}

proto.COMMENT_NODE_TYPE = 8;
proto.get_wiki_comment = function(element) {
    for (var node = element.firstChild; node; node = node.nextSibling) {
        if (node.nodeType == this.COMMENT_NODE_TYPE
            && node.data.match(/^\s*wiki/)
        ) {
            return node;
        }
    }
    return null;
}

proto.href_is_wiki_link = function(href) {
    if (! this.looks_like_a_url(href))
        return true;
    if (! href.match(/\?/))
        return false;
    if (href.match(/\/static\//) && href.match(/\/skin\/js-test\//))
        href = location.href;
    var no_arg_input   = href.split('?')[0];
    var no_arg_current = location.href.split('?')[0];
    if (no_arg_current == location.href)
        no_arg_current =
          location.href.replace(new RegExp(location.hash), '');
    return no_arg_input == no_arg_current;
}

proto.looks_like_a_url = function(string) {
    return string.match(/^(http|https|ftp|irc|mailto|file):/);
}

/*==============================================================================
Support for Internet Explorer in Wikiwyg.Wikitext
 =============================================================================*/
if (Wikiwyg.is_ie) {

proto.setHeightOf = function() {
    // XXX hardcode this until we can keep window from jumping after button
    // events.
    this.textarea.style.height = '200px';
}

proto.initializeObject = function() {
    var self = this;
    this.initialize_object();
    this.area.addBehavior(this.config.javascriptLocation + "Selection.htc");
    jQuery(this.area).bind('beforedeactivate', function () {
        self.old_range = document.selection.createRange();
    });
}

} // end of global if
/*==============================================================================
Socialtext Wikitext subclass.
 =============================================================================*/
proto = new Subclass(WW_ADVANCED_MODE, 'Wikiwyg.Wikitext');

/* Begin Widget */
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

proto.markup_bound_phrase = function(markup_array) {
    var markup_start = markup_array[1];

    // Hack: This line exists to turn "{link2: }" into "{link: }"
    markup_start = markup_start.replace(/\d+: $/, ': ');

    var markup_finish = markup_array[2];
    var scroll_top = this.area.scrollTop;

    // Hack: Here we handle "{link2_*}" variants...
    if (markup_start == '{link2_hyperlink: ') {
        // Turns "{link2_hyperlink: }" into "<http://...>"
        markup_start = '<http://';
        markup_finish = '>';
    }
    else if (markup_start == '{link2_section: ') {
        // Turns "{link2_section: }" into "{link: }"
        markup_start = '{link: ';
    }

    if (markup_finish == 'undefined')
        markup_finish = markup_start;
    if (this.get_words())
        this.add_markup_words(markup_start, markup_finish, null);
    this.area.scrollTop = scroll_top;
}
/* End of Widget */

proto.markupRules = {
    italic: ['bound_phrase', '_', '_'],
    underline: ['bound_phrase', '', ''],
    h1: ['start_line', '^ '],
    h2: ['start_line', '^^ '],
    h3: ['start_line', '^^^ '],
    h4: ['start_line', '^^^^ '],
    h5: ['start_line', '^^^^^ '],
    h6: ['start_line', '^^^^^^ '],
    www: ['bound_phrase', '"', '"<http://...>'],
    attach: ['bound_phrase', '{file: ', '}'],
    image: ['bound_phrase', '{image: ', '}']
}

for (var ii in proto.markupRules) {
    proto.config.markupRules[ii] = proto.markupRules[ii]
}

proto.canonicalText = function() {
    var wikitext = Wikiwyg.Wikitext.prototype.canonicalText.call(this);
    return this.convert_tsv_sections(wikitext);
}

proto.convert_tsv_sections = function(text) {
    var self = this;
    return text.replace(
        /^tsv:\s*\n((.*(?:\t| {2,}).*\n)+)/gim,
        function(s) { return self.detab_table(s) }
    );
}

proto.detab_table = function(text) {
    return text.
        replace(/\r/g, '').
        replace(/^tsv:\s*\n/, '').
        replace(/(\t| {2,})/g, '|').
        replace(/^/gm, '|').
        replace(/\n/g, '|\n').
        replace(/\|$/, '');
}

proto.enableThis = function() {
    this.wikiwyg.set_edit_tips_span_display('inline');
    Wikiwyg.Wikitext.prototype.enableThis.call(this);
    if (jQuery('#contentRight').is(':visible')) {
        jQuery('#st-page-maincontent').css('marginRight', '240px');
    }
}

proto.toHtml = function(func) {
    this.wikiwyg.current_wikitext = this.canonicalText();
    Wikiwyg.Wikitext.prototype.toHtml.call(this, func);
}

proto.fromHtml = function(html) {
    if (Wikiwyg.is_safari) {
        if (this.wikiwyg.current_wikitext)
            return this.setTextArea(this.wikiwyg.current_wikitext);
        if (jQuery('#st-raw-wikitext-textarea').size()) {
            return this.setTextArea(jQuery('#st-raw-wikitext-textarea').val());
        }
    }
    Wikiwyg.Wikitext.prototype.fromHtml.call(this, html);
}

proto.disableThis = function() {
    this.wikiwyg.set_edit_tips_span_display('none');
    Wikiwyg.Wikitext.prototype.disableThis.call(this);
}

proto.setHeightOfEditor = function() {
    this.textarea.style.height = this.get_edit_height() + 'px';
}

proto.do_www = Wikiwyg.Wikitext.make_do('www');
proto.do_attach = Wikiwyg.Wikitext.make_do('attach');
proto.do_image = Wikiwyg.Wikitext.make_do('image');

proto.convertWikitextToHtml = function(wikitext, func) {
    var uri = location.pathname;
    var postdata = 'action=wikiwyg_wikitext_to_html;content=' +
        encodeURIComponent(wikitext);

    var post = jQuery.ajax({
        url: uri,
        async: false,
        type: 'POST',
        data: {
            action: 'wikiwyg_wikitext_to_html',
            page_name: jQuery('#st-newpage-pagename-edit, #st-page-editing-pagename').val(),
            content: wikitext
        }
    });

    func(post.responseText);
}

proto.href_is_really_a_wiki_link = function(href) {
    var query = href.split('?')[1];
    if (!query) return false;
    return ((! query.match(/=/)) || query.match(/action=display\b/));
}

proto.href_label_similar = function(elem, href, label) {
    var id_from_href  = nlw_name_to_id(href);
    var id_from_label = nlw_name_to_id(label);
    var id_from_attr  = nlw_name_to_id(elem.wiki_page || "");
    return ((id_from_href == id_from_label) || id_from_attr == id_from_label);
}

proto.is_renamed_wiki_link = function(element) {
    var comment = this.get_wiki_comment(element);
    return comment && comment.data.match(/wiki-renamed-link/);
}

proto.is_renamed_hyper_link = function(element) {
    var comment = this.get_wiki_comment(element);
    return comment && comment.data.match(/wiki-renamed-hyperlink/);
}

proto.make_table_wikitext = function(rows, columns) {
    var text = '';
    for (var i = 0; i < rows; i++) {
        var row = ['|'];
        for (var j = 0; j < columns; j++)
            row.push('|');
        text += row.join(' ') + '\n';
    }
    return text;
}

proto.do_table = function() {
    var result = this.prompt_for_table_dimensions();
    if (! result) return false;
    this.markup_line_alone([
        "a table",
        this.make_table_wikitext(result[0], result[1])
    ]);
}

proto.start_is_no_good = function(element) {
    var first_node = this.getFirstTextNode(element);
    var prev_node = this.getPreviousTextNode(element);

    if (! first_node) return true;
    if (first_node.nodeValue.match(/^ /)) return false;
    if (! prev_node) return false;
    if (prev_node.nodeValue.match(/^\n?[\xa0\ ]?/)) return false;
    if (prev_node.nodeValue == '\n') return false;
    return ! prev_node.nodeValue.match(/[\( "]$/);
}

/* Depth.js code */
if (! window.Page) {
    Page = {
        page_title: 'foo',
        wiki_title: 'bar'
    };
}

proto.convert_html_to_wikitext = function(html) {
    html = this.strip_msword_gunk(html);

    (function ($) {
        var dom = document.createElement("div");
        dom.innerHTML = html;

        // This needs to be done by hand for IE.
        // jQuery().replaceWith considered dangerous in IE.
        // It was causing stack overflow.
        if ($.browser.msie) {
            var elems = dom.getElementsByTagName('div');
            for (var i = 0, l = elems.length; i < l; i++) {
                if (elems[i].className != 'wiki') continue;
                var div = document.createElement('div');
                div.innerHTML = elems[i].innerHTML + '<br>\n';
                elems[i].parentNode.replaceChild(
                    div,
                    elems[i]
                );
            }
            html = dom.innerHTML;
        }
        else {
            var $dom = $(dom);

            $dom
            .find("div.wiki").each(function() { 
                $(this).replaceWith( $(this).html() + "<br>\n" );
            });

        // Try to find an user-pasted paragraph. With extra gecko-introduced \n
        // characters in there, which we need to remove.
            $dom.contents().each(function() {
                if (this.nodeType == 3 ) {
                    if (this.previousSibling && this.previousSibling.nodeType == 1 && this.previousSibling.nodeName != 'BR' ) {
                        return;
                    }

                    if (this.nextSibling && this.nextSibling.nodeType == 1 && this.nextSibling.nodeName != 'BR' ) {
                        return;
                    }

                    this.nodeValue = this.nodeValue
                    .replace(/^\n/, '')
                    .replace(/\n$/, '')
                    .replace(/\n/g, ' ');

                }
                else if ( $(this).is("p") ) {
                    if ( this.childNodes.length == 1 && this.childNodes[0].nodeType == 3) {
                        this.childNodes[0].nodeValue = this.childNodes[0].nodeValue
                            .replace(/^\n/, '')
                            .replace(/\n$/, '')
                            .replace(/\n/g, ' ');
                    }
                }
            });
            html = $dom.html();
        }
    })(jQuery);

    // XXX debugging stuff
//     if (String(location).match(/\?.*html$/))
//         YYY(html);

    this.copyhtml = html;
    var dom = document.createElement('div');
    dom.innerHTML = html;
    this.output = [];
    this.list_type = [];
    this.indent_level = 0;
    this.no_collapse_text = false;
    this.depth = 0;

    this.normalizeDomWhitespace(dom);
    this.normalizeDomStructure(dom);

//     if (String(location).match(/\?.*html2$/))
//         YYY(dom.innerHTML);

    this.dom = dom;

    // XXX debugging stuff
//     dom_copy = copyDom(dom);
//     if (String(location).match(/\?.*dump$/))
//         throw yyy(dom_copy);

    var wikitext = this.walk(dom).replace(/[\xa0\s\n]*$/, '\n');
//     if (String(location).match(/\?.*dump2$/))
//         throw yyy(copyDom(dom));
    return wikitext;
}

proto.walk = function(elem) {
    this.depth++;
    if (!elem) return '';

    for (var part = elem.firstChild; part; part = part.nextSibling) {
        if (part.nodeType == 1) {
            if (this.no_descend(part)) continue;
            part.wikitext = this.walk(part);
        }
    }

    this.wikitext = '';

    var fixups = [];
    for (var part = elem.firstChild; part; ) {

        if (part.nodeType == 3) {
            if (
                !(
                    part.nodeValue.match(/[^\n]/) &&
                    (! part.nodeValue.match(/^\n[\n\ \t]*$/))
                ) ||
                (
                    part.nodeValue.match(/^\s+$/) &&
                    part.previousSibling &&
                    part.previousSibling.nodeName == 'BR' &&
                    part.previousSibling.previousSibling &&
                    part.previousSibling.previousSibling.nodeName == 'BR'
                )
            ) {
                var node = part;
                part = part.nextSibling;
                node.parentNode.removeChild(node);
                continue;
            }
        }

        var method = 'format_' + part.nodeName.toLowerCase();
        if (method != 'format_blockquote' && part.is_indented)
            method = 'format_indent';
//         window.XXX_method = method = method.replace(/#/, '');
        method = method.replace(/#/, '');
        try {
            var text = this[method](part);
            if (part.fixup) {
                text = '\x07' + text + '\x07';
                fixups.push([part.fixup, part]);
            }

            if (!text) {
                part = part.nextSibling;
                continue;
            }

            if (this.wikitext &&
                part.top_level_block
            ) this.wikitext = this.wikitext.replace(/ *\n*$/, '\n\n');
            if (part.widget_on_widget) {
                this.wikitext = this.wikitext.replace(/\n*$/, '\n');
            }

            this.assert_trailing_space(part, text);
            this.wikitext += text;
        }
        catch(e) {
//             alert(method + ' ' + e.message);
//             delete(e.stack);
//             var error = yyy({
//                 'method': method,
//                 'e': e,
//                 'wikitext': this.wikitext
//             });
//             var dom_dump = yyy(dom_copy);
//             throw("Depth First Formatting Error:\n" + error + dom_dump);
        }
        part = part.nextSibling;
    }

    for (var i = 0; i < fixups.length; i++) {
        var fixup = fixups[i];
        this[fixup[0]](fixup[1]);
    }

    this.depth--;
    if (!(this.wikitext.length && this.wikitext.match(/\S/))) return '';
    return this.wikitext.replace(/\n+$/, '\n');
}

proto.assert_trailing_space = function(part, text) {
    if ((! part.requires_preceding_space) && (
            (! part.previousSibling) 
         || (! part.previousSibling.requires_trailing_space)
        )
    ) return;

    if (this.wikitext.match(/ $/)) return;

    if (this.wikitext.match(/\n$/)) {
        if (part.previousSibling &&
            part.previousSibling.nodeName == 'BR'
        ) return;
        this.wikitext = this.wikitext.replace(/\n$/, '');
    }

    if (! text.match(/^\s/))
        this.wikitext += ' ';
}

proto.no_descend = function(elem) {
    if (elem.nodeName == 'BLOCKQUOTE')
        elem.is_indented = true;
    else if (elem.nodeName.match(/^(P|DIV)$/)) {
        if (elem.style.marginLeft.match(/^(\d+)px/)) {
            elem.is_indented = Number(RegExp.$1);
        }
    }

    return Boolean(
        (
            elem.nodeName.match(/^(DIV|SPAN)$/) && 
            elem.className.match(/^(nlw_phrase|wafl_block)$/)
        ) ||
        (elem.nodeName == 'A' &&
        elem.lastChild &&
        elem.lastChild.nodeType == 8) ||
        (elem.nodeName == 'A') ||
        (
            (elem.nodeName == 'SPAN') &&
            this.get_wiki_comment(elem)
        )
    );
}

proto.check_start_of_block = function(elem) {
    var prev = elem.previousSibling;

    if (this.wikitext &&
        prev &&
        prev.top_level_block &&
        ! this.wikitext.match(/\n\n$/)
    ) this.wikitext += '\n';
}

proto.format_text = function(elem) {
    if (elem.previousSibling &&
        elem.previousSibling.nodeName == 'P' &&
        elem.previousSibling.wikitext == ''
    ) {
        elem.top_level_block = true;
    }

    this.check_start_of_block(elem);
    var text = elem.nodeValue.
        replace(/^\n+/, '').
        replace(/[\xa0 ]+/g, ' ');

    if (text.match(/^[\xa0\s]+$/) && (
        !elem.nextSibling || elem.nextSibling.nodeName == 'BR'
    )) return '';

    text = text.replace(/\xa0 /g,' ');
    text = text.replace(/\xa0/g,' ');
    return text;
}

proto.format_div = function(elem) {
    if (elem.className == 'nlw_phrase') {
        elem.top_level_block = true;
        return this.handle_nlw_phrase(elem);
    }
    if (elem.className == 'wafl_block')
        return this.handle_wafl_block(elem);
    var text = elem.wikitext;
    return text.
        replace(/^\s+$/, '').
        replace(/\n*$/, '\n');
}

proto.handle_nlw_phrase = function(elem) {
    this.check_start_of_block(elem);

    // XXX Maybe we should use get_wiki_comment.
    var comment = elem.lastChild;
    var text = Wikiwyg.htmlUnescape(comment.nodeValue).
        replace(/^\ wiki: ([\s\S]*?)\ ?$/, '$1').
        replace(/\n*$/, '').
        replace(/-=/g, '-').
        replace(/==/g, '=');
    elem.is_widget = true;
    var prev = elem.previousSibling;
    if (prev && prev.nodeName == 'BR' &&
        prev.previousSibling &&
        prev.previousSibling.is_widget
    ) elem.widget_on_widget = true;
    return this.handle_include(text, elem);
}

proto.handle_wafl_block = function(elem) {
    var comment = elem.lastChild;
    if (! comment) return;
    var text = comment.data;
    text = text.replace(/^ wiki:\s+/, '').
                replace(/-=/g, '-').
                replace(/==/g, '=');
    elem.top_level_block = true;
    return text;
}

proto.format_p = function(elem) {
    if (elem.className == 'padding' && ! this.wikitext) {
        if (Wikiwyg.is_ie) return '\n';
        return;
    }

    var text = elem.wikitext;
    elem.top_level_block = true;
    if (!text) {
        if (Wikiwyg.is_ie && elem == elem.parentNode.lastChild)
            return '\n';
        return;
    }
    // XXX Somehow an include wafl at the beginning of the text makes the
    // formatter print a P with a single space. Should fix that some day.
    if (text == ' ') return;

    return text.replace(/\s*$/, '\n');
}

proto.format_img = function(elem) {
    var widget = elem.getAttribute('widget');
    if (widget) {
        if (widget.match(/^\.\w+\n/))
            elem.top_level_block = true;
        else
            elem.is_widget = true;
            this.check_start_of_block(elem);
        var text = Wikiwyg.htmlUnescape(widget).
            replace(/-=/g, '-').
            replace(/==/g, '=');
        var prev = elem.previousSibling;
        var requires_preceding_space = false;

        if (!text.match(/\{\{.*\}\}/)) {
            if (!elem.top_level_block)
                elem.requires_trailing_space = true;
            if (prev &&
                !(prev.nodeType == 1 && prev.nodeName == 'BR') &&
                !prev.top_level_block) {
                if (prev.nodeType == 3 && Wikiwyg.is_ie) {
                    elem.requires_preceding_space = true;
                } else {
                    prev.requires_trailing_space = true;
                }
            }
        }

        text = this.handle_include(text, elem);

        if (widget.match(/^\.\w+\n/))
            text = text.replace(/\n*$/, '\n');

        // Dirty hack for {{{ ... }}} wikitext
        if (Wikiwyg.is_ie) {
            if (!text.match(/\{\{\{.*\}\}/))
                elem.requires_trailing_space = true;
        }

        if (prev && prev.nodeName == 'BR' &&
            prev.previousSibling &&
            prev.previousSibling.is_widget
        ) elem.widget_on_widget = true;
        return text;
    }
    var uri = elem.getAttribute('src');
    if (uri) {
        this.check_start_of_block(elem);
        return(uri);
    }
//     throw('unhandled image ' + elem.innerHTML);
}

proto.handle_include = function(text, elem) {
    if (text.match(/^{include:/)) {
        if (!this.wikitext || this.wikitext.match(/\n$/)) {
            var next = elem.nextSibling;
            if (next) {
                if (next.nodeType == 3 &&
                    next.nodeValue.match(/\S/)
                ) next.nodeValue = next.nodeValue.replace(/^\s*/, '');
                if (next.nodeType == 1)
                    next.wikitext = next.wikitext.replace(/^\s*/, '');
            }
        }
        this.is_include = true;
        elem.requires_trailing_space = null;
    }
    return text;
}

proto.format_span = function(elem) {
    if (
        (elem.className == 'nlw_phrase') ||
        this.get_wiki_comment(elem)
    ) return this.handle_nlw_phrase(elem);

    var style = this.squish_style_object_into_string(elem.style);

    /* If the style is not interesting, we pretend it's not there, instead
     * of reducing it to a single line. -- {bz: 1704}
     */
    if (!style || style == '') {
        if ((elem.parentNode.nodeName == 'P')
         && (elem.parentNode.className == 'MsoNormal')
        ) {
            /* However, MS-Office <p class="MsoNormal"><span>...</span></p> 
             * chunks do need to be squished into a single line.
             * See js-test/wikiwyg/t/wordpaste.t.js for details.
             */
        }
        else {
            return elem.wikitext;
        }
    }


    // It has line-level style markups; we're forced to make it a single line.
    elem.wikitext = elem.wikitext.replace(/\n/g, ' ').replace(/  */g, ' ');

    if (style.match(/font-weight: bold;/))
        elem.wikitext = this.format_b(elem);
    if (style.match(/font-style: italic;/))
        elem.wikitext = this.format_i(elem);
    if (style.match(/text-decoration: line-through;/))
        elem.wikitext = this.format_strike(elem);
    return elem.wikitext;
}

proto.format_indent = function(elem) {
    var px = elem.is_indented;
    while (px > 0) {
        elem.wikitext = this.format_blockquote(elem);
        px -= 40;
    }
    return elem.wikitext;
}

proto.format_blockquote = function(elem) {
    if ( ! 
        (
            elem.parentNode.is_indented || 
            (elem.previousSibling && elem.previousSibling.is_indented)
        )
    ) elem.top_level_block = true;
    else {
        this.wikitext = this.wikitext.replace(/ $/,'');
        if (this.wikitext && ! this.wikitext.match(/\n$/))
            this.wikitext += '\n';
    }
    return elem.wikitext.
        replace(/^[>]/mg, '>>').
        replace(/^([^>])/mg, '> $1').
        replace(/ *$/mg, '').
        replace(/\n*$/, '\n');
}

proto.format_li = function(elem) {
    return '\x07' +
        elem.wikitext.
            replace(/^\xa0$/, '').
            replace(/^\s*/, '').
            replace(/\n+/g, ' ').
            replace(/  +/, ' ').
            replace(/ *$/, '')
            + '\n';
}

proto.format_ul = function(elem) {
    if (! elem.parentNode.nodeName.match(/^(UL|OL)$/))
        elem.top_level_block = true;
    var text = elem.wikitext.
        replace(/^([*]+)( |$)/mg, '*$1$2').
        replace(/^([#]+)( |$)/mg, '#$1$2').
        replace(/^\x07$/mg, '*').
        replace(/^\x07(?=.)/mg, '* ');
    return text;
}

proto.format_ol = function(elem) {
    if (! elem.parentNode.nodeName.match(/^(UL|OL)$/))
        elem.top_level_block = true;
    var text = elem.wikitext.
        replace(/^([*]+)( |$)/mg, '*$1$2').
        replace(/^([#]+)( |$)/mg, '#$1$2').
        replace(/^\x07$/mg, '#').
        replace(/^\x07(?=.)/mg, '# ');
    return text;
}

proto.format_table = function(elem) {
    elem.top_level_block = true;
    return elem.wikitext;
}

proto.format_tr = function(elem) {
    return elem.wikitext + '|\n';
}

proto.format_td = function(elem) {
    if (
        elem.firstChild &&
        elem.firstChild.nodeName.match(/^(H[123456])$/)
    ) {
        elem.wikitext = elem.wikitext.replace(/\n?$/, '\n');
        return '| ' + elem.wikitext;
    }

    if (
        elem.firstChild &&
        elem.firstChild.nodeName.match(/^(OL|UL|BLOCKQUOTE)$/)
    ) {
        elem.wikitext = '\n' + elem.wikitext.replace(/\n$/, ' ');
        return '| ' + elem.wikitext;
    }

    if (elem.wikitext.match(/\n/) ||
        (elem.firstChild && elem.firstChild.top_level_block)
    ) {
        elem.wikitext = elem.wikitext.replace(/\n$/, ' ');
        return '| ' + elem.wikitext;
    }
    else {
        var style = this.squish_style_object_into_string(
            elem.getAttribute('style')
        );
        if (style && style.match(/font-weight: bold;/))
            elem.wikitext = this.format_b(elem);
    }

    return '| ' + elem.wikitext + ' ';
}

proto.format_th = proto.format_td;

proto.format_tbody = function(elem) {
    return elem.wikitext;
}

proto.format_h1 = function(elem) {
    elem.top_level_block = true;
    var text = '^ ' + elem.wikitext;
    return text.replace(/\n*$/, '\n');
}

proto.format_h2 = function(elem) {
    elem.top_level_block = true;
    var text = '^^ ' + elem.wikitext;
    return text.replace(/\n*$/, '\n');
}

proto.format_h3 = function(elem) {
    elem.top_level_block = true;
    var text = '^^^ ' + elem.wikitext;
    return text.replace(/\n*$/, '\n');
}

proto.format_h4 = function(elem) {
    elem.top_level_block = true;
    var text = '^^^^ ' + elem.wikitext;
    return text.replace(/\n*$/, '\n');
}

proto.format_h5 = function(elem) {
    elem.top_level_block = true;
    var text = '^^^^^ ' + elem.wikitext;
    return text.replace(/\n*$/, '\n');
}

proto.format_h6 = function(elem) {
    elem.top_level_block = true;
    var text = '^^^^^^ ' + elem.wikitext;
    return text.replace(/\n*$/, '\n');
}

proto.format_pre = function(elem) {
    var data = Wikiwyg.htmlUnescape(elem.innerHTML);
    data = data.replace(/<br>/g, '\n')
               .replace(/\n$/, '')
               .replace(/^&nbsp;$/, '\n');
    elem.top_level_block = true;
    return '.pre\n' + data + '\n.pre\n';
}

proto.format_a = function(elem) {
    if (elem.innerHTML == '') {
        /* An empty anchor should not render into <> or []: {bz: 1691} */
        return '';
    }

    this.check_start_of_block(elem);
    var label = Wikiwyg.htmlUnescape(elem.innerHTML);
    label = label.replace(/<[^>]*?>/g, ' ');
    label = label.replace(/\s+/g, ' ');
    label = label.replace(/^\s+/, '');
    label = label.replace(/\s+$/, '');

    var href = elem.href;

    if (! href) href = ''; // Necessary for <a name="xyz"></a>'s
    var link = this.make_wikitext_link(label, href, elem);

    // For [...] links, we need to ensure there are surrounding spaces
    // because it won't take effect when put adjacent to word characters.
    if (link.match(/^\[/)) {
        // Turns "foo[bar]" into "foo [bar]"
        var prev_node = this.getPreviousTextNode(elem);
        if (prev_node && prev_node.nodeValue.match(/\w$/)) {
            link = ' ' + link;
        }

        // Turns "[bar]baz" into "[bar] baz"
        var next_node = this.getNextTextNode(elem);
        if (next_node && next_node.nodeValue.match(/^\w/)) {
            link = link + ' ';
        }
    }

    elem.fixup = 'strip_ears';

    return link;
}

// Remove < > (ears) from links if possible
proto.strip_ears = function(elem) {
    var self = this;
    this.wikitext = this.wikitext.replace(
        /(^|[\s\S])\x07([^\x07]*)\x07([\s\S]|$)/, function($0, $1, $2, $3) {
            var link = $2;
            if (link.match(/\s/))
                return $1 + link + $3;
            if (self.wikitext.match(/>\x07$/)) {
                if (self.is_italic(elem.parentNode))
                    return $1 + link;
            }
            if (
                (! ($1.match(/\S/) || $3.match(/\S/))) ||
                ($1 == "'" && ! $3.match(/\S/))
            ) link = link.replace(/^<(.*)>$/, '$1');
            return $1 + link + $3;
        }
    );
}

proto.is_italic = function(elem) {
    var self = this;
    return (elem &&
        (
            elem.nodeName == 'I' ||
            elem.nodeName == 'EM' ||
            (
                elem.nodeName == 'SPAN' &&
                (function(elem) {
                    return self.squish_style_object_into_string(
                        elem.getAttribute('style')
                    ).match(/font-style: italic;/)
                })(elem)
            )
        )
    );
}

proto.make_wikitext_link = function(label, href, elem) {
    var mailto = href.match(/^mailto:(.*)/);

    if (this.is_renamed_hyper_link(elem)) {
        var link = this.get_wiki_comment(elem).data.
            // The following line is a workaround for an apparent jQuery bug
            // that I couldn't fix.
            replace(/><\/http>\s$/, '/>').
            replace(/^\s*wiki-renamed-hyperlink\s*/, '').
            replace(/\s*$/, '').
            replace(/=-/g, '-');
        return(link);
    }
    else if (elem.wiki_page || (this.href_is_wiki_link(href) &&
        this.href_is_really_a_wiki_link(href))
    ) {
        return this.handle_wiki_link(label, href, elem);
    }
    else if (mailto) {
        var address =
            (jQuery.browser.msie && jQuery.browser.version == 6)
            ? mailto[1]
            : mailto[1].replace(/\%25/g, '%');

        if (address == label)
            return address;
        else
            return '"' + label + '"<' + href + '>';
    }
    else {
        if (href == label)
            return '<' + href + '>';
        else if (this.looks_like_a_url(label)) {
            return '<' + label + '>';
        }
        else {
            return '"' + label + '"<' + href + '>';
        }
    }
}

proto.handle_wiki_link = function(label, href, elem) {
    var href_orig = href;
    href = href.replace(/.*\?/, '');
    href = decodeURI(escape(href));
    href = href.replace(/_/g, ' ');
    // XXX more conversion/normalization poo
    // We don't yet have a smart way to get to page->Subject->metadata
    // from page->id
    if (label == href_orig && !(label.match(/=/))) {
        return '[' + (elem.wiki_page || href) + ']';
    }
    else if ((elem.wiki_page || this.is_renamed_wiki_link(elem)) &&
             ! this.href_label_similar(elem, href, label))
    {
        var link = elem.wiki_page || this.get_wiki_comment(elem).data.
            replace(/^\s*wiki-renamed-link\s*/, '').
            replace(/\s*$/, '').
            replace(/=-/g, '-');
        return '"' + label + '"[' + link + ']';
    }
    else {
        return '[' + (elem.wiki_page || label) + ']';
    }
}

proto.get_wiki_comment = function(elem) {
    for (var node = elem.firstChild; node; node = node.nextSibling) {
        if (node.nodeType == this.COMMENT_NODE_TYPE
            && node.data.match(/^\s*wiki/)
        ) {
            return node;
        }
    }
    return null;
}

proto.format_br = function(elem) {
    if (Wikiwyg.is_ie) 
       this.wikitext = this.wikitext.replace(/\xA0/, "");
    return (this.wikitext && !this.wikitext.match(/\n\n$/)) ? '\n' : '';
}

proto.format_hr = function(elem) {
    if (this.has_parent(elem, 'LI')) return '';
    elem.top_level_block = true;
    return '----\n';
}

proto.has_parent = function(elem, name) {
    while (elem = elem.parentNode) {
        if (elem.nodeName == name) return true;
    }
    return false;
}

// Build trivial bound_phrase formatters
;(function() {
    var build_bound_phrase_formatter = function(style) {
        return function(elem) {
            this.check_start_of_block(elem);
            var markup = this.config.markupRules[style];
            var markup_open = markup[1];
            var markup_close = markup[2] || markup_open;

            var wikitext = elem.wikitext;

            var prev_node = elem.previousSibling;
            if (prev_node && prev_node.nodeType == 3) { // Same as .getPreviousTextNode
                if (prev_node.nodeValue.match(/\w$/) && wikitext.match(/^\S/)) {
                    // If there is no room for markup at the front, discard the markup.
                    // Example: "x<b>y</b> z" should become "xy z", not "x*y* z".
                    return wikitext;
                }
                else if (prev_node.nodeValue.match(/\s$/)) {
                    // Strip whitespace at the front if there's already
                    // trailing whitespace from the previous node.
                    // Example: "x <b> y</b>" becomes "x <b>y</b>".
                    wikitext = wikitext.replace(/^\s+/, '');
                }
            }

            var next_node = elem.nextSibling;
            if (next_node && next_node.nodeType == 3) { // Same as .getNextTextNode
                if (next_node.nodeValue.match(/^\w/) && wikitext.match(/\S$/)) {
                    // If there is no room for markup at the end, discard the markup.
                    // Example: "x <b>y</b>z" should become "x yz", not "x *y*z".
                    return wikitext;
                }
                else if (next_node.nodeValue.match(/^\s/)) {
                    // Strip whitespace at the end if there's already
                    // leading whitespace from the next node.
                    // Example: "x <b> y</b>" becomes "x <b>y</b>".
                    wikitext = wikitext.replace(/\s+$/, '');
                }
            }

            // Finally, move whitespace outward so only non-whitespace
            // characters are put into markup.
            // Example: "x<b> y </b>z" becomes "x *y* z".
            return wikitext
                .replace(/^(\s*)/, "$1" + markup_open)
                .replace(/(\s*)$/, markup_close + "$1");
        }
    }

    // These tags are trivial ones.
    var style_of = {
        b: 'bold',
        strong: 'bold',
        i: 'italic',
        em: 'italic',
        strike: 'strike',
        del: 'strike',
        s: 'strike',
        tt: 'code',
        code: 'code',
        kbd: 'code',
        samp: 'code',
        'var': 'code',
        u: 'underline'
    };

    for(var tag in style_of) {
        proto[ "format_" + tag ] = build_bound_phrase_formatter( style_of[ tag ] );
    }
})();

