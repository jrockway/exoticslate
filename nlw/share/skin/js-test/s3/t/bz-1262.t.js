(function($) {

var t = new Test.Visual();

t.plan(1);

var name = "bz_1262_really_long_"
    + Date.now() + Date.now() + Date.now() + Date.now()
    + Date.now() + Date.now() + Date.now() + Date.now();

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: name,
            content: name,
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe(
            "/admin/index.cgi?" + name + "#edit",
            t.nextStep(3000)
        );
    },
            
    function() { 
        t.elements_do_not_overlap(
            t.$('#st-editing-title'),
            t.$('#st-edit-mode-toolbar'),
            "Overlong page names should truncate, not overlapping edit toolbar"
        );
        t.endAsync();
    }
]);

})(jQuery);
