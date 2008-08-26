(function($) {

var WIDTH_MIN = 100;
var WIDTH_MAX = 1500;
var WIDTH_INT = 10;

var t = new Test.Visual();

t.plan(1);

t.beginAsync(step1);

function step1() {
    t.open_iframe("/", step2);
}

function step2() {
    var always_even = true;
    for (var width = WIDTH_MIN; width <= WIDTH_MAX; width += WIDTH_INT) {
        $(t.iframe).width(width);
        t.scrollTo(t.$('#contentLeft').offset().top, width);

        always_even = ( t.$('#contentLeft').offset().top ==
                        t.$('#columnMiddle').offset().top ) &&
                      ( t.$('#columnMiddle').offset().top ==
                        t.$('#contentRight').offset().top );
        if (!always_even) break;
    }

    t.ok(always_even, "Column top is always aligned");

    t.endAsync();
};

})(jQuery);
