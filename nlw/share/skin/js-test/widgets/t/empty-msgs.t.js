(function($) {

var t = new Test.Visual();

t.plan(2);

if (jQuery.browser.msie) 
    t.skipAll("Skipping this insanity on IE for now...");

t.pass("This test might take up to 30 seconds to run. Be patient.");

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
    t.fail('under construction...');
    t.endAsync();
};

})(jQuery);
