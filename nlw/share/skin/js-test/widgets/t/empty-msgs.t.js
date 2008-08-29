(function($) {

var t = new Test.Visual();

t.plan(3);

t.beginAsync(step1);

function step1() {
    t.login({}, step2);
}

function step2() {
//     t.create_anonymous_user_and_login({}, step6); // XXX
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
    
    t.$.poll(
        function() { return Boolean(widget.$(".st-widget-empty-msg").length) },
        function() { step5(widget) }
    );
}

function step5(widget) {
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

    step_last();

}

function step_last() {
    t.login({}, function() {
        t.endAsync();
    });
};

})(jQuery);
