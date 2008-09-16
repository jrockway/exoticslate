var ST = ST || {};
ST.Move = function () { }
var proto = ST.Move.prototype = {};

proto.copyLightbox = function () {
    var self = this;
    this.process('copy_lightbox.tt2');
    this.sel = '#st-copy-lightbox';
    jQuery.ajax({
        url: '/data/workspaces',
        type: 'get',
        cache: false,
        async: false,
        dataType: 'json',
        success: function (list) {
            jQuery('#st-copy-workspace option').remove();
            jQuery.each(list, function () {
                jQuery('<option />')
                    .val(this.id)
                    .html(this.title)
                    .attr('name', this.name)
                    .appendTo('#st-copy-workspace');
            })

            self.show(false); // No redirection
        }
    });
}

proto.renameLightbox = function () {
    this.process('rename_lightbox.tt2');
    this.sel = '#st-rename-lightbox';
    this.show(true); // Do redirection
}

proto.duplicateLightbox = function () {
    this.process('duplicate_lightbox.tt2');
    this.sel = '#st-duplicate-lightbox';
    jQuery("#st-duplicate-newname").val(
        loc('Duplicate of [_1]', Socialtext.page_title)
    );
    this.show(true); // Do redirection
}

proto.newUrl = function (page) {
    var ws = jQuery(this.sel + ' #st-copy-workspace option:selected')
        .attr('name') || Socialtext.wiki_id;
    return '/' + ws + '/index.cgi?' + page;
}

proto.process = function (template) {
    Socialtext.loc = loc;
    jQuery('body').append(
        Jemplate.process(template, Socialtext)
    );
}

proto.show = function (do_redirect) {
    var self = this;
    jQuery.showLightbox({
        content: this.sel,
        close: this.sel + ' .close'
    });

    // Clear errors from the previous time around: {bz: 1039}
    jQuery(self.sel + ' .error').html('');

    jQuery(self.sel + ' form').submit(function () {
        jQuery(self.sel + ' input[type=submit]').attr('disabled', true);

        var formdata = jQuery(this).serializeArray();
        var new_title = this.new_title.value;

        jQuery.ajax({
            url: Page.cgiUrl(),
            data: formdata,
            type: 'post',
            dataType: 'json',
            async: false,
            success: function (data) {
                jQuery(self.sel + ' input[type=submit]').attr('disabled', false);

                var error = self.errorString(data, new_title);
                if (error) {
                    jQuery('<input name="clobber" type="hidden">')
                        .attr('value', new_title)
                        .appendTo(self.sel + ' form');
                    jQuery(self.sel + ' .error').html(error).show();
                }
                else {
                    jQuery.hideLightbox();

                    if (do_redirect) {
                        document.location = self.newUrl(new_title);
                    }
                }
            },
            error: function (xhr, textStatus, errorThrown) {
                jQuery(self.sel + ' .error').html(textStatus).show();
                jQuery(self.sel + ' input[type=submit]').attr('disabled', false);
            }
        });

        return false;
    });
}

proto.errorString = function (data, new_title, workspace) {
    if (data.page_exists) {
        var button = jQuery(this.sel + ' input[type=submit]').val();
        return loc(
            'The new page name you selected, "' + new_title + 
            '", is already in use.  Please choose a different ' +
            'name. If you are sure you wish to overwrite the ' +
            'existing "' + new_title + '" page, please press ' +
            '"' + button + '" again.'
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

