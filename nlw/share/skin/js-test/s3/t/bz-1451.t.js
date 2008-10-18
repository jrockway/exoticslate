(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_1451",
            content: "{image: x} x",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe("/admin/index.cgi?bz_1451#edit", t.nextStep(5000));
    },
            
    function() { 
        t.$('a[do=do_hr]').click();
        t.callNextStep(1500);
    },
            
    function() { 
        t.$('#st-save-button-link').click();
        t.callNextStep(5000);
    },
            
    function() { 
        t.is(
            t.$('div.wiki').children('*').get(0).tagName.toLowerCase(),
            'hr',
            "Horizontal line should be inserted before the WAFL"
        );

        t.endAsync();
    }
]);

})(jQuery);
