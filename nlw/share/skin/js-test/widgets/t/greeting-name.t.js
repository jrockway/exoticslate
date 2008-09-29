(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.login({}, t.nextStep());
    },

    function() {
        t.create_anonymous_user_and_login({workspace: 'admin'}, t.nextStep());
    },

    function() {
        t.open_iframe("/", t.nextStep());
    },

    function step4() {
        $(t.iframe).width(1000);
        t.scrollTo(50);
        var username = t.$("span.welcome div").text()
            .replace(/^\s*(.*?)\s*$/, '$1');
        var expected = t.anonymous_username.replace(/@.*/, '');
        t.is(username, expected,
            'User name is correct (' + expected + ') when user has no name'
        );
        t.endAsync();
    }
]);

})(jQuery);
