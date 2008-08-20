(function() {

var t = new Test.Visual();

t.plan(1);

t.manualAsync = true;

t.login(function() {
    t.pass('Logged in...');
    t.endAsync();
});

})();
