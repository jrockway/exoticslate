if (Socialtext.S3) {
    jQuery('#bootstrap-loader').hide();

    setup_wikiwyg();
    window.wikiwyg.start_nlw_wikiwyg();

    $("#st-edit-pagetools-pounce").click(function() {
        $("#st-pagetools-pounce").click();
        $(window).trigger("resize");
        return false;
    });
}
