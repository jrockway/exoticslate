(function($) {

var t = new Test.Visual();

t.plan(1);

t.checkRichTextSupport();

var iframeHeight;

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "bz_1294",
            content: "^ H1\n\n^^ H2",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe(
            "/admin/index.cgi?bz_1294",
            t.nextStep()
        );
    },

    t.doRichtextEdit(),

    function() { 
        var editArea = $(
            t.$('#st-page-editing-wysiwyg').get(0)
             .contentWindow.document.documentElement
        );
        var $h1 = editArea.find('h1');
        var $h2 = editArea.find('h2');

        t.scrollTo(500);

        t.isnt(
            $h1.height(),
            $h2.height(),
            'Heading styles are in effect for rich text edit'
        );

        t.$('#st-save-button-link').click();

        t.endAsync();
    }
]);

})(jQuery);
