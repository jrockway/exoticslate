(function($) {

var t = new Test.Visual();

t.plan(2);

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "em",
            content: "^^ foo _bar_ there\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe("/admin/index.cgi?em", t.nextStep());
    },

    function() {
        t.scrollTo(150);
        $(t.iframe).height(200);
        for (attr in {color: 1, fontSize: 1}) {
            t.is(
                t.$.curCSS(t.$('.wiki h2 em')[0], attr),
                t.$.curCSS(t.$('.wiki h2')[0], attr),
                'EM in H2 has same ' + attr + ' as H2'
            );
        }

        t.endAsync();
    }
]);

})(jQuery);
