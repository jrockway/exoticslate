(function($) {

var t = new Test.Visual();

t.plan(1);

if (!$.browser.msie) {
    t.skipAll('This reflow bug only presents in IE');
}

t.beginAsync(function(){
    t.open_iframe("/admin/index.cgi?how_do_i_make_a_new_page", function(){

    // Remember the vertical position of that button
    var topOffset = t.$("#bottomButtons .editButton").offset().top;

    // Scroll to wherever the bottom Edit button is
    t.scrollTo(topOffset - 50);

    // Now reset the HTML content with the setPageContent method
    t.win.Page.setPageContent('<div />');

    // Ensure that it moved after the page content moved
    t.isnt(
        topOffset,
        t.$("#bottomButtons .editButton").offset().top,
        'The bottom Edit button moved after the page content moved'
    );

    t.endAsync();
})})})(jQuery);
