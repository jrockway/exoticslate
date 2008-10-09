(function($) {

var t = new Test.Visual();

t.plan(2);

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_1200",
            content: "{toc:}\n\n"
                   + '^^ "Foo"<http://foo.com>'
                   + "\n\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe("/admin/index.cgi?bz_1200", t.nextStep());
    },
            
    function() { 
        t.is(
            t.$('div.wafl_box a').length,
            1,
            "The {toc:} is rendered as a box"
        );

        t.is(
            t.$('div.wafl_box a').text(),
            "Foo",
            "The {toc:} link has its title set correctly"
        );

        t.endAsync();
    }
]);

})(jQuery);
