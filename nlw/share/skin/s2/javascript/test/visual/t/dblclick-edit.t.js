(function($) {

var t = new Test.Visual();

t.plan(5);

t.runTests = function() {
    $(t.iframe).height(200);
    $(t.iframe).width(900);
    t.builder.ok(
        t.$("div#st-display-mode-container").is(":visible"),
        'Display is visible before edit'
    );
    t.builder.ok(
        t.$("div#st-edit-mode-view").is(":hidden") ||
        ( t.$("div#st-edit-mode-view").size() == 0 ),
        'Editor is not visible'
    );

    t.$("div#st-page-content").trigger("dblclick");

    var id = t.builder.beginAsync();
    setTimeout(function() {
        t.builder.ok(
            t.iframe.contentWindow.Wikiwyg,
            'Double click starts wikiwyg'
        );
        t.builder.ok(
            t.$("div#st-display-mode-container").is(":hidden"),
            'Display is hidden after doubleclick to edit'
        );

        t.builder.ok(
            t.$("div#st-edit-mode-view").is(":visible"),
            'Editor is now visible'
        );

        t.builder.endAsync(id);
    }, 1000);
};

t.open_iframe("/admin/index.cgi?admin_wiki");

})(jQuery);
