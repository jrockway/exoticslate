(function($) {

var t = tt = new Test.Visual();

t.plan(7);

t.beginAsync(step1);

function step1() {
    t.open_iframe("/admin/index.cgi?admin_wiki", step2);
}

function step2() {
    t.ok(
        (
            !(t.win.Widget && t.win.Widget.Lightbox)
        ),
        'Old Lightbox code is not used'
    );
    t.ok(
        t.win.jQuery.showLightbox,
        'New Lightbox code is used'
    );
    t.is(t.$('#lightbox').size(), 0, 'No lightbox yet');

    t.diag("Showing lightbox now");
    t.$.showLightbox({
        html: '<span>foo</span><input type="button" id="close"/>',
        close: '#close',
        callback: step3
    });
}

function step3() {
    t.is(t.$('#lightbox').size(), 1, 'One and only one lightbox');
    t.is(t.$('#lightbox:visible').size(), 1, 'Lightbox is visible');

    t.diag("Hiding lightbox now");
    t.$('#close').click();
    t.is(t.$('#lightbox').size(), 1, 'Lightbox still exists');
    t.is(t.$('#lightbox:visible').size(), 0, 'Lightbox is not visible');

    t.endAsync();
};

})(jQuery);
