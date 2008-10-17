(function($) {

var t = new Test.Visual();

t.plan(2);

t.runAsync([
    function() {
        var v = "VeryLongLineVeryLongLine"
              + "VeryLongLineVeryLongLine"
              + "VeryLongLine ";

        t.put_page({
            workspace: 'admin',
            page_name: "bz_1477",
            content: v + v + v + v + v + "\n\n"
                   + ".pre\n"
                   + v + v + v + v + "\n"
                   + ".pre\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe("/admin/index.cgi?bz_1477", t.nextStep());
    },
            
    function() { 
        var clWidth = t.$('#contentLeft').width();

        t.$('#st-page-boxes-toggle-link').click();

        t.isnt(
            clWidth,
            t.$('#contentLeft').width(),
            "Hiding contentRight will change contentLeft's width"
        );

        t.$('#st-page-boxes-toggle-link').click();

        t.is(
            clWidth,
            t.$('#contentLeft').width(),
            "Showing contentRight will change contentLeft's width"
        );

        t.endAsync();
    }
]);

})(jQuery);
