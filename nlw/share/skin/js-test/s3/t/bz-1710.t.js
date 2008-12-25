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
            page_name: "bz_1710",
            content: ".html\n"
                   + "X&nbsp;Y\n"
                   + ".html\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe(
            "/admin/index.cgi?bz_1710",
            t.nextStep()
        );
    },

    function() { 
         t.$('#st-edit-button-link').click();
         t.poll(
            function() { return wikiwyg_started() },
            function() { t.callNextStep(2000) }
        );
    },
            
    function() { 
        if (wikitextModeIsReady()) {
             t.callNextStep(0);
             return;
        }
        t.$('#st-mode-wikitext-button').click();
        t.poll(wikitextModeIsReady, function() {t.callNextStep(2000);});
    },

    function() { 
        t.unlike(
            t.$('#wikiwyg_wikitext_textarea').val(),
            /XnbspY/,
            "Wikitext mode should not cripple ampersand and semicolons in .html widgets"
        );

        t.$('#st-mode-wysiwyg-button').click();
        t.$('#st-save-button-link').click();
        t.endAsync();
    }
]);

})(jQuery);
