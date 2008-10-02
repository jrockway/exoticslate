(function($) {

var t = new Test.Visual();

t.plan(3);

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_1347",
            content: "VeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLineVeryLongLine",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe("/admin/index.cgi?bz_1347", t.nextStep());
    },
            
    function() { 
        t.is(
            t.$('#contentLeft').css('overflow'),
            'visible',
            "Long content lines overflows rightward as needed" 
        );

        t.ok(
            (t.$('#mainWrap').width() > t.$('#contentLeft').width()),
            "Main wrapper gets resized along with overlong content"
        );

        t.is(
            t.$('#contentLeft').offset().top,
            t.$('#contentRight').offset().top,
            "Long content lines does not cause contentRight to move downward"
        );

        t.endAsync();
    }
]);

})(jQuery);
