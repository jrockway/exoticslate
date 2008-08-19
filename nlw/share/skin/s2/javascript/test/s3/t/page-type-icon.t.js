(function($) {

var t = new Test.Visual();

t.plan(1);

t.runTests = function() {
    t.like(
        t.$("#st-listview-form tr.oddRow td:eq(1) img.pageType").attr('src'),
        /(ss|doc)16.png$/,
        "There is a page type icon in the list"
    );

    t.iframe.contentWindow.scrollTo(0, 200);
};

t.open_iframe("/admin/index.cgi?action=recent_changes");

})(jQuery);
