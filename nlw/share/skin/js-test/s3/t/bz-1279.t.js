(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.open_iframe("/data/workspaces/admin/attachments/admin_wiki:0-0-0/original/bad", t.nextStep());
    },
            
    function() { 
        t.unlike(
            t.doc.body.innerHTML,
            /Carp/,
            "Invalid attachment URL should not lead to ugly error message"
        );

        t.endAsync();
    }
]);

})(jQuery);
