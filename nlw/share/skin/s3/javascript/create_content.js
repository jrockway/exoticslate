var ST = ST || {};
ST.CreateContent = function () {}
var proto = ST.CreateContent.prototype = {};

proto.createContentLightbox = function () {
    var self = this;
    this.process('create_content_lightbox.tt2');
    this.sel = '#st-create-content-lightbox';
    this.show(
        false,
        self.callback
    );
}

proto.callback = function () { }

proto.process = function (template) {
    Socialtext.loc = loc;
    jQuery('body').append(
        Jemplate.process(template, Socialtext)
    );
}

proto.show = function (do_redirect, callback) {
    var self = this;
    jQuery.showLightbox({
        content: this.sel,
        close: this.sel + ' .close',
        callback: callback 
    });

    // Clear errors from the previous time around: {bz: 1039}
    jQuery(self.sel + ' .error').html('');

    // toggle enabling and disabling mutually exclusive options
    var enable_and_disable = function(enable_id, disable_id) {
        jQuery('#st-create-content-lightbox ' + disable_id + ' input')
            .attr('disabled', 'disabled');
        jQuery('#st-create-content-lightbox ' + enable_id + ' input')
            .attr('disabled', '');
    }
    var enable_blank = function() {
        enable_and_disable('#blank-option', '#template-option');
    }
    var enable_from_template = function() {
        enable_and_disable('#template-option', '#blank-option');
    }
    var enable_use_template = function() {
        enable_and_disable('#template-option-from-template',
            '#template-option-from-existing-page');
    }
    var enable_copy_existing = function() {
        enable_and_disable('#template-option-from-existing-page',
            '#template-option-from-template');
    }
    jQuery('#st-create-content-lightbox #blank-radio')
    .unbind('click').click(function () {
        enable_blank();
    });
    jQuery('#st-create-content-lightbox #template-radio')
    .unbind('click').click(function () {
        enable_from_template();
        // enable the section for whichever radio is selected
        if (jQuery('#st-create-content-lightbox #from-template-radio')
            .is(':checked')) {
            enable_use_template();
        } else {
            enable_copy_existing();
        }
    });
    jQuery('#st-create-content-lightbox #from-template-radio')
    .unbind('click').click(function () {
        enable_use_template();
    });
    jQuery('#st-create-content-lightbox #from-existing-page-radio')
    .unbind('click').click(function () {
        enable_copy_existing();
    });

    enable_blank();
}
