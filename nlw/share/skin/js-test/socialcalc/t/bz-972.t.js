(function($) {

var t = tt = new Test.Visual();

t.plan(1);

t.beginAsync(step1);

function step1() {
    t.open_iframe("/admin/index.cgi?action=display;page_type=spreadsheet;page_name=banana#edit", step2);
}

function step2() {
    t.$("a#st-color-button-link").click();
        t.pass("Clicking color button returned without an alert");
//     setTimeout(function() {
//         t.endAsync();
//     }, 200);
//     setTimeout(function() {
//         t.fail("Clicking color button returned without an alert");
//         t.endAsync();
//     }, 200);
};

})(jQuery);
