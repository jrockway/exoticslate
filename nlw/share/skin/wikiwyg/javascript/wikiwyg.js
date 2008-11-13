if (Socialtext.S3) {
    jQuery('#bootstrap-loader').hide();

    setup_wikiwyg();
    window.wikiwyg.start_nlw_wikiwyg();

    $("#st-edit-pagetools-expand").click(function() {
        Socialtext.ui_expand_toggle();
        $(window).trigger("resize");
        return false;
    });
}
