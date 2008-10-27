(function($) {

var t = new Test.Visual();

t.plan(4);

if (jQuery.browser.msie)
    t.skipAll("Skipping this insanity on IE for now");

t.checkRichTextSupport();

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_554",
            content: '"<&>"<http://example.org/>\n',
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe("/admin/index.cgi?bz_554", t.nextStep());
    },
            
    function() { 
        t.is(
            t.$('div.wiki a').text(),
            "<&>",
            "Special chars in link text is recognized correctly (text)"
        );

        t.is(
            t.$('div.wiki a').attr('href'),
            "http://example.org/",
            "Special chars in link text is recognized correctly (href)"
        );

        t.put_page({
            workspace: 'admin',
            page_name: "bz_554",
            content: '\n',
            callback: t.nextStep()
        });

    },

    function() { 
        t.$('#st-edit-button-link').click();
        t.callNextStep(7500);
    },

    function() {
        t.$('#wikiwyg_button_link').click();
        t.callNextStep(3000);
    },


    function() { 
        t.$('#add-web-link').click();
        t.callNextStep(3000);
    },

    function() { 
        t.$('#web-link-text').val('<&>');
        t.$('#web-link-destination').val('http://example.org/');
        t.$('#add-a-link-form').submit();
        t.callNextStep(3000);
    },

    function() { 
        t.$('#st-save-button-link').click();
        t.callNextStep(5000);
    },

    function() { 
        t.is(
            t.$('div.wiki a').text(),
            "<&>",
            "Special chars in link text is recognized correctly (text)"
        );

        t.is(
            t.$('div.wiki a').attr('href'),
            "http://example.org/",
            "Special chars in link text is recognized correctly (href)"
        );

        t.endAsync();
    }
]);

})(jQuery);
