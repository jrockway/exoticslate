function try_wikiwyg() {

    var boot = function(e) {
        jQuery("<script>").attr({
            type: 'text/javascript',
            src: nlw_make_static_path("/javascript/socialtext-edit-wikiwyg.js.gz")
        }).appendTo("head");

        var loader = function() {
            if ( window.setup_wikiwyg ) {
                setup_wikiwyg();

                // XXX There should be a more reliable way to do this.
                // This setTimeout fixes simple mode bug in IE and FF.
                setTimeout(function() {
                    wikiwyg.start_nlw_wikiwyg();

                    // for "Upload files" and "Add tags" buttons
                    jQuery( "#st-edit-mode-uploadbutton" ).click(function() {
                        window.EditQueue._display_interface();
                        return false;
                    });

                    jQuery( "#st-edit-mode-tagbutton" ).click(function() {
                        window.TagQueue._display_interface();
                        return false;
                    });
                }, 100);

                return;
            }
            setTimeout(loader, 50);
        }
        loader();

        return false;
    };

    jQuery("#st-edit-button-link,#st-edit-actions-below-fold-edit")
    .one("click",boot);

    if (Socialtext.double_click_to_edit)
        jQuery("#st-page-content").one("dblclick", boot);

    if (Socialtext.new_page || Socialtext.start_in_edit_mode || location.hash.toLowerCase() == '#edit' ) {
        setTimeout(function() {
            jQuery("#st-edit-button-link").trigger("click");
        }, 1);
    }

    /*
    try {
        setup_wikiwyg();
    } catch(e) {
        alert(loc('setup_wikiwyg error') + ': ' + (e.description || e));
    }
    */
}

Event.observe(window, 'load', try_wikiwyg);

