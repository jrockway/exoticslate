var ST = ST || {};

(function ($) {

ST.Lightbox = function () {};

ST.Lightbox.prototype = {
    newUrl: function (page) {
        var ws = $(this.sel + ' #st-copy-workspace option:selected')
            .attr('name') || Socialtext.wiki_id;
        return '/' + ws + '/index.cgi?' + page;
    },

    process: function (template) {
        Socialtext.loc = loc;
        $('body').append(
            Jemplate.process(template, Socialtext)
        );
    },

    show: function (do_redirect, callback) {
        var self = this;
        $.showLightbox({
            content: this.sel,
            close: this.sel + ' .close',
            callback: callback 
        });

        $(self.sel + ' .submit').click(function () {
                $(this).parents('form').submit();
        });

        // Clear errors from the previous time around: {bz: 1039}
        $(self.sel + ' .error').html('');

        $(self.sel + ' form').submit(function () {
            $(self.sel + ' input[type=submit]').attr('disabled', true);

            var formdata = $(this).serializeArray();
            var new_title = this.new_title.value;

            $.ajax({
                url: Page.cgiUrl(),
                data: formdata,
                type: 'post',
                dataType: 'json',
                async: false,
                success: function (data) {
                    $(self.sel + ' input[type=submit]').attr('disabled', false);

                    var error = self.errorString(data, new_title);
                    if (error) {
                        $('<input name="clobber" type="hidden">')
                            .attr('value', new_title)
                            .appendTo(self.sel + ' form');
                        $(self.sel + ' .error').html(error).show();
                    }
                    else {
                        $.hideLightbox();

                        if (do_redirect) {
                            document.location = self.newUrl(new_title);
                        }
                    }
                },
                error: function (xhr, textStatus, errorThrown) {
                    $(self.sel + ' .error').html(textStatus).show();
                    $(self.sel + ' input[type=submit]').attr('disabled', false);
                }
            });

            return false;
        });
    },

    errorString: function (data, new_title, workspace) {
        if (data.page_exists) {
            var button = $(this.sel + ' input[type=submit]').val();
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
};
})(jQuery);
