(function($) {

var t = new Test.Visual();

t.plan(2);

t.checkRichTextSupport();

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_1318",
            content: "{toc}\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe("/admin/index.cgi?bz_1318", t.nextStep());
    },
            
    function() { 
        t.$('#st-edit-button-link').click();

        setTimeout(function(){
            var ww = t.iframe.contentWindow.Wikiwyg.Wysiwyg.Socialtext.prototype;
            var img = $(
                t.$('#st-page-editing-wysiwyg').get(0).contentWindow.document.documentElement
            ).find('img').get(0);
            ww.getWidgetInput(img, false, false);

            t.ok(
                t.$('#st-widget-cancelbutton').is(':visible'),
                "Clicking on the TOC image brings out a wikiwyg widget form"
            );

            t.$('#st-widget-cancelbutton').click();

            t.$('#st-save-button-link').click();

            t.ok(
                true,
                "Dismissing the TOC image did not raise javascript errors"
            );

            t.endAsync();
        }, 10000)
    }
]);

})(jQuery);
