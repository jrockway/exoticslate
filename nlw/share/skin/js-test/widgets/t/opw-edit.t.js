(function($) {

var t = new Test.Visual();

t.plan(2);

if (jQuery.browser.msie) 
    t.skipAll("Skipping this insanity on IE for now...");

t.pass("This test might take up to 30 seconds to run. Be patient.");

t.beginAsync(step1);

function step1() {
    t.login({callback: step2});
}

function step2() {
    t.setup_one_widget(
        "/?action=add_widget;file=gadgets/share/gadgets/one_page.xml",
        step3
    );
}

// Most fragile test evar.
function step3(widget) {
    var counter = 0, counter2 = 0, failed = false;
    t.scrollTo(150);
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
