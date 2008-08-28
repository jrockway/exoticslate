(function($) {

var t = new Test.Visual();

t.plan(1);

t.beginAsync(step1);

function step1() {
    t.login({}, step2);
}

function step2() {
    t.create_anonymous_user_and_login({workspace: 'admin'}, step3);
}

function step3() {
    t.open_iframe("/", step4);
};

function step4() {
    $(t.iframe).width(1000);
    t.scrollTo(50);
    var username = t.$("span.welcome div").text()
        .replace(/^\s*(.*)\s*$/, '$1');
    var expected = t.anonymous_username.replace(/@.*/, '');
    t.is(username, expected,
        'User name is correct (' + expected + ') when user has no name'
    );
    t.endAsync();
};

})(jQuery);
