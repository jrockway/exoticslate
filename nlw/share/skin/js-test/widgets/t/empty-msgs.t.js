(function($) {

var t = new Test.Visual();

t.plan(6);

t.beginAsync(step1);

function step1() {
    t.login({}, step2);
}

function step2() {
//     t.create_anonymous_user_and_login({}, step13); // XXX
    t.create_anonymous_user_and_login({}, step3);
}

function step3() {
    t.setup_one_widget(
        "/?action=add_widget;file=gadgets/share/gadgets/my_workspaces.xml",
        step4
    );
}

function step4(widget) {
    t.scrollTo(150);

    var $empty = widget.$(".st-widget-empty-msg");
    t.is($empty.length, 1, "We have an empty message");
    t.is($empty.text(), "You do not belong to any workspaces yet.",
        "Empty message is correct"
    );

    step6();
}

function step6() {
    t.setup_one_widget(
        "/?action=add_widget;file=gadgets/share/gadgets/one_page.xml",
        step7
    );
}

function step7(widget) {
    t.scrollTo(150);
    t.like(
        widget.$("body").html(),
        /This widget shows a single wiki page\. To show a page, click on the tool icon and add the name of the workspace and page\./,
        "Empty message for one page wiki is present and correct"
    );

    step8();
}

function step8() {
    t.setup_one_widget(
        "/?action=add_widget;file=people/share/profile_tags.xml",
        step9
    );
}

function step9(widget) {
    t.scrollTo(150);

    var html = widget.$('body div').html();
    t.like(
        html,
        /You don't have any tags yet. Click <b>Add tag<\/b> to add one now./,
        "Empty message for profile tags is present and correct"
    );
    
    step10();
}

// Profile tags for another user's profile
function step10() {
    t.open_iframe("/?profile/7", function() {
        t.scrollTo(150);
        t.getWidget('tags', step12);
    });
}

function step12(widget) {
    var html = widget.$('body div').html();
    t.like(
        html,
        /This person doesn't have any tags yet. Click <b>Add tag<\/b> to add one now./,
        "Empty message for another user's profile tags is present and correct"
    );

    step13();
}

// people i'm following
function step13() {
    t.setup_one_widget(
        "/?action=add_widget;file=people/share/profile_following.xml",
        step14
    );
}

function step14(widget) {
    var html = widget.$('body div').html();
    t.like(
        html,
        /You are not following anyone yet. When viewing someone else's profile, you can click on the "Follow this person" button at the top of the page./,
        "Empty message for my \"Persons I'm Following\" list."
    );

    step_last();
}

function step_last() {
    t.login({}, function() {
        t.endAsync();
    });
};

})(jQuery);
