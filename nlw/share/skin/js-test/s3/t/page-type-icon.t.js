(function($) {

var t = new Test.Visual();

t.plan(1);
t.beginAsync();

var begin = function() {
    t.open_iframe("/admin/index.cgi?action=recent_changes", step1);
}

var step1 = function() {
    t.like(
        t.$("#st-listview-form tr.oddRow td:eq(1) img.pageType").attr('src'),
        /(ss|doc)16.png$/,
        "There is a page type icon in the list"
    );

    t.scrollTo(200);

    t.endAsync();
};

begin();

})(jQuery);
