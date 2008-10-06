(function($) {

var t = new Test.Visual();

t.plan(2);

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_1459",
            content: "NotVeryLongLine",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe("/admin/index.cgi?bz_1459", t.nextStep());
    },
            
    function() { 
        t.is(
            t.$('#contentLeft').css('overflow'),
            'auto',
            "Show content lines need not overflow rightward"
        );

        if ($.browser.safari) {
            t.is(
                t.$('#contentLeft').css('overflow-y'),
                'hidden',
                "Safari needs overflow-y set to 'hidden' to hide the scrollbar"
            );
        }
        else {
            t.skip("This test is Safari-specific");
        }

        t.endAsync();
    }
]);

})(jQuery);
