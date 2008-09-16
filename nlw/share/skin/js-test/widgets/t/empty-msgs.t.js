(function($) {

var t = new Test.Visual();

t.plan(7);

var asyncSteps = [
    function() { t.login({}, t.nextStep()) }, 
    function() { t.create_anonymous_user_and_login({}, t.nextStep()) }, 
];

var testData = [
    {
        type: "one_widget",
        url: "/?action=add_widget;location=widgets/share/widgets/my_workspaces.xml",
        regex: /You do not belong to any workspaces yet\./,
        desc: "Empty My Workspaces message is correct"
    },
    {
        type: "one_widget",
        url: "/?action=add_widget;location=widgets/share/widgets/one_page.xml",
        regex: /This widget shows a single wiki page\. To show a page, click on the tool icon and add the name of the workspace and page\./,
        desc: "Empty message for one page wiki is present and correct"
    },
    {
        type: "one_widget",
        url: "/?action=add_widget;location=people/share/profile_tags.xml",
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
        url: "/?action=add_widget;location=people/share/profile_following.xml",
        regex: /You are not following anyone yet. When viewing someone else's profile, you can click on the "Follow this person" button at the top of the page./,
        desc: "Empty message for my \"Persons I'm Following\" list."
    },
    {
        type: "open_iframe",
        widget: "people_i_am_following",
        url: "/?profile/7",
        regex: /This person isn't following anyone yet./,
        desc: "Empty message for someone else's \"Persons I'm Following\" list."
    },
    { // Create a new user in the admin workspace...
        type: 'user_with_workspace'
    },
    {
        type: "one_widget",
        url: "/?action=add_widget;location=widgets/share/widgets/recent_conversations.xml",
        regex: /My Conversations shows updates to pages you are involved with. To see entries in my conversation, edit, comment on, or watch a page. When someone else modifies that page, you will see those updates here./,
        desc: "Empty message for my \"Recent Conversations\" list."
    }
];

// Generate the test step functions for each test.
for (var i = 0, l = testData.length; i < l; i++) {
    (function(d) {
        if (d.type == 'user_with_workspace') {
            asyncSteps.push(function() {
                t.login({}, function() {
                    t.create_anonymous_user_and_login(
                        {workspace: 'admin'},
                        t.nextStep()
                    );
                });
            });
            return;
        }
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
        asyncSteps.push(step1);

        var step2 = function(widget) {
            t.scrollTo(150);
            t.like(widget.$("body").html(), d.regex, d.desc);
            t.callNextStep();
        };
        asyncSteps.push(step2);
    })(testData[i]);
}

asyncSteps.push(function() { t.login({}); t.endAsync() });

t.runAsync(asyncSteps);

})(jQuery);
