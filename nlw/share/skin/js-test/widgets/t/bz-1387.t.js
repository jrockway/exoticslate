(function($) {

var t = new Test.Visual();

t.plan(1);


t.runAsync([
    function() {
        $.ajax({
            url: "/?action=clear_widgets",
            async: false
        });
        t.open_iframe("/", t.nextStep());
    },

    function () {
        var containerID = t.$('#containerID').val();
        $.ajax({
            url: "/?action=add_widget;type=dashboard;src=file:widgets/share/widgets/recent_conversations.xml;container_id=" + containerID,
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
