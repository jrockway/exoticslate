(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.open_iframe("/admin/?action=new_page", t.nextStep(5000));
    },
            
    function() { 
        t.$('#st-newpage-pagename-edit').val(')');
        t.$('#st-mode-wikitext-button').click();
        t.callNextStep(1500);
    },

    function() { 
        t.$('#wikiwyg_wikitext_textarea').val("{toc:}\n\n^ 1");
        t.$('#st-mode-wysiwyg-button').click();
        t.callNextStep(5000);
    },

    function() { 
        t.$('#st-preview-button-link').click();
        t.is(t.$('div.wafl_items a').text(), '1', "No extra paren on toc wafl");

        t.endAsync();
    }
]);

})(jQuery);
