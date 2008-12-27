(function($) {

var t = new Test.Visual();

t.plan(1);

t.skipAll("TODO - To be implemented in the 2009-01-16 iteation");

t.checkRichTextSupport();

var iframeHeight;

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_943",
            content: "<http://socialtext.net/>",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe(
            "/admin/index.cgi?bz_943",
            t.nextStep()
        );
    },

    t.doRichtextEdit(),

    function() { 
        t.win.wikiwyg.current_mode.exec_command('selectall');
        t.$('#wikiwyg_button_link').click();

        t.poll(function(){
            return(
                t.$('#web-link-destination').val()
                  && (t.$('#web-link-destination').val().length > 0)
            );
        }, function() {t.callNextStep();});
    },

    function() { 
        t.is(
            t.$('#web-link-destination').val(),
            'http://socialtext.net/',
            "Link destination for hyperlink is parsed correctly"
        );

        t.$('#st-widget-link-cancelbutton').click();
        t.endAsync();
    }
]);

})(jQuery);
