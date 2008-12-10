(function($) {

var t = new Test.Visual();

t.plan(2);

t.checkRichTextSupport();

var iframeHeight;

function wikiwyg_started() {
    return (t.win.wikiwyg && t.win.wikiwyg.is_editing);
}

function richtextModeIsReady() {
    return (
        (t.win.wikiwyg.current_mode.classtype == 'wysiwyg') &&
        $(
            t.$('#st-page-editing-wysiwyg').get(0)
             .contentWindow.document.documentElement
        ).find('h1').is(':visible')
    );
};

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
         t.$('#st-edit-button-link').click();
         t.poll(
            function() { return wikiwyg_started() },
            function() { t.callNextStep() }
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

    function() { 
        t.$('#st-edit-button-link').click();
        t.poll(
            function() { return wikiwyg_started() },
            function() { t.callNextStep() }
        );
    },

    function() { 
        var $editArea = t.$('iframe#st-page-editing-wysiwyg');
        t.ok(
            ($editArea.offset().left + $editArea.width())
                < (t.$('#st-edit-mode-view').offset().left + t.$('#st-edit-mode-view').width()),
            "Edit area's right edge does not go beyond the page"
        );

        t.$('#st-save-button-link').click();
        t.endAsync();
    }
]);

})(jQuery);
