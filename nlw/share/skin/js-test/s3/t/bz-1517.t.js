(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.open_iframe("/admin/?action=new_page", t.nextStep(5000));
    },
            
    function() { 
        t.$('#st-save-button-link').click();
        t.callNextStep(1500);
    },

    function() { 
        t.is(
            t.doc.activeElement.getAttribute('id'),
            'st-newpage-save-pagename',
            "st-newpage-save-pagename received focus correctly"
        );

        t.endAsync();
    }
]);

})(jQuery);
