(function($) {

var t = new Test.Visual();

var asyncSteps = [
    function() {
        t.login({}, t.nextStep());
    },

    function() {
        t.create_anonymous_user_and_login({}, t.nextStep());
    },

    function() {
        t.setup_one_widget(
            "/?action=add_widget;file=gadgets/share/gadgets/my_workspaces.xml",
            t.nextStep()
        );
    },

    function(widget) {
        t.scrollTo(150);

        var $empty = widget.$(".st-widget-empty-msg");
        t.is($empty.length, 1, "We have an empty message");
        t.is($empty.text(), "You do not belong to any workspaces yet.",
            "Empty message is correct"
        );

        t.callNextStep();
    },

    function() {
        t.setup_one_widget(
            "/?action=add_widget;file=gadgets/share/gadgets/one_page.xml",
            t.nextStep()
        );
    },

    function(widget) {
        t.scrollTo(150);
        t.like(
            widget.$("body").html(),
            /This widget shows a single wiki page\. To show a page, click on the tool icon and add the name of the workspace and page\./,
            "Empty message for one page wiki is present and correct"
        );

        t.callNextStep();
    },

    function() {
        t.setup_one_widget(
            "/?action=add_widget;file=people/share/profile_tags.xml",
            t.nextStep()
        );
    },

    function(widget) {
        t.scrollTo(150);

        var html = widget.$('body div').html();
        t.like(
            html,
            /You don't have any tags yet. Click <b>Add tag<\/b> to add one now./,
            "Empty message for profile tags is present and correct"
        );
        
        t.callNextStep();
    },

    // Profile tags for another user's profile
    function() {
        t.open_iframe("/?profile/7", function() {
            t.scrollTo(150);
            t.getWidget('tags', t.nextStep());
        });
    },

    function(widget) {
        var html = widget.$('body div').html();
        t.like(
            html,
            /This person doesn't have any tags yet. Click <b>Add tag<\/b> to add one now./,
            "Empty message for another user's profile tags is present and correct"
        );

        t.callNextStep();
    },

    // people i'm following
    function() {
        t.setup_one_widget(
            "/?action=add_widget;file=people/share/profile_following.xml",
            t.nextStep()
        );
    },

    function(widget) {
        var html = widget.$('body div').html();
        t.like(
            html,
            /You are not following anyone yet. When viewing someone else's profile, you can click on the "Follow this person" button at the top of the page./,
            "Empty message for my \"Persons I'm Following\" list."
        );

        t.callNextStep();
    },

    // people someone else is following
    function() {
        t.open_iframe("/?profile/7", function() {
            t.scrollTo(150);
            t.getWidget('people_i_am_following', t.nextStep());
        });
    },

    function(widget) {
        var html = widget.$('body div').html();
        t.like(
            html,
            /This person isn't following anyone yet./,
            "Empty message for someone else's \"Persons I'm Following\" list."
        );

        t.callNextStep();
    },

    function() {
        t.login({});
        t.endAsync();
    }
];

t.runAsync({
    plan: 7,
    steps: asyncSteps
});

})(jQuery);
