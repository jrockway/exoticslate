(function($) {

var t = new Test.Visual();

t.plan(1);

t.checkRichTextSupport();

var editableDivCount;

function wikiwyg_started() {
    return (t.win.wikiwyg && t.win.wikiwyg.is_editing);
}

function richtextModeIsReady() {
    return (
        (t.win.wikiwyg.current_mode.classtype == 'wysiwyg') &&
        $(
            t.$('#st-page-editing-wysiwyg').get(0)
             .contentWindow.document.documentElement
        ).find('h1').is(':visible')
    );
};

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_1717",
            content: "^ Test\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe(
            "/admin/index.cgi?bz_1717",
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
        editableDivCount = $(
            t.$('#st-page-editing-wysiwyg').get(0)
             .contentWindow.document.documentElement
        ).find('#wysiwyg-editable-div').length;

        t.$('#wikiwyg_button_table').click();
        t.callNextStep(2000);
    },

    function() { 
        t.$('.table-create input[name=save]').click();

        t.poll(function() {
            return ($(
                t.$('#st-page-editing-wysiwyg').get(0)
                 .contentWindow.document.documentElement
            ).find('body table tbody').length > 0)
        }, function() {t.callNextStep();});
    },

    function() { 
        t.is(
            $(
                t.$('#st-page-editing-wysiwyg').get(0)
                 .contentWindow.document.documentElement
            ).find('#wysiwyg-editable-div').length,
            editableDivCount,
            "Inserting a table should result in random editable divs"
        );

        t.$('#st-save-button-link').click();
        t.endAsync();
    }
]);

})(jQuery);
