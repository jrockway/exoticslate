(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    t.doCreatePage("{image: x} x"),
    t.doRichtextEdit(),

    function() { 
        t.$('a[do=do_hr]').click();
        t.callNextStep(1500);
    },
            
    function() { 
        t.$('#st-preview-button-link').click();
        t.callNextStep(5000);
    },
            
    function() { 
        t.is(
            t.$('div.wiki').children('*').get(0).tagName.toLowerCase(),
            'hr',
            "Horizontal line should be inserted before the WAFL"
        );

        t.endAsync();
    }
]);

})(jQuery);
