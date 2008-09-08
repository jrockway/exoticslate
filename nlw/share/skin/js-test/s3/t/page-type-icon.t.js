(function($) {

var t = new Test.Visual();

t.plan(1);

t.beginAsync(step1);

function step1() {
    t.open_iframe("/admin/index.cgi?action=recent_changes", step2);
}

function step2() {
    t.like(
        t.$("#st-listview-form tr.oddRow td:eq(1) img.pageType").attr('src'),
        /(sheet|doc)Icon.png$/,
        "There is a page type icon in the list"
    );

    t.scrollTo(200);

    t.endAsync();
};

})(jQuery);
