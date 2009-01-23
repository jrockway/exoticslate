(function($) {

var t = new Test.Visual();

t.plan(1);

if (jQuery.browser.msie)
    t.skipAll("Skipping this insanity on IE for now");

t.runAsync([
    function() {
        t.login({}, t.nextStep());
    },

    function() {
        var widget = WID = t.setup_one_widget(
            {
                url: "/?action=add_widget;src=http%3A%2F%2Fwww.labpixies.com%2Fcampaigns%2Ftodo%2Ftodo.xml",
                noPoll: true
            },
            t.nextStep()
        );
    },

    function(widget) {
        t.is(
            widget.$('#menu_div').length,
            1,
            "TODO widget initialized correctly"
        );

        t.endAsync();
    }
]);

})(jQuery);
