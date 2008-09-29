(function($) {

var t = new Test.Visual();

t.plan(3);

t.runAsync([
    function() {
        t.open_iframe( "/", t.nextStep() );
    },
            
    function() { 
        var minHeight = 300;
        t.ok(
            t.$('#leftList').height() >= minHeight,
            "Left list is at least 300 pixels high"
        );
        t.ok(
            t.$('#middleList').height() >= minHeight,
            "Middle list is at least 300 pixels high"
        );
        t.ok(
            t.$('#rightList').height() >= minHeight,
            "Right list is at least 300 pixels high"
        );
        t.endAsync();
    }
]);

})(jQuery);
