(function($) {

var t = new Test.Visual();

t.plan(2);

t.runTests = function() {
    t.is(
        t.$("#st-listview-form tr.oddRow td:eq(1) img.avatar").size(),
        1,
        "There are user avatars in recent changes listview"
    );

    t.is(
        t.$("#st-listview-form tr.oddRow td:eq(1) img.avatar").css("float"),
        "none",
        "Make sure it's not floated to left or right."
    );

    t.iframe.contentWindow.scrollTo(0, 200);
};

t.open_iframe("/admin/index.cgi?action=recent_changes");

})(jQuery);
