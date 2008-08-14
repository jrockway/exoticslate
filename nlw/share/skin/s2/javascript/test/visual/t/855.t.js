var t = new Test.Visual();
t.plan(1);
if (jQuery.browser.mozilla) {
    t.open(
        "/admin/index.cgi?action=recent_changes",
        function(t) {
            jQuery(t.iframe).height(200);
            jQuery(t.iframe).width(800);

            t.elements_do_not_overlap(
                'div.tableFilter ul',
                'div#controlsRight',
                'Export and Tools do not overlap when window width is ' + 800
            );

            t.iframe.contentWindow.scrollTo(800, 50);
        }
    );
}
else {
    t.skip("This test is only for Mozilla browsers. On IE, those two elements are not overlapping but still look bad in other ways. ");
}

