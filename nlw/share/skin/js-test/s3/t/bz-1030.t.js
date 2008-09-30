(function($) {

var t = new Test.Visual();

t.plan(4);

t.runAsync([
    function() {
        for (var id = 1; id <= 3; id++) {
            jQuery.ajax({
                url:'/data/people/devnull1@socialtext.com/watchlist',
                type:'POST',
                contentType: 'application/json',
                processData: false,
                async: false,
                data: '{"person":{"id":"'+id+'"}}',
                complete: function() {
                    t.ok('Followed person with ID ' + id);
                }
            });
        }

        t.open_iframe("http://topaz.socialtext.net:22021/?profile", t.nextStep());
    },
            
    function() { 
        /* Find the "People I'm following" panel */
        var $$ = t.$('ul#middleList li:first div.widgetContent iframe')
                  .get(0).contentWindow.jQuery;

        $$('img:first').css('border', '1px solid black');
        $$('li.oddRow:first').css('border', '1px solid black');

        t.elements_do_not_overlap(
            $$('img:first'),
            $$('li.oddRow:first'),
            "Rows should not overlap each other in [People I'm following]."
        );
        t.endAsync();
    }
]);

})(jQuery);
