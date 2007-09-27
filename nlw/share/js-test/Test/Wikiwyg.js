proto = new Subclass('Test.Wikiwyg', 'Test.Base');

proto.init = function() {
    Test.Base.prototype.init.call(this);
    this.block_class = 'Test.Wikiwyg.Block';
}

proto.run_roundtrip = function(section_name, section_name2) {
    if ( Wikiwyg.is_safari ) {
        this.skip("Skip roundtrip tests on Safari");
        return;
    }

    if (Wikiwyg.is_ie) {
        var self = this;

        var t = 10000
        var id = this.builder.beginAsync(t + 1000);
        setTimeout(function() {
            self.run_roundtrip_sync(section_name, section_name2);

            self.builder.endAsync(id)
        }, 300)
    }
    else {
        this.run_roundtrip_sync(section_name, section_name2);
    }
}

proto.run_roundtrip_sync = function(section_name, section_name2) {
    try {
        this.compile();
        var blocks =  this.state.blocks;
        for (var i = 0; i < blocks.length; i++) {
            var block = blocks[i];
            if (! this.verify_block(block, section_name)) continue;
            var wikitext = block.data[section_name];
            var wikitext2 = this.do_roundtrip(wikitext);
            if (section_name2)
                wikitext = block.data[section_name2];
                
            this.is(
                wikitext2.replace(/\r/g, ''),
                wikitext.replace(/\r/g, ''),
                block.name
            );
        }
    }
    catch(e) {
        // alert(e);
        throw(e);
    }
}

proto.do_roundtrip = function(wikitext, cb) {
    var url = '/admin/index.cgi';
    var postdata = 'action=wikiwyg_wikitext_to_html;content=' +
        encodeURIComponent(wikitext);
    var html = Ajax.post(url, postdata);
    var wysiwygObject = this.create_wysiwyg_object();
    wysiwygObject.fromHtml(html);

    if ( cb ) {
        var cb2 = function(html2) {
            var wikitextObject = new Wikiwyg.Wikitext.Socialtext();
            wikitextObject.wikiwyg = wysiwygObject.wikiwyg;
            wikitextObject.set_config();
            var wikitext2 = wikitextObject.convert_html_to_wikitext(html2);
            cb(wikitext2);
        };
        wysiwygObject.get_inner_html( cb2 );
        return;
    }

    var html2 = wysiwygObject.get_inner_html();
    var wikitextObject = new Wikiwyg.Wikitext.Socialtext();
    wikitextObject.wikiwyg = wysiwygObject.wikiwyg;
    wikitextObject.set_config();
    return wikitextObject.convert_html_to_wikitext(html2);
}

proto.create_wysiwyg_object = function(html) {
    var wikiwyg = new Wikiwyg.Socialtext();
    wikiwyg.set_config();
    var wysiwyg = new Wikiwyg.Wysiwyg.Socialtext();
    wysiwyg.show_messages = function() {};
    wysiwyg.config.iframeId = "wikiwyg_iframe";
    wysiwyg.wikiwyg = wikiwyg;
    wysiwyg.initializeObject();
    return wysiwyg;
}

proto = Subclass('Test.Wikiwyg.Block', 'Test.Base.Block');

proto.init = function() {
    Test.Base.Block.prototype.init.call(this);
    this.filter_object = new Test.Wikiwyg.Filter();
}

proto = new Subclass('Test.Wikiwyg.Filter', 'Test.Base.Filter');

proto.html_to_wikitext = function(content) {
    var object = new Wikiwyg.Wikitext.Socialtext();
    return object.convert_html_to_wikitext(content);
}

proto.template_vars = function(content) {
    return content.replace(
        /\[\%BASE_URL\%\]/g,
        'http://talc.socialtext.net:21002/static/1.1.1.1/js-test/run'
    ).replace(
        /\[\%THIS_URL\%\]/g,
        window.location
    );
}

proto.dom_sanitize  = function(content) {
    var html = content;
    var dom = document.createElement('div');
    dom.innerHTML = html;
    (new Wikiwyg.Wikitext.Socialtext()).normalizeDomStructure(dom);
    var html2 = dom.innerHTML;
    if (! html2.match(/\n$/))
        html2 += '\n';
    return html2;
}
 
