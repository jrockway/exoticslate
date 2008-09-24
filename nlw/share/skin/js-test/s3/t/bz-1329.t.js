(function($) {

var t = new Test.Visual();

t.plan(2);

t.runAsync([
    function() {
        t.open_iframe("/admin/index.cgi?admin_wiki", t.nextStep());
    },
            
    function() { 
        setTimeout(function(){
            t.$('#st-comment-button-link').click();

            setTimeout(function(){
                var buttons = t.$('div.comment div.toolbar img.comment_button');
                t.ok(buttons.length, 'We see comment buttons');

                var buttonsWithTitles = t.$('div.comment div.toolbar img.comment_button[title]');
                t.is(buttons.length, buttonsWithTitles.length, 'All comment buttons have titles');

                t.endAsync();
            }, 2500);
        }, 2500);
    }
]);

})(jQuery);
