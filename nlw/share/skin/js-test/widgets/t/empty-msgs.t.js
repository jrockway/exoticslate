(function($) {

var t = new Test.Visual();

t.plan(2);

t.beginAsync(step1);

function step1() {
    t.login({}, step2);
}

function step2() {
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

    t.login({}, step6);
}

function step6() {
    t.endAsync();
};

})(jQuery);
