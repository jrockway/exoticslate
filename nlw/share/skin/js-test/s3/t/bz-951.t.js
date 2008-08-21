(function($) {

var t = new Test.Visual();

t.plan(2);

t.beginAsync(step1);

function step1() {
    t.put_page({
        workspace: "admin",
        page_name: "Navigation for: Recent Changes",
        content: "*strong*\n_italic_\n",
        callback: step2
    });
}

function step2() {
    t.open_iframe("/admin/index.cgi?action=weblog_display&limit=1&category=Recent+Changes", step3);
}

function step3() {
    t.scrollTo(200);
    t.is_no_harness(
        t.$(".widget div.wiki strong").css("font-weight"),
        "bold",
        "*strong* is strong"
    );

    t.is_no_harness(
        t.$(".widget div.wiki em").css("font-style"),
        "italic",
        "_italic_ is italic"
    );
    t.endAsync();
}

})(jQuery);
