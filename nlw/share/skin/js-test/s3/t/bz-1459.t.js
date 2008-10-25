(function($) {

var t = new Test.Visual();

t.plan(1);

if (!$.browser.safari) {
    t.skipAll("This test is Safari-specific");
}

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
            t.$('#contentLeft').css('overflow-y'),
            'hidden',
            "Safari needs overflow-y set to 'hidden' to hide the scrollbar"
        );

        t.endAsync();
    }
]);

})(jQuery);
