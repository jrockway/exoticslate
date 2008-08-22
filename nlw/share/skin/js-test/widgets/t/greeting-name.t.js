(function($) {

var t = new Test.Visual();

t.plan(1);

t.beginAsync(step1);

function step1() {
    t.login({callback: step2});
}

function step2() {
    t.ts = (new Date()).getTime();
    t.username = 'user' + t.ts + '@example.com',
    t.email_address = 'email' + t.ts + '@example.com',

    t.create_user({
        username: t.username,
        email_address: t.email_address,
        password: 'd3vnu11l',
        workspace: 'admin',
        callback: step3
    });
}

function step3() {
    t.login({
        'username': t.username,
        'password': 'd3vnu11l',
        'callback': step4
    });
}

function step4() {
    t.open_iframe("/", step5);
};

function step5() {
    $(t.iframe).width(1000);
    t.scrollTo(50);
    var username = t.$("span.welcome div").text()
        .replace(/^\s*(.*)\s*$/, '$1');
    t.is(username, 'user' + t.ts,
        'User name is correct (user' + t.ts + ') when user has no name'
    );
    t.endAsync();
};

})(jQuery);
