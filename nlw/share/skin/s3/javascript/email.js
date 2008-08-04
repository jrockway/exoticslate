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
        jQuery('<div class="lightbox" id="st-email-lightbox">')
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
            jQuery('<option>').val(val).html(val).appendTo('#email_dest');
        });

        jQuery.getJSON(this.restURL + '/users', function (data) {
            for (var i=0; i<data.length; i++) {
                jQuery('<option>')
                    .html(data[i].name)
                    .attr('value', data[i].name)
                    .appendTo('#email_source')
            }
        });

        jQuery('#st-email-lightbox').submit(function () {
            var data = jQuery(this).serialize();
            jQuery.post(
                Page.cgiUrl(),
                data,
                function (data) {
                    jQuery.hideLightbox();
                }
            )
            return false;
        });
    }
    jQuery.showLightbox({
        content: '#st-email-lightbox',
        close: '#email_cancel',
        width: '600px'
    });
}

var Email = new ST.Email;
Email.show();
