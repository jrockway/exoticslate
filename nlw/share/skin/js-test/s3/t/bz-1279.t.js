(function($) {

var t = new Test.Visual();

t.plan(2);

t.runAsync([
    function() {
        t.open_iframe("/data/workspaces/admin/attachments/admin_wiki:0-0-0/original/VeryBad", t.nextStep());
    },
            
    function() { 
        t.unlike(
            t.doc.body.innerHTML,
            /Carp/,
            "Invalid attachment URL should not lead to ugly error message"
        );

        t.like(
            t.doc.body.innerHTML,
            /VeryBad/,
            "The error message should contain the attachment file name"
        );

        t.endAsync();
    }
]);

})(jQuery);
