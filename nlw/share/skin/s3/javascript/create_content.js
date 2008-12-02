var ST = ST || {};
ST.CreateContent = function () {}
var proto = ST.CreateContent.prototype = {};

// toggle enabling and disabling mutually exclusive options
proto.enable_and_disable = function(enable_id, disable_id) {
    jQuery('#st-create-content-lightbox ' + disable_id + ' input')
        .attr('disabled', 'disabled');
    jQuery('#st-create-content-lightbox ' + enable_id + ' input')
        .attr('disabled', '');
}

proto.enable_blank = function() {
    this.enable_and_disable('#blank-option', '#template-option');
}

proto.enable_from_template = function() {
    this.enable_and_disable('#template-option', '#blank-option');
    // enable the section for whichever radio is selected
    if (jQuery('#st-create-content-lightbox #from-template-radio')
        .is(':checked')) {
        this.enable_use_template();
    } else {
        this.enable_copy_existing();
    }
}

proto.enable_use_template = function () {
    this.enable_and_disable('#template-option-from-template',
        '#template-option-from-existing-page');
}

proto.enable_copy_existing = function() {
    this.enable_and_disable('#template-option-from-existing-page',
        '#template-option-from-template');
}

proto.selected_page_type = function () {
    if (jQuery('#st-create-content-lightbox #page-radio')
            .is(":checked"))
        return "page";
    else if (
        jQuery('#st-create-content-lightbox #spreadsheet-radio')
            .is(":checked"))
        return "spreadsheet";
}

proto.setup = function () {
    var self = this;

    // Clear errors from the previous time around: {bz: 1039}
    jQuery('#st-create-content-lightbox .error').html('');

    // Bind radio buttons
    jQuery('#st-create-content-lightbox #blank-radio')
    .unbind('click').click(function () {
        self.enable_blank();
    });
    jQuery('#st-create-content-lightbox #template-radio')
    .unbind('click').click(function () {
        self.enable_from_template();
    });
    jQuery('#st-create-content-lightbox #from-template-radio')
    .unbind('click').click(function () {
        self.enable_use_template();
    });
    jQuery('#st-create-content-lightbox #from-existing-page-radio')
    .unbind('click').click(function () {
        self.enable_copy_existing();
    });
    if (jQuery('#st-create-content-lightbox #blank-radio').is(':checked')) {
        this.enable_blank();
    }
    else {
        this.enable_from_template();
    }

    jQuery('#st-create-content-lightbox #st-create-content-form')
        .unbind('submit')
        .submit(function () {
            var url = self.create_url();
            alert(url);
            if (url)
                document.location = url;    
            return false;
        });

}

proto.set_incipient_title = function (title) {
    this._incipient_title = title;
}

proto.create_url = function () {
    var type = this.selected_page_type();
    if (this._incipient_title) {
        return "?action=display;is_incipient=1"
            + ';page_name=' + this._incipient_title
            + ';page_type=' + type;
    }
    else {
        return "?action=new_page;page_type=" + type;
    }
}
