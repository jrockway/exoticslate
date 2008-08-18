(function($) {

var t = new Test.Visual();

t.plan(1);

t.runTests = function() {
    var hoverText = t.$("#st-attachment-listing li:eq(0) a:eq(0)").attr("title");
    t.like(hoverText, /Uploaded by (.+) on (.+)\.\d+(K|M| bytes)/, "Attachment hover text contains uploader, date and size info.");

    // Scroll to wherever the attachment widget is
    t.iframe.contentWindow.scrollTo(0, t.$("#st-attachment-listing").offset().top - 50);
};

// Need a page with attachments
t.open_iframe("/admin/index.cgi?how_do_i_make_a_new_page", {w: 950});

})(jQuery);
