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
        t.scrollTo(t.$('#st-tags-addlink').offset().top);
        t.$('#st-tags-addlink').click();
        t.poll(function(){
            return t.$('#st-tags-field').is(':visible');
        }, function () { t.callNextStep() } );
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

        t.endAsync();
    }
]);

})(jQuery);
