(function($) {

var t = new Test.Visual();

t.plan(1);

t.skipAll("TODO - Not ready for 12-12");

t.checkRichTextSupport();

var iframeHeight;

function wikiwyg_started() {
    return (t.win.wikiwyg && t.win.wikiwyg.is_editing);
}

function richtextModeIsReady() {
    return (
        (t.win.wikiwyg.current_mode.classtype == 'wysiwyg') &&
        $(
            t.$('#st-page-editing-wysiwyg').get(0)
             .contentWindow.document.documentElement
        ).find('a').is(':visible')
    );
};

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

    function() { 
         t.$('#st-edit-button-link').click();
         t.poll(
            function() { return wikiwyg_started() },
            function() { t.callNextStep() }
        );
    },
            
    function() { 
        if (richtextModeIsReady()) {
             t.callNextStep(0);
             return;
        }
        t.$('#st-mode-wysiwyg-button').click();
        t.poll(richtextModeIsReady, function() {t.callNextStep();});
    },

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
        t.$('#st-save-button-link').click();
        t.endAsync();
    }
]);

})(jQuery);
