(function($) {

var t = new Test.Visual();

t.plan(1);

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

    t.doWikitextEdit(),

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
