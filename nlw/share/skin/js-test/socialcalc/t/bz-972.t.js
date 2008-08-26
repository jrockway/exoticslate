(function($) {

var t = tt = new Test.SocialCalc();

t.plan(1);

t.beginAsync(step1);

function step1() {
    t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name=banana#edit", step2);
}

function step2() {
    var val = t.callEventHandler("#st-color-button-link", "click");
    t.is(val, false, "Event handler returns false");

    t.endAsync();
};

})(jQuery);
