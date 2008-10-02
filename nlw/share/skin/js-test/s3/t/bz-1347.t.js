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
        t.ok(
            (t.$('div.wiki').width() > t.$('#controls').width()),
            "Long content lines overflows rightward as needed" 
        );

        t.like(
            t.$('#contentLeft').css('background-color'),
            '^#[fF]+$|^(rgb|RGB)\\\(255\\s*,\\s*255\\s*,\\s*255\\\)$',
            "Left content column has its own white background"
        );

        t.isnt(
            t.$('#contentLeft').offset().top,
            t.$('#contentRight').offset().top,
            "Long content lines pushes contentRight controls downward"
        );

        t.endAsync();
    }
]);

})(jQuery);
