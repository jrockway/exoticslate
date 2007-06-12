proto = new Subclass('Test.Wikiwyg', 'Test.Base');

proto.init = function() {
    Test.Base.prototype.init.call(this);
    this.block_class = 'Test.Wikiwyg.Block';
}

proto.run_roundtrip = function(section_name, section_name2) {
    if ( Wikiwyg.is_ie ) {
        this.run_roundtrip_async(section_name, section_name2);
    }
    else {
        this.run_roundtrip_sync(section_name, section_name2);
    }
}

proto.run_roundtrip_async = function(section_name, section_name2) {
    this.pause = function() { };

    if ( Wikiwyg.is_safari ) {
        this.skip("Skip roundtrip tests on Safari");
        return;
    }

    if ( typeof(section_name2) == 'undefined' ) {
        section_name2 = section_name;
    }

    this.compile();
    var total_blocks = 0;
    var blocks = this.state.blocks;
    for (var i = 0; i < blocks.length; i++) {
        var block = blocks[i];
        if (! this.verify_block(block, section_name)) continue;
        total_blocks++;
    }

    var asyncId = this.builder.beginAsync(3600);
    var finished_tests = 0;
    this.run_roundtrip_async2(section_name, section_name2,
        function() {
            finished_tests++;
            if ( finished_tests == total_blocks ) {
                t.builder.endAsync(asyncId);
                this.pause = Test.Wikiwyg.prototype.pause;
            }
        }
    );

}

proto.run_roundtrip_async2 = function(section_name, section_name2, func) {
    try {
        var blocks =  this.state.blocks;
        for (var i = 0; i < blocks.length; i++) {
            var block = blocks[i];
            if (! this.verify_block(block, section_name)) continue;
            var wikitext = block.data[section_name];
            var self = this;
            var cb = (function( block, section_name2 ) {
                return function( wikitext2 ) {
                    if (section_name2)
                        wikitext = block.data[section_name2];

                    self.is(
                        wikitext2.replace(/\r/g, ''),
                        wikitext.replace(/\r/g, ''),
                        block.name
                    );
                    if (func) {
                        func();
                    }
                }
            })(block, section_name2);

            this.do_roundtrip(wikitext, cb);
        }
    }
    catch(e) {
        // alert(e);
        throw(e);
    }
}

proto.run_roundtrip_sync = function(section_name, section_name2) {
    if ( Wikiwyg.is_safari ) {
        this.skip("Skip roundtrip tests on Safari");
        return;
    }
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
    this.pause();
    return wysiwyg;
}

proto.pause = function() {
    if (/MSIE/.test(navigator.userAgent)) {
        alert("Pause...");
    }
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
 
