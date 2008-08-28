(function() {

var t = new Test.Visual();

t.plan(1);

t.beginAsync(login);

function login() {
    t.login({}, complete);
}

function complete() {
    t.pass('Logged in...');
    t.endAsync();
}

})();
