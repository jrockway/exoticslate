(function($) {

var t = new Test.Visual();

t.plan(1);

t.beginAsync(step1);

function step1() {
    t.open_iframe("/admin/index.cgi?admin_wiki", step2);
}

function step2() {
    t.scrollTo(330);

    t.is(
        t.$("div.widget:eq(1) div.widgetContent p").text(),
        "There are no pages that link to this page yet.",
        "Admin Wiki is an orphan page, should say so"
    );

    t.endAsync();
};

})(jQuery);
