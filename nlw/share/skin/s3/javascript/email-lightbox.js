jQuery('#st-email-lightbox').remove(); //remove this line after

var ST = ST || {};
ST.Email = function () {
    this.restURL = '/data/workspaces/' + Socialtext.wiki_id;
};

var proto = ST.Email.prototype = {};


proto.show = function () {
    var self = this;
    if (!jQuery('#st-email-lightbox').size()) {
        Socialtext.loc = loc;
        Socialtext.full_uri = location.href.replace(/#.*$/, '').replace(/index\.cgi\?/, '?');

        jQuery('<div class="lightbox" id="st-email-lightbox" />')
            .appendTo('body')
            .html( Jemplate.process('email_lightbox.tt2', Socialtext) );

        jQuery('#email_page_add_one').click(function () {
            jQuery(this).val('');
        });

        jQuery('#email_add').click(function () {
            jQuery('#email_source option:selected').appendTo('#email_dest');
        });

        jQuery('#email_remove').click(function () {
            jQuery('#email_dest option:selected').appendTo('#email_source');
        });

        jQuery('#email_all').click(function () {
            jQuery('#email_source option').appendTo('#email_dest');
        });

        jQuery('#email_none').click(function () {
            jQuery('#email_dest option').appendTo('#email_source');
        });

        jQuery('#email_addone').click(function () {
            var val = jQuery('#email_page_add_one').val();
            if (!val) {
                return false;
            }
            else if (!email_page_check_address(val)) {
                alert(loc('"[_1]" is not a valid email address.', val))
                jQuery('#email_page_add_one').focus();
                return false;
            }
            else {
                jQuery('<option />').val(val).html(val).appendTo('#email_dest');
                return false;
            }
        });

        jQuery.getJSON(this.restURL + '/users', function (data) {
            for (var i=0; i<data.length; i++) {
                jQuery('<option />')
                    .html(data[i].email)
                    .attr('value', data[i].email)
                    .appendTo('#email_source')
            }
        });

        jQuery('#st-email-lightbox-form').submit(function () {
            if (jQuery('#email_dest').get(0).length <= 0) {
                alert(loc('Error: To send email, you must specify a recipient.'));
                return false;
            }
            
            jQuery('#email_send').attr('disabled', true);
            jQuery('#email_dest option').attr('selected', true);

            var data = jQuery(this).serialize();
            jQuery.ajax({
                type: 'post',
                url: Page.cgiUrl(),
                data: data,
                success: function (data) {
                    jQuery.hideLightbox();
                },
                error: function() {
                    alert(loc('Error: Failed to send email.'));
                    jQuery('#email_send').attr('disabled', false);
                    jQuery('#email_dest option').attr('selected', false);
                }
            })
            return false;
        });
    }
    jQuery.showLightbox({
        content: '#st-email-lightbox',
        close: '#email_cancel',
        width: '760px',
        callback: function() {
            jQuery('input[name="email_page_subject"]').select().focus();
            jQuery('#email_send').attr('disabled', false);
        }
    });
}
