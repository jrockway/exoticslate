(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        $.ajax({
            url: "/?action=elar_widgets",
            async: false
        });
        $.ajax({
            url: "/?action=add_widget;location=widgets/share/widgets/recent_conversations.xml",
            async: false
        });
        t.open_iframe("/", t.nextStep());
    },
            
    function() { 
        t.is(
            t.$('.widgetHeaderTitleBox:first span').attr('title'),
            'Recent Conversations',
            'Header text should hover as titletext'
        );

        t.endAsync();
    }
]);

})(jQuery);
