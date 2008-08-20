(function($) {

var t = new Test.Visual();

t.plan(1);
t.beginAsync();

var begin = function() {
    t.open_iframe("/admin/index.cgi?admin_wiki", step1);
}

var step1 = function() {
    t.is(
        t.$("div.widget:eq(1) div.widgetContent p").text(),
        "There are no pages that link to this page yet.",
        "Admin Wiki is an orphan page, should say so"
    );

    t.scrollTo(330);

    t.endAsync();
};

begin();

})(jQuery);
