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
        $.ajax({
            url: "/data/workspaces/help-en/pages/socialtext_releases_simple_editing/tags/測",
            type: 'PUT',
            async: false,
            cache: false
        });

        var widget = WID = t.setup_one_widget(
            {
                url: "/?action=add_widget;location=widgets/share/widgets/tag_cloud.xml",
                noPoll: true
            },
            t.nextStep()
        );
    },

    function(widget) {
        t.scrollTo(150);

        setTimeout(function(){
            var found = false;
            widget.$('a').each(function(){
                if ($(this).text().match(/測/)) {
                    found = true;
                }
            });

            t.ok(
                found,
                "Unicode tag names are handled properly"
            );

            t.endAsync();
        }, 2500);
    }
]);

})(jQuery);
