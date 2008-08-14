(function($) {

var t = new Test.Visual();

t.plan(1);

// Play with these two numbers:
var box2_vertical = 0;
var box2_horizontal = 75;

t.runTests = function() {
    $(t.iframe).height(300).width(300);
    var $body = $(t.iframe.contentDocument.body);
    var $box1 = window.$box1 = $('<div id="box1"></div>')
        .width(100)
        .height(100)
        .css({
            backgroundColor: 'blue',
            position: 'absolute',
            opacity: '0.5',
            top: '100px',
            left:'100px'
        })
        .appendTo($body);

    var $box2 = window.$box2 = $('<div id="box2"></div>')
        .width(50)
        .height(50)
        .css({
            backgroundColor: 'red',
            opacity: '0.5',
            position: 'absolute',
            top: String((300 - 50) / 2 + box2_vertical) + 'px',
            left: String((300 - 50) / 2 + box2_horizontal) + 'px',
        })
        .appendTo($body);

    t.elements_do_not_overlap(
        $box1,
        $box2,
        'elements_do_not_overlap() function works'
    );
};

t.open_iframe("blank.html");

})(jQuery);
