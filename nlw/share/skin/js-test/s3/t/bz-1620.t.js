(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.open_iframe("/?profile/2", t.nextStep());
    },
            
    function() { 
        var rss_link = t.$('iframe.updates').get(0).contentWindow.document.getElementById('rss_link');
        t.is(
            rss_link.getAttribute('target'),
            '_blank',
            "[RSS Feed] link opens in a new window"
        );

        t.endAsync();
    }
]);

})(jQuery);
