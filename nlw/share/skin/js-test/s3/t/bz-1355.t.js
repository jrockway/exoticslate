(function($) {

var t = new Test.Visual();

t.plan(1);

t.checkRichTextSupport();

t.runAsync([
    function() {
        t.open_iframe("/admin/index.cgi?action=new_page", t.nextStep());
    },
            
    function() { 
        setTimeout(function(){
            t.$('#wikiwyg_button_link').click();

            setTimeout(function(){
                t.$('#st-newpage-pagename-edit').val('bz_1318_'+Math.random());
                t.$('#st-newpage-pagename-edit').focus();

                t.scrollTo(300);

                t.$('#add-web-link').click();
                t.$('#web-link-text').val('Test');
                t.$('#web-link-destination').val('http://socialtext.com/');
                t.$('#add-a-link-form').submit();

                setTimeout(function(){
                    var href = $(
                        t.$('#st-page-editing-wysiwyg').get(0).contentWindow.document.documentElement
                    ).find('a[href=http://socialtext.com/]');

                    t.ok(
                        href.length,
                        "Creating a new link on an empty page should work"
                    );

                    t.$('#st-save-button-link').click();

                    t.endAsync();
                }, 2500);
            }, 2500);
        }, 2500);
    }
]);

})(jQuery);
