(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_1596",
            content: "fnord\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe("/admin/index.cgi?bz_1596", t.nextStep());
    },
            
    function() { 
        t.$('a.addTagButton').click();
        t.callNextStep(1000);
    },
    
    function() { 
        t.$('#st-tags-field').val('bz_1596_' + Math.random());
        t.$('#st-tags-form').submit();
        t.callNextStep(1500);
    },
    
    function() { 
        t.$('#st-edit-button-link').click();
        t.callNextStep(5000);
    },
    
    function() { 
        t.ok('No javascript errors after adding a tag and editing a page');
        t.$('#st-save-button-link').click();

        t.endAsync();
    }
]);

})(jQuery);
