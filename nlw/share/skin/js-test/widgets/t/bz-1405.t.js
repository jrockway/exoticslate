(function($) {

var t = new Test.Visual();

t.plan(2);

if (jQuery.browser.msie)
    t.skipAll("Skipping this insanity on IE for now...");

t.runAsync([
    function() {
        t.login({}, t.nextStep());
    },

    function() {
        var widget = WID = t.setup_one_widget(
            {
                url: "/?action=add_widget;location=widgets/share/widgets/recent_conversations.xml",
                noPoll: true
            },
            t.nextStep()
        );
    },

    function(widget) {
        t.scrollTo(150);
        t.is(
            widget.$("div.tablib_content_container0").css('overflow'),
            'auto',
            'Recent conversation tabs are scrollable individually'
        );
        t.ok(
            parseInt(widget.$("div.tablib_content_container0").css('height')),
            'Recent conversation tabs have reasonable height'
        );
        t.endAsync();
    }
]);

})(jQuery);
