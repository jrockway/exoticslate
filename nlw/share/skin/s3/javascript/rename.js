var error = jQuery('#st-rename-error');

function error_string (data, new_title) {
    if (data.page_exists) {
        return loc(
            'The new page name you selected, "' + new_title + 
            '", is already in use.  Please choose a different ' +
            'name. If you are sure you wish to overwrite the ' +
            'existing "' + new_title + '" page, please press ' +
            '"Rename" again.'
        );
    }
    else if (data.page_title_bad) {
        return loc(
            'The page name you selected, "' + new_title +'", ' +
            'is not allowed.  Please enter or change the page ' +
            'name.'
        );
    }
    else if (data.page_title_too_long) {
        return loc(
            'The page name you selected, "' +
            new_title + '", is too long after URL encoding'
        );
    }
    else if (data.same_title) {
        return loc(
            'The page name you selected, "' + new_title + '", ' +
            "is the same as the page's current title.  " +
            'Please enter a new page name.'
        );
    }
}

function show_lightbox (name) {
    Socialtext.loc = loc;
    jQuery('body').append(
        Jemplate.process(name + '_lightbox.tt2', Socialtext)
    );
    jQuery.showLightbox({
        content: '#st-' + name + '-lightbox',
        close: '#st-' + name + '-cancel'
    });
    jQuery('#st-' + name + '-form').submit(function () {
        var new_title = jQuery('#st-' + name + '-newname').val();
        var data = jQuery(this).serialize();
        jQuery.getJSON(Page.cgiUrl(), data, function (data) {
            var error = error_string(data, new_title);
            if (error) {
                jQuery('<input name="clobber" type="hidden">')
                    .attr('value', new_title)
                    .appendTo('#st-' + name + '-form');
                jQuery('#st-' + name + '-error').html(error).show();
            }
            else {
                jQuery.hideLightbox();
                document.location = Page.cgiUrl() + '?' + new_title;
            }
        });
        return false;
    });
}
