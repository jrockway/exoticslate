(function($) {

var t = new Test.Visual();

t.plan(1);

function wikiwyg_started() {
    return (t.win.wikiwyg && t.win.wikiwyg.is_editing);
}

function wikitextModeIsReady() {
    return (
        (t.win.wikiwyg.current_mode.classtype == 'wikitext') &&
        t.$('#wikiwyg_wikitext_textarea').is(':visible')
    );
}

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_1690",
            content: ".html\n"
                   + "foo\n"
                   + ".html\n"
                   + "bar\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe(
            "/admin/index.cgi?bz_1690",
            t.nextStep()
        );
    },

    t.doWikitextEdit(),

    function() { 
        t.like(
            t.$('#wikiwyg_wikitext_textarea').val(),
            /^\.html\nfoo\n\.html\n+bar/,
            "Wikitext mode should not cripple .html widgets"
        );

        t.$('#st-mode-wysiwyg-button').click();
        t.$('#st-save-button-link').click();
        t.endAsync();
    }
]);

})(jQuery);
