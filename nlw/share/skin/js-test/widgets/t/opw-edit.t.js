(function($) {

var t = window.tt = new Test.Visual();

t.plan(2);

t.beginAsync();

t.pass("This test might take up to 30 seconds to run. Be patient.");

var begin = function() {
    t.setup_one_widget(
        "/?action=add_widget;file=gadgets/share/gadgets/one_page.xml",
        step1
    );
}

t.login({callback: begin});

// Most fragile test evar.
var step1 = function(widget) {
    var counter = 0, counter2 = 0, failed = false;
    t.iframe.contentWindow.scrollTo(0, 150);
    widget.$("body").ajaxComplete(function(e, xhr, options) {
        if (options.url.match(/^\/data\/workspaces\/admin\/pages\/workspace_tour_table_of_contents/)) {
            counter++;
        }

        if (counter == 2) {
            widget.$('#edit_button').click();
        }
        if (counter >= 2 && options.url.match(/^\/data\/workspaces\/admin\/pages\/workspace_tour_table_of_contents\?.*accept=text/)) {
            widget.$('#save_button').click();
            counter2 = 1;
        }

        if (counter2) {
            counter2++;
            var text = xhr.responseText;
            if (text.match(/^0/)) {
                t.fail('Received bad REST response');
                failed = true;
            }

            if (counter2 == 4) {
                if (!failed)
                    t.pass('All REST responses were good');
                counter2 = 0;
                t.endAsync();
            }
        }
    });
};

})(jQuery);
