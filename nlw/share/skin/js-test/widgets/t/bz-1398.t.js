(function($) {

var t = new Test.Visual();

t.plan(2);

t.runAsync([

    function() {
        t.open_iframe("/?action=gallery", t.nextStep());
    },
            
    function() { 
        function bottomOffset$ (sel) {
            var el = t.$(sel);
            return el.offset().top
                 + el.height()
                 + parseInt(el.css('padding-top'))
                 + parseInt(el.css('padding-bottom'));
        }

        t.is(
            bottomOffset$('#controls'),
            t.$('#contentContainer').offset().top,
            "Header and the gallery should be next to each other"
        );

        t.is(
            bottomOffset$('#contentContainer'),
            t.$('#footer').offset().top,
            "Footer and the gallery should be next to each other"
        );
        t.endAsync();
    }
]);

})(jQuery);
