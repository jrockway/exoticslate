(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.open_iframe("/admin/?action=new_page", t.nextStep(15000));
    },
            
    function() { 
        t.$('#st-save-button-link').click();
        t.callNextStep(5000);
    },

    function() { 
        if (t.doc && t.doc.activeElement) {
            t.is(
                t.doc.activeElement.getAttribute('id'),
                'st-newpage-save-pagename',
                "st-newpage-save-pagename received focus correctly"
            );
        }
        else {
            t.skip("This browser has no activeElement support");
        }
        t.endAsync();
    }
]);

})(jQuery);
