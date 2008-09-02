(function($) {

var t = new Test.Visual();

var testData = [
    {
        type: "one_widget",
        url: "/?action=add_widget;file=gadgets/share/gadgets/my_workspaces.xml",
        regex: /You do not belong to any workspaces yet\./,
        desc: "Empty My Workspaces message is correct"
    },
    {
        type: "one_widget",
        url: "/?action=add_widget;file=gadgets/share/gadgets/one_page.xml",
        regex: /This widget shows a single wiki page\. To show a page, click on the tool icon and add the name of the workspace and page\./,
        desc: "Empty message for one page wiki is present and correct"
    },
    {
        type: "one_widget",
        url: "/?action=add_widget;file=people/share/profile_tags.xml",
        regex: /You don't have any tags yet. Click <b>Add tag<\/b> to add one now./,
        desc: "Empty message for profile tags is present and correct"
    },
    {
        type: "open_iframe",
        widget: "tags",
        url: "/?profile/7",
        regex: /This person doesn't have any tags yet. Click <b>Add tag<\/b> to add one now./,
        desc: "Empty message for another user's profile tags is present and correct"
    },
    {
        type: "one_widget",
        url: "/?action=add_widget;file=people/share/profile_following.xml",
        regex: /You are not following anyone yet. When viewing someone else's profile, you can click on the "Follow this person" button at the top of the page./,
        desc: "Empty message for my \"Persons I'm Following\" list."
    },
    {
        type: "open_iframe",
        widget: "people_i_am_following",
        url: "/?profile/7",
        regex: /This person isn't following anyone yet./,
        desc: "Empty message for someone else's \"Persons I'm Following\" list."
    }
];

var asyncSteps = [
    function() {
        t.login({}, t.nextStep());
    },

    function() {
        t.create_anonymous_user_and_login({}, t.nextStep());
    },

];

// Generate the test step functions for each test.
for (var i = 0, l = testData.length; i < l; i++) {
    (function(d) {
        var step1 = (d.type == 'one_widget')
        ? function() {
            t.setup_one_widget(
                d.url,
                t.nextStep()
            );
        }
        : function() {
            t.open_iframe(d.url, function() {
                t.scrollTo(150);
                t.getWidget(d.widget, t.nextStep());
            });
        };
        var step2 = function(widget) {
            t.scrollTo(150);
            t.like(widget.$("body").html(), d.regex, d.desc);
            t.callNextStep();
        };
        asyncSteps.push(step1);
        asyncSteps.push(step2);
    })(testData[i]);
}

asyncSteps.push(
    function() {
        t.login({});
        t.endAsync();
    }
);

t.runAsync({
    plan: 6,
    steps: asyncSteps
});

})(jQuery);
