(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.open_iframe("/admin/index.cgi?admin_wiki", t.nextStep());
    },
            
    function() { 
        t.$('#st-comment-button-link').click();
        t.callNextStep(5000);
    },
            
    function() { 
        if (t.doc && t.doc.activeElement) {
            t.is(
                t.doc.activeElement.tagName.toLowerCase(),
                'textarea',
                "Text area gets focus after the user clicks Comment"
            );
        }
        else {
            t.skip("This browser has no activeElement support");
        }

        t.endAsync();
    }
]);

})(jQuery);
