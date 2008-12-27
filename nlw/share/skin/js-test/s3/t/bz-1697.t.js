(function($) {

var t = new Test.Visual();

t.plan(2);

t.checkRichTextSupport();

var iframeHeight;

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_1697",
            content: "Test\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe(
            "/admin/index.cgi?bz_1697",
            t.nextStep(),
            {w: 1024}
        );
    },

    function() { 
        t.win.Cookie.del("ui_is_expanded");
        t.$('#st-edit-button-link').click();

        t.poll(
            function() { return t.wikiwyg_started() },
            function() { t.callNextStep(5000) }
        );
    },

    function() { 
        t.$('#st-edit-pagetools-expand').click();

        var $editArea = t.$('iframe#st-page-editing-wysiwyg');
        t.ok(
            ($editArea.offset().left + $editArea.width())
                < (t.$('#st-edit-mode-view').offset().left + t.$('#st-edit-mode-view').width()),
            "Edit area's right edge does not go beyond the page"
        );

        t.$('#st-save-button-link').click();

        t.open_iframe(
            "/admin/index.cgi?bz_1697",
            t.nextStep(),
            {w: 1024}
        );
    },

    t.doRichtextEdit(),

    function() { 
        var $editArea = t.$('iframe#st-page-editing-wysiwyg');
        t.ok(
            ($editArea.offset().left + $editArea.width())
                < (t.$('#st-edit-mode-view').offset().left + t.$('#st-edit-mode-view').width()),
            "Edit area's right edge does not go beyond the page"
        );

        t.win.Cookie.del("ui_is_expanded");
        t.$('#st-save-button-link').click();
        t.endAsync();
    }
]);

})(jQuery);
