(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_1116",
            content: "test\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe(
            "/admin/index.cgi?bz_1116",
            t.nextStep()
        );
    },

    t.doWikitextEdit(),

    function() { 
        t.win.wikiwyg.current_mode.insert_widget('{file: bz_1116}');
        t.like(
            t.$('#wikiwyg_wikitext_textarea').val(),
            /^\n\{file: bz_1116\}\ntest/
        );
        t.endAsync();
    }
]);

})(jQuery);
