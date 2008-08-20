(function() {

var t = new Test.Visual();

t.plan(1);

t.beginAsync();

t.login({
    callback: function() {
        t.pass('Logged in...');
        t.endAsync();
    }
});

})();
