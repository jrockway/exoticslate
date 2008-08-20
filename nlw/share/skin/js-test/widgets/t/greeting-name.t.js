(function($) {

var t = new Test.Visual();

t.plan(1);

t.runTests = function() {
    t.pass('it works');
};

// Need a page with attachments
t.open_iframe("/", {w: 950});

})(jQuery);
