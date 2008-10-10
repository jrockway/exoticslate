(function($) {

var t = new Test.Visual();

t.plan(1);

if (jQuery.browser.msie)
    t.skipAll("Skipping this insanity on IE for now...");

t.runAsync([
    function() {
        t.login({}, t.nextStep());
    },

    function() {
        var widget = WID = t.setup_one_widget(
            {
                url: "/?action=add_widget;location=widgets/share/widgets/my_workspaces.xml",
                noPoll: true
            },
            t.nextStep()
        );
    },

    function() {
        t.scrollTo(150);
        t.$('div.widgetHeader a.minimize:first').click();
        t.iframe.contentWindow.location = '/index.cgi?';
        t.callNextStep(3000);
    },

    function() {
        t.is(
            t.$('div.widgetContent div.visible').length,
            0,
            "Minimizing a widget should persist across reloads"
        );

        t.endAsync();
    }
]);

})(jQuery);
