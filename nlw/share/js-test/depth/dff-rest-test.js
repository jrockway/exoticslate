
/* To Do:

* Grab 10 pages (wikitext) from corp.
* Roundtrip each page.
* If different call a server diff function.

*/

DFF = function() {
    this.url = '/admin/index.cgi';
    this.cred = {
        userid: 'devnull1@socialtext.com',
        passwd: 'd3vnu11l'
    };
}

proto = DFF.prototype;

proto.rest_test = function() {
    var run_all = document.forms.dff_start.run_all;
    var self = this;
    run_all.onclick = function() {
        self.run_all_tests(run_all);
    }


    document.forms.dff_start.purge_good.onclick = function() {
        self.purge_good_tests();
    };

    var form = document.forms[0];
    this.dffServer = form.dff_server.value;
    this.dffCount = form.dff_count.value;
    this.dffSkip = form.dff_skip.value;
    var postdata = 'action=wikiwyg_dff_rest_test_pages' +
        ';dff_server=' + this.dffServer +
        ';dff_count=' + (Number(this.dffCount) + Number(this.dffSkip));
    jQuery("#test").html("Loading pages...");

    Ajax.post(
        this.url,
        postdata,
        function(result) {
            jQuery("#test").empty();
            var data = JSON.parse(result);
            var list = document.getElementById('output');
            list.innerHTML = '';
            for (var i = Number(self.dffSkip); i < data.length; i++) {
                var elem = data[i];
                var item = document.createElement('li');
                var link = document.createElement('a');
                link.setAttribute('href', elem.page_uri);
                link.setAttribute('title', "Click it to run an individual test, right-click it to open this page from menu.");
                link.innerHTML = elem.name;

                jQuery(link).addClass("run");
                item.appendChild(link);
                list.appendChild(item);

                jQuery(item).prepend( (1+i) + ". ");
                jQuery(link).click((function(node, stuff) {
                    return function() {
                        self.process_page(node, stuff);
                        return false;
                    };
                })(item, elem));
            }
        },
        this.cred
    );
}

proto.run_all_tests = function(e) {
    e.onclick = function() { return false };
    var li = document.getElementsByTagName('li')[0];
    var runner = function(elem) {
        if (elem) {
            var next = elem.nextSibling;

            jQuery(elem).find("a.run").click();

            if (!next) return;

            setTimeout(
                function() {
                    runner(next);
                }, 1000
            )
        }
    }
    runner(li);
}

proto.purge_good_tests = function() {
    jQuery("#output li.good").remove();
};

dffSimpleModeHtml = true;

proto.process_page = function(item, data) {
    if (item.nextSibling && item.nextSibling.nodeName == 'PRE') {
        item.parentNode.removeChild(item.nextSibling);
        return;
    }

    var postdata = 'action=wikiwyg_dff_get_page' +
        ';dff_server=' + this.dffServer +
        ';page_id=' + data.page_id;
    var wikitext = Ajax.post(this.url, postdata, null, this.cred);

    var postdata = 'action=wikiwyg_wikitext_to_html;content=' +
        encodeURIComponent(wikitext);

    var self = this;
    var html = Ajax.post(
        this.url,
        postdata,
        function(html) {
            var wikitext1Object = new Wikiwyg.Wikitext.SocialtextOld();
            var wikitext2Object = new Wikiwyg.Wikitext.Socialtext();

            if (dffSimpleModeHtml) {
                var wysiwygObject = self.create_wysiwyg_object();
                wysiwygObject.fromHtml(html);
                var html = wysiwygObject.get_inner_html();

                wikitext1Object.wikiwyg = wysiwygObject.wikiwyg;
                wikitext1Object.set_config();

                wikitext2Object.wikiwyg = wysiwygObject.wikiwyg;
                wikitext2Object.set_config();
            }

            var wikitext1 = wikitext1Object.convert_html_to_wikitext(html);
            var wikitext2 = wikitext2Object.convert_html_to_wikitext(html);

            if (wikitext1 == wikitext2) {
                jQuery(item).removeClass("bad");
                jQuery(item).addClass("good");
            }
            else {
                jQuery(item).removeClass("lookgood");
                jQuery(item).addClass("bad");
                self.show_diff(item, wikitext1, wikitext2);
            }
        },
        this.cred
    );
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

proto.show_diff = function(item, wikitext1, wikitext2) {
    var postdata = 'action=wikiwyg_dff_diff' +
        ';text1=' + encodeURIComponent(wikitext1) +
        ';text2=' + encodeURIComponent(wikitext2);
    document.getElementById('test').innerHTML = '';
    var pre = document.createElement('pre');
    var text = document.createTextNode("");
    pre.appendChild(text);


    jQuery("<a href='#'> (Looks Good)</a>").appendTo(item)
        .addClass("looksgood")
        .click(
        function() {
            jQuery(this).parent().addClass("lookgood").
                removeClass("bad").next().remove();
            jQuery(this).remove();
            return false;
        }
    );

    jQuery(pre).insertAfter(item);

    Ajax.post(
        this.url,
        postdata,
        function(diff) {
            if (Wikiwyg.is_ie)
                diff = diff.replace(/\n/g,'\r\n');
            text.nodeValue = diff;
        },
        this.cred
    );
}

