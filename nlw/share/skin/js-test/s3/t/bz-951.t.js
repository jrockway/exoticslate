(function($) {

var t = new Test.Visual();

t.plan(2);

t.beginAsync();

var begin = function() {
    t.put_page({
        workspace: "admin",
        page_name: "Navigation for: Recent Changes",
        content: "*strong*\n_italic_\n",
        callback: step1
    });
}

var step1 = function() {
    t.open_iframe("/admin/index.cgi?action=weblog_display&category=Recent+Changes", step2);
}

var step2 = function() {
    t.scrollTo(200);
    t.is(
        t.$("#st-page-boxes div.wiki strong").css("font-weight"),
        "bold",
        "*strong* is strong"
    );

    t.is(
        t.$("#st-page-boxes div.wiki em").css("font-style"),
        "italic",
        "_italic_ is italic"
    );
    t.endAsync();
}

begin();

})(jQuery);
